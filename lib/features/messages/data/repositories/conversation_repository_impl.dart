import 'package:oasis/features/messages/data/datasources/conversation_remote_datasource.dart';
import 'package:oasis/features/messages/domain/models/conversation_entity.dart';
import 'package:oasis/features/messages/domain/repositories/conversation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Implementation of ConversationRepository
class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDatasource _remoteDatasource;
  final SupabaseClient? _client;

  ConversationRepositoryImpl({ConversationRemoteDatasource? remoteDatasource, SupabaseClient? client})
    : _remoteDatasource = remoteDatasource ?? ConversationRemoteDatasource(),
      _client = client;

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
    final userId = _client?.auth.currentUser?.id;
    if (userId == null) return;
    await _remoteDatasource.markConversationAsRead(
      conversationId: conversationId,
      userId: userId,
    );
  }

  @override
  Future<void> togglePin(String conversationId) async {
    await _remoteDatasource.updateConversation(conversationId: conversationId);
  }

  @override
  Future<void> toggleMute(String conversationId) async {
    final conv = await _remoteDatasource.getConversation(conversationId);
    final currentMuted = conv?['is_muted'] as bool? ?? false;
    await _remoteDatasource.toggleMute(conversationId, currentMuted);
  }

  @override
  Future<void> toggleArchive(String conversationId) async {
    final conv = await _remoteDatasource.getConversation(conversationId);
    final currentArchived = conv?['is_archived'] as bool? ?? false;
    await _remoteDatasource.toggleArchive(conversationId, currentArchived);
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
      otherUserId: json['other_user_id'] as String? ?? '',
      otherUserName: json['other_user_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      otherUserAvatar: json['other_user_avatar'] as String? ?? json['avatar_url'] as String? ?? '',
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
