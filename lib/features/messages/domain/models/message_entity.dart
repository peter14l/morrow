/// Message entity for the domain layer
class MessageEntity {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageTypeEntity type;
  final String? mediaUrl;
  final String? mediaFileName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final String? replyToId;
  final String? rippleId;
  final String? storyId;
  final List<MessageReactionEntity> reactions;
  final MessageStatusEntity status;

  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.mediaFileName,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.replyToId,
    this.rippleId,
    this.storyId,
    this.reactions = const [],
    this.status = MessageStatusEntity.sent,
  });

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      type: MessageTypeEntity.values.firstWhere(
        (e) => e.name == (json['message_type'] as String? ?? 'text'),
        orElse: () => MessageTypeEntity.text,
      ),
      mediaUrl: json['media_url'] as String?,
      mediaFileName: json['media_file_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      replyToId: json['reply_to_id'] as String?,
      rippleId: json['ripple_id'] as String?,
      storyId: json['story_id'] as String?,
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    MessageReactionEntity.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      status: MessageStatusEntity.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'sent'),
        orElse: () => MessageStatusEntity.sent,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': type.name,
      'media_url': mediaUrl,
      'media_file_name': mediaFileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'reply_to_id': replyToId,
      'ripple_id': rippleId,
      'story_id': storyId,
      'status': status.name,
    };
  }

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageTypeEntity? type,
    String? mediaUrl,
    String? mediaFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? replyToId,
    String? rippleId,
    String? storyId,
    List<MessageReactionEntity>? reactions,
    MessageStatusEntity? status,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaFileName: mediaFileName ?? this.mediaFileName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId ?? this.replyToId,
      rippleId: rippleId ?? this.rippleId,
      storyId: storyId ?? this.storyId,
      reactions: reactions ?? this.reactions,
      status: status ?? this.status,
    );
  }
}

/// Message type enum
enum MessageTypeEntity { text, image, video, document, voice, system }

/// Message status enum
enum MessageStatusEntity { sending, sent, delivered, read, failed }

/// Reaction entity
class MessageReactionEntity {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  const MessageReactionEntity({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReactionEntity.fromJson(Map<String, dynamic> json) {
    return MessageReactionEntity(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
