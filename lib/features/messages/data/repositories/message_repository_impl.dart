import 'package:oasis/features/messages/data/datasources/message_remote_datasource.dart';
import 'package:oasis/features/messages/domain/models/message_entity.dart';
import 'package:oasis/features/messages/domain/repositories/message_repository.dart';

/// Implementation of MessageRepository
class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDatasource _remoteDatasource;

  MessageRepositoryImpl({MessageRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? MessageRemoteDatasource();

  @override
  Future<List<MessageEntity>> getMessages({
    required String conversationId,
    int limit = 50,
    String? before,
  }) async {
    final results = await _remoteDatasource.getMessages(
      conversationId: conversationId,
      limit: limit,
      before: before,
    );

    return results.map((json) => _messageFromJson(json)).toList();
  }

  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageTypeEntity type = MessageTypeEntity.text,
    String? mediaUrl,
    String? mediaFileName,
    String? replyToId,
    String? rippleId,
    String? storyId,
  }) async {
    final typeString = _typeToString(type);

    final result = await _remoteDatasource.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      type: typeString,
      mediaUrl: mediaUrl,
      mediaFileName: mediaFileName,
      replyToId: replyToId,
      rippleId: rippleId,
      storyId: storyId,
    );

    return _messageFromJson(result);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _remoteDatasource.deleteMessage(messageId);
  }

  @override
  Future<MessageReactionEntity> reactToMessage({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final result = await _remoteDatasource.addReaction(
      messageId: messageId,
      userId: userId,
      emoji: emoji,
    );

    return _reactionFromJson(result);
  }

  @override
  Future<void> removeReaction(String messageId, String userId) async {
    await _remoteDatasource.removeReaction(messageId, userId);
  }

  @override
  Future<List<MessageReactionEntity>> getReactions(String messageId) async {
    final results = await _remoteDatasource.getReactions(messageId);
    return results.map((json) => _reactionFromJson(json)).toList();
  }

  // Helper methods for mapping
  MessageEntity _messageFromJson(Map<String, dynamic> json) {
    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      type: _typeFromString(json['type'] as String? ?? 'text'),
      mediaUrl: json['media_url'] as String?,
      mediaFileName: json['media_file_name'] as String?,
      replyToId: json['reply_to_id'] as String?,
      rippleId: json['ripple_id'] as String?,
      storyId: json['story_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isDeleted: json['deleted_at'] != null,
    );
  }

  MessageReactionEntity _reactionFromJson(Map<String, dynamic> json) {
    return MessageReactionEntity(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String _typeToString(MessageTypeEntity type) {
    switch (type) {
      case MessageTypeEntity.text:
        return 'text';
      case MessageTypeEntity.image:
        return 'image';
      case MessageTypeEntity.video:
        return 'video';
      case MessageTypeEntity.document:
        return 'document';
      case MessageTypeEntity.voice:
        return 'voice';
      case MessageTypeEntity.system:
        return 'system';
    }
  }

  MessageTypeEntity _typeFromString(String type) {
    switch (type) {
      case 'image':
        return MessageTypeEntity.image;
      case 'video':
        return MessageTypeEntity.video;
      case 'document':
        return MessageTypeEntity.document;
      case 'voice':
        return MessageTypeEntity.voice;
      case 'system':
        return MessageTypeEntity.system;
      default:
        return MessageTypeEntity.text;
    }
  }
}
