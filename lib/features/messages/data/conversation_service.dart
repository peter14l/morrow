import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/messages/data/chat_decryption_service.dart';

/// Service for managing chat conversations and threads.
///
/// Handles fetching conversations, creating new threads, managing participants,
/// and updating thread-level metadata like chat themes/backgrounds.
class ConversationService {
  final SupabaseClient _supabase;
  final ChatDecryptionService _decryptionService;

  ConversationService({
    SupabaseClient? client,
    ChatDecryptionService? decryptionService,
  }) : _supabase = client ?? SupabaseService().client,
       _decryptionService = decryptionService ?? ChatDecryptionService();

  /// Retrieves a list of conversations for a user.
  ///
  /// Fetches participants, last message previews, and metadata for both
  /// direct and group chats.
  Future<List<Conversation>> getConversations({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final List<dynamic> response = await _supabase.rpc(
        'get_user_conversations_v2',
      );

      if (response.isEmpty) return [];

      final List<Conversation> conversations = [];
      for (final item in response) {
        final conversationMap = Map<String, dynamic>.from(item);

        // Process participant information for direct/group chats
        if (conversationMap['type'] == 'direct' &&
            conversationMap['all_participants'] != null) {
          final participants = conversationMap['all_participants'] as List;
          final otherParticipant = participants.firstWhere(
            (p) => p['user_id'] != userId,
            orElse: () => participants.isNotEmpty ? participants[0] : null,
          );

          if (otherParticipant != null && otherParticipant['profile'] != null) {
            final profile = otherParticipant['profile'];
            conversationMap['other_user_id'] = otherParticipant['user_id'];
            conversationMap['other_user_name'] =
                profile['username'] ?? profile['full_name'] ?? 'Unknown';
            conversationMap['other_user_avatar'] = profile['avatar_url'] ?? '';
          }
        } else {
          conversationMap['other_user_id'] = '';
          conversationMap['other_user_name'] =
              conversationMap['name'] ?? 'Group Chat';
          conversationMap['other_user_avatar'] =
              conversationMap['image_url'] ?? '';
        }

        conversationMap['last_message_time'] = conversationMap['sort_time'];

        // Decrypt the preview for the last message
        final lastMsgData = conversationMap['last_message_data'];
        if (lastMsgData != null) {
          final decryptedContent = await _decryptionService
              .decryptMessageContent(
                senderId: lastMsgData['sender_id'],
                currentUserId: userId,
                content: lastMsgData['content'] ?? '',
                encryptedKeys:
                    lastMsgData['encrypted_keys'] != null
                        ? Map<String, String>.from(
                          lastMsgData['encrypted_keys'],
                        )
                        : null,
                iv: lastMsgData['iv'],
                signalMessageType: lastMsgData['signal_message_type'],
                signalSenderContent: lastMsgData['signal_sender_content'],
              );

          conversationMap['last_message'] = decryptedContent;
          conversationMap['last_message_sender_id'] = lastMsgData['sender_id'];
          conversationMap['last_message_type'] = _decryptionService
              .determineMessageType(lastMsgData);
        }

        conversations.add(Conversation.fromJson(conversationMap));
      }

      return conversations;
    } catch (e) {
      debugPrint('[ConversationService] Error: $e');
      rethrow;
    }
  }

  /// Retrieves details for a specific conversation.
  ///
  /// Uses a direct targeted query instead of fetching all conversations,
  /// which avoids the O(N) full-list scan on every unread/receipt update.
  Future<Conversation> getConversationDetails(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      // Fetch participants for this conversation only
      final participants = await _supabase
          .from(SupabaseConfig.conversationParticipantsTable)
          .select(
            'user_id, unread_count, is_muted, cleared_at, '
            'profiles:user_id(username, full_name, avatar_url)',
          )
          .eq('conversation_id', conversationId);

      if (participants.isEmpty) {
        throw Exception('Conversation not found: $conversationId');
      }

      // Find the other participant
      final me = participants.firstWhere(
        (p) => p['user_id'] == userId,
        orElse: () => participants.first,
      );
      final other = participants.firstWhere(
        (p) => p['user_id'] != userId,
        orElse: () => participants.first,
      );

      final otherProfile = other['profiles'] as Map<String, dynamic>? ?? {};
      final unreadCount = (me['unread_count'] as int?) ?? 0;

      // Fetch last message for this conversation
      final lastMsgRows = await _supabase
          .from(SupabaseConfig.messagesTable)
          .select(
            'id, sender_id, content, created_at, '
            'image_url, video_url, voice_url, file_url, '
            'encrypted_keys, iv, signal_message_type, signal_sender_content',
          )
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);

