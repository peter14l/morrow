import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/notification_service.dart';

/// Service dedicated to message transport and lifecycle management.
///
/// Handles retrieving messages, applying "whisper mode" (ephemeral) filters,
/// sending new messages with security checks (e.g. blocking), and marking
/// messages as read.
class ChatMessagingService {
  final SupabaseClient _supabase;

  ChatMessagingService({SupabaseClient? client})
    : _supabase = client ?? SupabaseService().client;

  /// Retrieves messages for a specific conversation.
  ///
  /// Includes read receipts, reply-to metadata, and reaction counts.
  /// Filters messages based on the user's "cleared_at" timestamp.
  Future<List<Message>> getMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
    DateTime? sessionStart,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      // 1. Fetch cleared_at timestamp for the current user
      final participantResponse = await _supabase
          .from('conversation_participants')
          .select('cleared_at')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      final clearedAt =
          participantResponse != null &&
              participantResponse['cleared_at'] != null
          ? DateTime.parse(participantResponse['cleared_at'])
          : null;

      // 2. Query messages
      var query = _supabase
          .from(SupabaseConfig.messagesTable)
          .select('''
            *,
            sender_profile:sender_id (username, avatar_url),
            reply_to:reply_to_id (
              id, content, sender_id, image_url, video_url, file_url, voice_url, 
              iv, encrypted_keys, signal_message_type, signal_sender_content,
              pq_aura_header, pq_aura_payload,
              profiles:sender_id (username)
            ),
            reactions:message_reactions(*),
            media_views:message_media_views!left(view_count)
          ''')
          .eq('conversation_id', conversationId);

      if (clearedAt != null) {
        query = query.gte('created_at', clearedAt.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Message> messages = [];
      final List<String> messageIds = [];

      for (final item in response) {
        final messageMap = Map<String, dynamic>.from(item);
        final profile = messageMap['sender_profile'];
        if (profile != null) {
          messageMap['sender_name'] = profile['username'];
          messageMap['sender_avatar'] = profile['avatar_url'];
        }

        if (messageMap['media_views'] != null) {
          final views = messageMap['media_views'] as List;
          if (views.isNotEmpty) {
            messageMap['current_user_view_count'] = views[0]['view_count'] ?? 0;
          }
        }

        messages.add(Message.fromJson(messageMap));
        messageIds.add(messageMap['id']);
      }

      // 3. Process read receipts
      if (messageIds.isNotEmpty) {
        final readReceipts = await _supabase
            .from(SupabaseConfig.messageReadReceiptsTable)
            .select('message_id, user_id, read_at')
            .inFilter('message_id', messageIds);

        final myReadMap = <String, String>{};
        final firstReadMap = <String, String>{};

        for (final r in readReceipts) {
          final msgId = r['message_id'] as String;
          final uId = r['user_id'] as String;
          final rAt = r['read_at'] as String;

          if (uId == currentUserId) myReadMap[msgId] = rAt;

          final msgIndex = messages.indexWhere((m) => m.id == msgId);
          if (msgIndex >= 0 && uId != messages[msgIndex].senderId) {
            if (!firstReadMap.containsKey(msgId) ||
                DateTime.parse(
                  rAt,
                ).isBefore(DateTime.parse(firstReadMap[msgId]!))) {
              firstReadMap[msgId] = rAt;
            }
          }
        }

        for (var i = 0; i < messages.length; i++) {
          final isSender = messages[i].senderId == currentUserId;
          final myReadTimeStr = myReadMap[messages[i].id];
          final anyReadTimeStr = firstReadMap[messages[i].id];

          final DateTime? myReadAt = myReadTimeStr != null
              ? DateTime.parse(myReadTimeStr)
              : null;
          final DateTime? anyReadAt = anyReadTimeStr != null
              ? DateTime.parse(anyReadTimeStr)
              : null;

          if (myReadAt != null || anyReadAt != null) {
            messages[i] = messages[i].copyWith(
              readAt: myReadAt,
              anyReadAt: anyReadAt,
              isRead: isSender ? (anyReadAt != null) : (myReadAt != null),
            );

            // Heal expiresAt locally
            if (messages[i].isEphemeral &&
                messages[i].expiresAt == null &&
                anyReadAt != null) {
              final calculatedExpiry = anyReadAt.add(
                Duration(seconds: messages[i].ephemeralDuration),
              );
              messages[i] = messages[i].copyWith(expiresAt: calculatedExpiry);
            }
          }
        }
      }

      return messages.reversed.toList();
    } catch (e) {
      debugPrint('[ChatMessagingService] Error fetching messages: $e');
      rethrow;
    }
  }

