import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Remote datasource for conversation operations
class ConversationRemoteDatasource {
  final SupabaseClient _client;

  ConversationRemoteDatasource({SupabaseClient? client})
    : _client = client ?? SupabaseService().client;

  /// Get all conversations for a user
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    // Get conversations where user is a participant
    final participantData = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', userId);

    if (participantData.isEmpty) return [];

    final conversationIds = participantData
        .map((p) => p['conversation_id'] as String)
        .toList();

    if (conversationIds.isEmpty) return [];

    // Get conversation details - fetch individually to avoid in_() issue
    final List<Map<String, dynamic>> conversations = [];
    for (final id in conversationIds.take(50)) {
      final result = await _client
          .from('conversations')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (result != null) {
        conversations.add(result);
      }
    }

    // Sort by updated_at
    conversations.sort((a, b) {
      final aTime = a['updated_at']?.toString() ?? '';
      final bTime = b['updated_at']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    return conversations;
  }

  /// Get a single conversation by ID
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final result = await _client
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .maybeSingle();
    return result;
  }

  /// Create a new conversation
  Future<Map<String, dynamic>> createConversation({
    required String createdBy,
    String? name,
    required List<String> participantIds,
  }) async {
    // Create conversation
    final conversationData = {
      'created_by': createdBy,
      if (name != null) 'name': name,
      'is_group': participantIds.length > 2,
    };

    final conversation = await _client
        .from('conversations')
        .insert(conversationData)
        .select()
        .single();

    // Add participants
    final participantData = participantIds
        .map(
          (userId) => {
            'conversation_id': conversation['id'],
            'user_id': userId,
            'role': userId == createdBy ? 'admin' : 'member',
          },
        )
        .toList();

    await _client.from('conversation_participants').insert(participantData);

    return conversation;
  }

  /// Update conversation (name, avatar, etc.)
  Future<Map<String, dynamic>> updateConversation({
    required String conversationId,
    String? name,
    String? avatarUrl,
    String? description,
  }) async {
    final updateData = <String, dynamic>{};
    if (name != null) updateData['name'] = name;
    if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
    if (description != null) updateData['description'] = description;

    final result = await _client
        .from('conversations')
        .update(updateData)
        .eq('id', conversationId)
        .select()
        .single();

    return result;
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    await _client.from('conversations').delete().eq('id', conversationId);
  }

  /// Get conversation participants
  Future<List<Map<String, dynamic>>> getParticipants(
    String conversationId,
  ) async {
    return await _client
        .from('conversation_participants')
        .select('''
          *,
          user:users(*)
        ''')
        .eq('conversation_id', conversationId);
  }

  /// Add participant to conversation
  Future<void> addParticipant({
    required String conversationId,
    required String userId,
    String role = 'member',
  }) async {
    await _client.from('conversation_participants').insert({
      'conversation_id': conversationId,
      'user_id': userId,
      'role': role,
    });
  }

  /// Remove participant from conversation
  Future<void> removeParticipant({
    required String conversationId,
    required String userId,
  }) async {
    await _client
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    // Get all unread messages
    final unreadMessages = await _client
        .from('messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId);

    // Mark each as read
    for (final msg in unreadMessages) {
      await _client.from('message_read_status').upsert({
        'message_id': msg['id'],
        'user_id': userId,
        'read_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get unread message count for a conversation
  Future<int> getUnreadCount({
    required String conversationId,
    required String userId,
  }) async {
    // Get all messages sent by others in this conversation
    final messages = await _client
        .from('messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId);

    if (messages.isEmpty) return 0;

    // Count messages that don't have a read status
    int unreadCount = 0;
    for (final msg in messages) {
      final readStatus = await _client
          .from('message_read_status')
          .select()
          .eq('message_id', msg['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (readStatus == null) {
        unreadCount++;
      }
    }

    return unreadCount;
  }

  /// Search conversations by name
  Future<List<Map<String, dynamic>>> searchConversations({
    required String userId,
    required String query,
  }) async {
    // Get user's conversation IDs
    final participantData = await _client
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', userId);

    if (participantData.isEmpty) return [];

    final conversationIds = participantData
        .map((p) => p['conversation_id'] as String)
        .toList();

    if (conversationIds.isEmpty) return [];

    // Search in conversations - fetch individually to avoid in_() issue
    final List<Map<String, dynamic>> results = [];
    for (final id in conversationIds.take(50)) {
      final result = await _client
          .from('conversations')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (result != null && result['name'] != null) {
        final name = result['name'].toString().toLowerCase();
        if (name.contains(query.toLowerCase())) {
          results.add(result);
        }
      }
    }

    return results;
  }
}