      String lastMessage = '';
      String? lastMessageType;
      String? lastMessageSenderId;
      DateTime? lastMessageTime;

      if (lastMsgRows.isNotEmpty) {
        final lastMsgData = lastMsgRows.first;
        lastMessageSenderId = lastMsgData['sender_id'] as String?;
        lastMessageTime =
            lastMsgData['created_at'] != null
                ? DateTime.tryParse(lastMsgData['created_at'] as String)
                : null;
        lastMessageType = _decryptionService.determineMessageType(lastMsgData);

        final decrypted = await _decryptionService.decryptMessageContent(
          senderId: lastMsgData['sender_id'] as String? ?? '',
          currentUserId: userId,
          content: lastMsgData['content'] as String? ?? '',
          encryptedKeys:
              lastMsgData['encrypted_keys'] != null
                  ? Map<String, String>.from(
                    lastMsgData['encrypted_keys'] as Map,
                  )
                  : null,
          iv: lastMsgData['iv'] as String?,
          signalMessageType: lastMsgData['signal_message_type'] as int?,
          signalSenderContent:
              lastMsgData['signal_sender_content'] as String?,
        );
        lastMessage = decrypted;
      }

      final conversationMap = <String, dynamic>{
        'id': conversationId,
        'type': 'direct',
        'other_user_id': other['user_id'],
        'other_user_name':
            otherProfile['username'] ?? otherProfile['full_name'] ?? 'Unknown',
        'other_user_avatar': otherProfile['avatar_url'] ?? '',
        'unread_count': unreadCount,
        'is_muted': me['is_muted'] ?? false,
        'last_message': lastMessage,
        'last_message_type': lastMessageType ?? 'text',
        'last_message_sender_id': lastMessageSenderId,
        'last_message_time': lastMessageTime?.toIso8601String(),
        'sort_time': lastMessageTime?.toIso8601String(),
      };