  /// Send a message with all security checks and metadata updates.
  /// Uses consolidated RPC send_message_v3 for scalability.
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType messageType = MessageType.text,
    String? mediaUrl,
    String? mediaFileName,
    int? mediaFileSize,
    int? voiceDuration,
    Map<String, String>? encryptedKeys,
    String? iv,
    int? signalMessageType,
    String? signalSenderContent,
    int whisperMode = 0,
    String? replyToId,
    String? rippleId,
    String? storyId,
    String? postId,
    Map<String, dynamic>? shareData,
    Map<String, dynamic>? locationData,
    String mediaViewMode = 'unlimited',
    bool isSpoiler = false,
    // PQ-Aura post-quantum encryption fields
    String? pqAuraHeader,
    String? pqAuraPayload,
  }) async {
    try {
      final response = await _supabase.rpc(
        'send_message_v3',
        params: {
          'p_conversation_id': conversationId,
          'p_content': content,
          'p_message_type': messageType.name,
          'p_media_url': mediaUrl,
          'p_media_file_name': mediaFileName,
          'p_media_file_size': mediaFileSize,
          'p_voice_duration': voiceDuration,
          'p_reply_to_id': replyToId,
          'p_is_ephemeral': whisperMode > 0,
          'p_ephemeral_duration': whisperMode == 1 ? 0 : 86400,
          'p_encrypted_keys': encryptedKeys,
          'p_iv': iv,
          'p_signal_message_type': signalMessageType,
          'p_signal_sender_content': signalSenderContent,
          'p_whisper_mode': whisperMode == 0
              ? 'OFF'
              : (whisperMode == 1 ? 'INSTANT' : '24_HOURS'),
          'p_ripple_id': rippleId,
          'p_story_id': storyId,
          'p_post_id': postId,
          'p_share_data': shareData,
          'p_location_data': locationData,
          'p_media_view_mode': mediaViewMode,
          'p_is_spoiler': isSpoiler,
          'p_pq_aura_header': pqAuraHeader,
          'p_pq_aura_payload': pqAuraPayload,
        },
      );

      if (response == null) throw Exception('Failed to send message via RPC');

      final messageMap = Map<String, dynamic>.from(response);
      final profile = messageMap['sender_profile'];
      if (profile != null) {
        messageMap['sender_name'] = profile['username'];
        messageMap['sender_avatar'] = profile['avatar_url'];
      }

      return Message.fromJson(messageMap);
    } catch (e) {
      debugPrint('[ChatMessagingService] Error sending message (RPC): $e');
      // If RPC fails (e.g. not migrated yet), fallback to legacy or rethrow
      rethrow;
    }
  }

  /// Mark message as read.
  Future<void> markAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.messageReadReceiptsTable).upsert({
        'message_id': messageId,
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'message_id,user_id');
    } catch (e) {
      debugPrint('[ChatMessagingService] Error marking read: $e');
    }
  }

  /// Subscribe to new messages.
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required Function(Message) onNewMessage,
    Function(String)? onDeleteMessage,
  }) {
    final channel = _supabase.channel('messages:$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final messageData = Map<String, dynamic>.from(payload.newRecord);

            // OPTIMIZATION: Ensure timestamp is set correctly for immediate UI display
            messageData['created_at'] =
                messageData['created_at'] ?? DateTime.now().toIso8601String();

            // OPTIMIZATION: Derive message type early to avoid deep construction lag
            if (messageData['message_type'] == null) {
              if (messageData['voice_url'] != null)
                messageData['message_type'] = 'voice';
              else if (messageData['image_url'] != null)
                messageData['message_type'] = 'image';
              else
                messageData['message_type'] = 'text';
            }

            onNewMessage(Message.fromJson(messageData));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConfig.messagesTable,
          callback: (payload) {
            if (onDeleteMessage != null)
              onDeleteMessage(payload.oldRecord['id'] as String);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              '[ChatMessagingService] Subscription error for $conversationId: $error',
            );
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint(
              '[ChatMessagingService] Subscription timed out for $conversationId. Table replication or RLS may be missing.',
            );
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            // Silenced for pitch
          }
        });
    return channel;
  }
}
