import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/domain/models/message_reaction.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:oasis/features/messages/data/conversation_service.dart';
import 'package:oasis/services/chat_messaging_service.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/features/messages/data/message_operations_service.dart';
import 'package:oasis/services/moderation_service.dart';
import 'package:oasis/core/config/supabase_config.dart';

/// Facade service for all messaging and chat-related operations.
///
/// This service orchestrates several specialized sub-services:
/// - [ConversationService]: Thread management.
/// - [ChatMessagingService]: Message transport.
/// - [ChatMediaService]: Attachment handling.
/// - [MessageOperationsService]: Auxiliary tasks (delete, typing, receipts).
/// - [ModerationService]: User blocking and reporting.
///
/// It maintains a unified public API while ensuring separation of concerns
/// and modularity.
class MessagingService extends ChangeNotifier {
  final SupabaseClient _supabase;

  late final ConversationService _conversationService;
  late final ChatMessagingService _chatMessagingService;
  late final ChatMediaService _chatMediaService;
  late final MessageOperationsService _messageOpsService;
  late final ModerationService _moderationService;

  MessagingService({
    SupabaseClient? client,
    NotificationService? notificationService,
    ConversationService? conversationService,
    ChatMessagingService? chatMessagingService,
    ChatMediaService? chatMediaService,
    MessageOperationsService? messageOpsService,
    ModerationService? moderationService,
  }) : _supabase = client ?? SupabaseService().client {
    _conversationService =
        conversationService ?? ConversationService(client: _supabase);
    _chatMessagingService =
        chatMessagingService ?? ChatMessagingService(client: _supabase);
    _chatMediaService = chatMediaService ?? ChatMediaService(client: _supabase);
    _messageOpsService =
        messageOpsService ?? MessageOperationsService(client: _supabase);
    _moderationService = moderationService ?? ModerationService();
  }

  // --- Conversations ---

