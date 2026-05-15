import 'package:oasis/features/messages/data/datasources/conversation_remote_datasource.dart';
import 'package:oasis/features/messages/domain/models/conversation_entity.dart';
import 'package:oasis/features/messages/domain/repositories/conversation_repository.dart';

/// Implementation of ConversationRepository
class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDatasource _remoteDatasource;

  ConversationRepositoryImpl({ConversationRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? ConversationRemoteDatasource();

  @override
  Future<List<ConversationEntity>> getConversations(String userId) async {
    final results = await _remoteDatasource.getConversations(userId);
    return results.map((json) => _conversationFromJson(json)).toList();
  }

  @override
  Future<ConversationEntity?> getConversation(String conversationId) async {
    final result = await _remoteDatasource.getConversation(conversationId);
    if (result == null) return null;
    return _conversationFromJson(result);
  }

  @override
  Future<ConversationEntity> createConversation({
    required String userId,
    required String otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
  }) async {
    final result = await _remoteDatasource.createConversation(
      createdBy: userId,
      participantIds: [userId, otherUserId],
    );
    return _conversationFromJson(result).copyWith(
      otherUserId: otherUserId,
      otherUserName: otherUserName ?? 'Unknown',
      otherUserAvatar: otherUserAvatar ?? '',
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _remoteDatasource.deleteConversation(conversationId);
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    // This would need userId from somewhere - placeholder
  }

  @override
  Future<void> togglePin(String conversationId) async {
    await _remoteDatasource.updateConversation(conversationId: conversationId);
  }

  @override
  Future<void> toggleMute(String conversationId) async {
    // This would need current mute state - placeholder
  }

  @override
  Future<void> toggleArchive(String conversationId) async {
    // This would need current archive state - placeholder
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final conversations = await getConversations(userId);
    int totalUnread = 0;
    for (final conv in conversations) {
      totalUnread += conv.unreadCount;
    }
    return totalUnread;
  }

  // Helper methods for mapping
  ConversationEntity _conversationFromJson(Map<String, dynamic> json) {
    return ConversationEntity(
      id: json['id'] as String,
      otherUserId: '', // Would need to fetch from participants
      otherUserName: json['name'] as String? ?? 'Unknown',
      otherUserAvatar: json['avatar_url'] as String? ?? '',
      lastMessage: null,
      lastMessageAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      unreadCount: 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
