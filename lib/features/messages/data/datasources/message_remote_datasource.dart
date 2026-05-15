import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Remote datasource for message operations
class MessageRemoteDatasource {
  final SupabaseClient _client;

  MessageRemoteDatasource({SupabaseClient? client})
    : _client = client ?? SupabaseService().client;

  /// Get messages for a conversation
  Future<List<Map<String, dynamic>>> getMessages({
    required String conversationId,
    int limit = 50,
    String? before,
  }) async {
    final query = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (before != null) {
      // Get the timestamp of the 'before' message
      final beforeMsg = await _client
          .from('messages')
          .select('created_at')
          .eq('id', before)
          .single();
      // Filter by timestamp instead of using .lt() on the builder
      final allMessages = await query;
      return allMessages
          .where(
            (m) =>
                m['created_at'] != null &&
                m['created_at'].toString().compareTo(
                      beforeMsg['created_at'].toString(),
                    ) <
                    0,
          )
          .toList();
    }

    return await query;
  }

  /// Send a new message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    required String type,
    String? mediaUrl,
    String? mediaFileName,
    String? replyToId,
    String? rippleId,
    String? storyId,
  }) async {
    final messageData = {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaFileName != null) 'media_file_name': mediaFileName,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (rippleId != null) 'ripple_id': rippleId,
      if (storyId != null) 'story_id': storyId,
    };

    final response = await _client
        .from('messages')
        .insert(messageData)
        .select()
        .single();

    return response;
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  /// Add reaction to a message
  Future<Map<String, dynamic>> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final reactionData = {
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    };

    final response = await _client
        .from('message_reactions')
        .insert(reactionData)
        .select()
        .single();

    return response;
  }

  /// Remove reaction from a message
  Future<void> removeReaction(String messageId, String userId) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId);
  }

  /// Get reactions for a message
  Future<List<Map<String, dynamic>>> getReactions(String messageId) async {
    return await _client
        .from('message_reactions')
        .select()
        .eq('message_id', messageId);
  }

  /// Mark message as read
  Future<void> markAsRead(String messageId, String userId) async {
    await _client.from('message_read_status').upsert({
      'message_id': messageId,
      'user_id': userId,
      'read_at': DateTime.now().toIso8601String(),
    });
  }
}