  /// Retrieves conversations for the specified [userId].
  Future<List<Conversation>> getConversations({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) => _conversationService.getConversations(
    userId: userId,
    limit: limit,
    offset: offset,
  );

  /// Retrieves details for a specific conversation.
  Future<Conversation> getConversationDetails(String conversationId) =>
      _conversationService.getConversationDetails(conversationId);

  /// Retrieves the current background URL for a conversation.
  Future<String?> getChatBackground(String conversationId) =>
      _conversationService.getChatBackground(conversationId);

  /// Initiates or retrieves a direct message conversation between two users.
  Future<String> getOrCreateConversation({
    required String user1Id,
    required String user2Id,
  }) => _conversationService.getOrCreateConversation(
    user1Id: user1Id,
    user2Id: user2Id,
  );

  /// Creates a new group conversation.
  Future<String> createGroupConversation({
    required String name,
    required List<String> participantIds,
  }) => _conversationService.createGroupConversation(
    name: name,
    participantIds: participantIds,
  );

  /// Updates the name of a group conversation.
  Future<void> updateGroupName(String conversationId, String newName) =>
      _conversationService.updateGroupName(conversationId, newName);

  /// Adds new members to an existing group.
  Future<void> addGroupMembers(
    String conversationId,
    List<String> participantIds,
  ) => _conversationService.addGroupMembers(conversationId, participantIds);

  /// Subscribes to thread-level updates for a user.
  RealtimeChannel subscribeToConversations({
    required String userId,
    required Function(String conversationId) onUpdate,
  }) => _conversationService.subscribeToConversations(
    userId: userId,
    onUpdate: onUpdate,
  );

  /// Updates the background/theme for a conversation.
  Future<void> updateChatBackground(
    String conversationId,
    String? backgroundUrl,
  ) async {
    await _conversationService.updateChatBackground(
      conversationId,
      backgroundUrl,
    );
    notifyListeners();
  }

  /// Subscribes to chat background changes.
  RealtimeChannel subscribeToBackgroundChanges({
    required String conversationId,
    String? userId,
    required Function(String? backgroundUrl) onUpdate,
  }) => _conversationService.subscribeToBackgroundChanges(
    conversationId: conversationId,
    userId: userId,
    onUpdate: onUpdate,
  );

  /// Toggles mute for a conversation.
  Future<void> toggleMute(String conversationId, bool mute) =>
      _conversationService.toggleMute(conversationId, mute);

  /// Gets the mute status for a conversation.
  Future<bool> getMuteStatus(String conversationId) =>
      _conversationService.getMuteStatus(conversationId);

  /// Removes chat background for the current user only.
  Future<void> removeChatBackground(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from(SupabaseConfig.chatThemesTable).upsert({
      'conversation_id': conversationId,
      'user_id': userId,
      'background_image_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'conversation_id, user_id');
    notifyListeners();
  }

  /// Fetches recent unread messages for Peek preview (decrypted, without marking as read).
  Future<List<String>> getRecentUnreadMessages(
    String conversationId,
    int limit,
  ) => _conversationService.getRecentUnreadMessages(conversationId, limit);

  // --- Messages ---

  /// Fetches history of messages for a [conversationId].
  Future<List<Message>> getMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
    DateTime? sessionStart,
  }) => _chatMessagingService.getMessages(
    conversationId: conversationId,
    limit: limit,
    offset: offset,
    sessionStart: sessionStart,
  );

  /// Sends a new chat message with optional media and E2EE metadata.
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType messageType = MessageType.text,
    String? mediaUrl,
    String? mediaFileName,
    int? mediaFileSize,
    String? mediaMimeType,
    int? voiceDuration,
    Map<String, String>? encryptedKeys,
    String? iv,
    int? signalMessageType,
    String? signalSenderContent,
    int? signalSenderMessageType,
    int whisperMode = 0,
    String? replyToId,
    String? rippleId,
    String? storyId,
    String? postId,
    Map<String, dynamic>? shareData,
    Map<String, dynamic>? locationData,
    String mediaViewMode = 'unlimited',
    bool isSpoiler = false,
    String? pqAuraHeader,
    String? pqAuraPayload,
  }) => _chatMessagingService.sendMessage(
    conversationId: conversationId,
    senderId: senderId,
    content: content,
    messageType: messageType,
    mediaUrl: mediaUrl,
    mediaFileName: mediaFileName,
    mediaFileSize: mediaFileSize,
    voiceDuration: voiceDuration,
    encryptedKeys: encryptedKeys,
    iv: iv,
    signalMessageType: signalMessageType,
    signalSenderContent: signalSenderContent,
    whisperMode: whisperMode,
    replyToId: replyToId,
    rippleId: rippleId,
    storyId: storyId,
    postId: postId,
    shareData: shareData,
    locationData: locationData,
    mediaViewMode: mediaViewMode,
    isSpoiler: isSpoiler,
    pqAuraHeader: pqAuraHeader,
    pqAuraPayload: pqAuraPayload,
  );

  /// Records a read receipt for a specific message.
  Future<void> markAsRead({
    required String messageId,
    required String userId,
    bool isWhisper = false,
  }) async {
    if (isWhisper) {
      try {
        await _supabase.rpc(
          'mark_whisper_message_read',
          params: {'msg_id': messageId, 'reader_id': userId},
        );
      } catch (e) {
        debugPrint('[MessagingService] Error marking whisper read: $e');
      }
    }
    return _chatMessagingService.markAsRead(
      messageId: messageId,
      userId: userId,
    );
  }

  /// Listens for incoming messages in a conversation.
  RealtimeChannel subscribeToMessages({
    required String conversationId,
    required Function(Message) onNewMessage,
    Function(String)? onDeleteMessage,
  }) => _chatMessagingService.subscribeToMessages(
    conversationId: conversationId,
    onNewMessage: onNewMessage,
    onDeleteMessage: onDeleteMessage,
  );

  // --- Media ---

  /// Uploads media for use in a chat message (unencrypted or manually encrypted).
  Future<String> uploadChatMedia(
    String filePath, {
    String folder = 'images',
    Uint8List? encryptedBytes,
    String? fileExtension,
    Function(double)? onProgress,
  }) => _chatMediaService.uploadChatMedia(
    filePath,
    folder: folder,
    encryptedBytes: encryptedBytes,
    fileExtension: fileExtension,
    onProgress: onProgress,
  );

  // --- Operations ---

  /// Permanently removes a message for everyone.
  Future<void> deleteMessage(String messageId) =>
      _messageOpsService.deleteMessage(messageId);

  /// Edits a message.
  Future<void> editMessage(
    String messageId,
    String newContent, {
    Map<String, dynamic>? encryptedKeys,
    String? iv,
    int? signalMessageType,
    String? pqAuraHeader,
    String? pqAuraPayload,
    String? signalSenderContent,
    String? pqAuraSenderPayload,
  }) =>
      _messageOpsService.editMessage(
        messageId,
        newContent,
        encryptedKeys: encryptedKeys,
        iv: iv,
        signalMessageType: signalMessageType,
        pqAuraHeader: pqAuraHeader,
        pqAuraPayload: pqAuraPayload,
        signalSenderContent: signalSenderContent,
        pqAuraSenderPayload: pqAuraSenderPayload,
      );

  /// Clears chat history for the current user only.
  Future<void> clearChatForMe(String conversationId) =>
      _messageOpsService.clearChatForMe(conversationId);

  /// Clears chat history for all participants (Admins/System).
  Future<void> clearConversationMessages(String conversationId) =>
      _messageOpsService.clearConversationMessages(conversationId);

  /// Broadcasts typing status to other participants.
  Future<void> updateTypingStatus(
    String conversationId,
    String userId,
    bool isTyping,
  ) => _messageOpsService.updateTypingStatus(conversationId, userId, isTyping);

  /// Broadcasts typing status via a specific Realtime channel (Zero IOPS).
  Future<void> sendTypingStatus(
    RealtimeChannel channel,
    String userId,
    bool isTyping,
  ) => _messageOpsService.sendTypingStatus(channel, userId, isTyping);

  /// Fetches typing status from database (polling fallback).
  Future<Map<String, dynamic>?> getTypingStatus(
    String conversationId,
    String currentUserId,
  ) => _messageOpsService.getTypingStatus(conversationId, currentUserId);

  /// Subscribes to typing status in a conversation.
  RealtimeChannel subscribeToTypingStatus({
    required String conversationId,
    required Function(String userId, bool isTyping) onTypingUpdate,
  }) => _messageOpsService.subscribeToTypingStatus(
    conversationId: conversationId,
    onTypingUpdate: onTypingUpdate,
  );

  /// Unsubscribes from typing status.
  Future<void> unsubscribeFromTypingStatus(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  /// Marks a conversation as read.
  Future<void> markConversationAsRead(String conversationId, String userId) =>
      _messageOpsService.markConversationAsRead(conversationId, userId);

  /// Marks messages as read (batch).
  Future<void> markMessagesAsRead(
    String conversationId,
    List<String> messageIds,
    String userId,
  ) =>
      _messageOpsService.markMessagesAsRead(conversationId, messageIds, userId);

  /// Toggles whisper mode.
  Future<void> toggleWhisperMode(String conversationId, int whisperMode) =>
      _messageOpsService.toggleWhisperMode(conversationId, whisperMode);

  /// Increments media view count.
  Future<void> incrementMediaViewCount(String messageId) =>
      _messageOpsService.incrementMediaViewCount(messageId);

  /// Adds a reaction to a message.
  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
    required String username,
  }) => _messageOpsService.addReaction(
    messageId: messageId,
    userId: userId,
    emoji: emoji,
    username: username,
  );

  /// Removes a reaction from a message.
  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) => _messageOpsService.removeReaction(
    messageId: messageId,
    userId: userId,
    emoji: emoji,
  );

  /// Fetches latest location data for a message (polling fallback).
  Future<Map<String, dynamic>?> getMessageLocation(String messageId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.messagesTable)
          .select('location_data')
          .eq('id', messageId)
          .maybeSingle();
      return response?['location_data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[MessagingService] Error fetching location: $e');
      return null;
    }
  }

  // --- Moderation ---

  /// Blocks a user.
  Future<bool> blockUser(String userId) => _moderationService.blockUser(userId);

  /// Unblocks a user.
  Future<bool> unblockUser(String userId) =>
      _moderationService.unblockUser(userId);

  /// Checks if a user is blocked.
  Future<bool> isUserBlocked(String userId) =>
      _moderationService.isUserBlocked(userId);

  /// Listens for read receipts in a conversation.
  RealtimeChannel subscribeToReadReceipts({
    required String conversationId,
    required Function(String messageId, String userId, DateTime readAt)
    onUpdate,
  }) => _messageOpsService.subscribeToReadReceipts(
    conversationId: conversationId,
    onUpdate: onUpdate,
  );

  /// Listens for reaction changes in a conversation.
  RealtimeChannel subscribeToReactions({
    required String conversationId,
    required Function(String messageId, List<MessageReactionModel> reactions)
    onUpdate,
  }) => _messageOpsService.subscribeToReactions(
    conversationId: conversationId,
    onUpdate: onUpdate,
  );

  /// Listens for changes to conversation metadata (e.g. whisper mode).
  RealtimeChannel subscribeToConversation({
    required String conversationId,
    required Function(int whisperMode) onUpdate,
  }) => _messageOpsService.subscribeToConversationDetails(
    conversationId: conversationId,
    onUpdate: onUpdate,
  );

  /// Closes a realtime subscription channel.
  Future<void> unsubscribeFromMessages(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  /// Listens for updates to a specific message.
  RealtimeChannel subscribeToMessageUpdates({
    required String messageId,
    required Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channel = _supabase.channel('message_updates:$messageId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: messageId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              '[MessagingService] Message updates subscription error: $error',
            );
          }
        });
    return channel;
  }

  /// Utility to filter messages based on expiry (placeholder).
  static List<Message> filterExpiredMessages(
    List<Message> messages, {
    DateTime? sessionStart,
  }) {
    // Currently returns all as per the original "disabled" logic in filterExpiredMessages.
    return messages;
  }
}