      return Conversation.fromJson(conversationMap);
    } catch (e) {
      debugPrint(
        '[ConversationService] Error fetching conversation details: $e',
      );
      rethrow;
    }
  }

  /// Get or create a direct conversation between two users.
  Future<String> getOrCreateConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_or_create_direct_conversation',
        params: {'p_user1_id': user1Id, 'p_user2_id': user2Id},
      );
      return response as String;
    } catch (e) {
      debugPrint('[ConversationService] Error creating direct chat: $e');
      rethrow;
    }
  }

  /// Subscribe to conversation updates (unread count, participants changes)
  RealtimeChannel subscribeToConversations({
    required String userId,
    required Function(String conversationId) onUpdate,
  }) {
    final channel = _supabase.channel('user_conversations:$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.conversationParticipantsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final conversationId =
                  payload.newRecord['conversation_id'] as String;
              onUpdate(conversationId);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              'ConversationService: subscribeToConversations error: $error',
            );
          }
        });

    return channel;
  }

  /// Subscribes to chat background changes for a specific conversation and user.
  RealtimeChannel subscribeToBackgroundChanges({
    required String conversationId,
    String? userId,
    required Function(String? backgroundUrl) onUpdate,
  }) {
    final effectiveUserId = userId ?? _supabase.auth.currentUser?.id;
    if (effectiveUserId == null) throw Exception('Not authenticated');

    final channel = _supabase.channel(
      'chat_background:$conversationId:$effectiveUserId',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_themes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final data =
                payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord;
            if (data.isNotEmpty && data['user_id'] == effectiveUserId) {
              onUpdate(data['background_image_url'] as String?);
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              'ConversationService: subscribeToBackgroundChanges error: $error',
            );
          }
        });
    return channel;
  }

  /// Toggles mute for a conversation for the current user.
  Future<void> toggleMute(String conversationId, bool mute) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from(SupabaseConfig.conversationParticipantsTable)
          .update({'is_muted': mute})
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[ConversationService] Error toggling mute: $e');
    }
  }

  /// Gets the mute status for a conversation for the current user.
  Future<bool> getMuteStatus(String conversationId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from(SupabaseConfig.conversationParticipantsTable)
          .select('is_muted')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();

      return response?['is_muted'] as bool? ?? false;
    } catch (e) {
      debugPrint('[ConversationService] Error getting mute status: $e');
      return false;
    }
  }

  /// Update chat background for all participants.
  Future<void> updateChatBackground(
    String conversationId,
    String? backgroundUrl,
  ) async {
    try {
      final participants = await _supabase
          .from(SupabaseConfig.conversationParticipantsTable)
          .select('user_id')
          .eq('conversation_id', conversationId);

      for (final participant in participants) {
        final userId = participant['user_id'] as String;
        await _supabase.from(SupabaseConfig.chatThemesTable).upsert({
          'conversation_id': conversationId,
          'user_id': userId,
          'background_image_url': backgroundUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'conversation_id, user_id');
      }
    } catch (e) {
      debugPrint('[ConversationService] Error updating background: $e');
      rethrow;
    }
  }

  /// Retrieves the current background URL for a conversation.
  Future<String?> getChatBackground(String conversationId) async {
    try {
      final data =
          await _supabase
              .from(SupabaseConfig.chatThemesTable)
              .select('background_image_url')
              .eq('conversation_id', conversationId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();

      return data?['background_image_url'] as String?;
    } catch (e) {
      debugPrint('[ConversationService] Error fetching background: $e');
      return null;
    }
  }

  /// Fetches recent unread messages for the Peek preview feature.
  /// Returns decrypted message content, NOT the encrypted ciphertext.
  /// This does NOT mark messages as read - it only reads them for preview.
  Future<List<String>> getRecentUnreadMessages(
    String conversationId,
    int limit,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Get unread messages for this conversation (not marked as read by current user)
      final unreadMessages = await _supabase
          .from(SupabaseConfig.messagesTable)
          .select(
            'id, sender_id, content, created_at, '
            'image_url, video_url, voice_url, file_url, '
            'encrypted_keys, iv, signal_message_type, signal_sender_content',
          )
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId) // Exclude own messages
          .order('created_at', ascending: false)
          .limit(limit);

      if (unreadMessages.isEmpty) return [];

      // Decrypt each message content
      final List<String> decryptedContents = [];
      for (final msgData in unreadMessages) {
        // Check if this is a media message type
        final messageType = _decryptionService.determineMessageType(msgData);

        String content;
        if (messageType != 'text') {
          // For media, show appropriate placeholder
          switch (messageType) {
            case 'image':
              content = '📷 Photo';
              break;
            case 'video':
              content = '🎥 Video';
              break;
            case 'voice':
              content = '🎤 Voice message';
              break;
            case 'document':
              content = '📄 Document';
              break;
            default:
              content = 'Sent attachment';
          }
        } else {
          // For text messages, decrypt the content
          final decrypted = await _decryptionService.decryptMessageContent(
            senderId: msgData['sender_id'] as String? ?? '',
            currentUserId: userId,
            content: msgData['content'] as String? ?? '',
            encryptedKeys:
                msgData['encrypted_keys'] != null
                    ? Map<String, String>.from(
                      msgData['encrypted_keys'] as Map,
                    )
                    : null,
            iv: msgData['iv'] as String?,
            signalMessageType: msgData['signal_message_type'] as int?,
            signalSenderContent:
                msgData['signal_sender_content'] as String?,
          );
          content = decrypted;
        }

        // Skip placeholder messages
        if (content != '🔒 Message encrypted' && content.isNotEmpty) {
          decryptedContents.add(content);
        }
      }

      return decryptedContents;
    } catch (e) {
      debugPrint(
        '[ConversationService] Error fetching recent unread messages: $e',
      );
      return [];
    }
  }
}
