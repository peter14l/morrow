import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type; // 'like', 'comment', 'follow', 'mention', 'dm'
  final String? title;
  final String? actorId;
  final String? actorName;
  final String? actorAvatar;
  final String? postId;
  final String? commentId;
  final String? messageId;
  final String? message;
  final String? conversationId;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.title,
    this.actorId,
    this.actorName,
    this.actorAvatar,
    this.postId,
    this.commentId,
    this.messageId,
    this.message,
    this.conversationId,
    this.metadata,
    this.isRead = false,
    required this.timestamp,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      actorAvatar: json['actor_avatar'] as String?,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      messageId: json['message_id'] as String?,
      message: (json['content'] ?? json['message']) as String?,
      conversationId:
          json['conversation_id'] as String? ??
          json['metadata']?['conversation_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'actor_id': actorId,
      'actor_name': actorName,
      'actor_avatar': actorAvatar,
      'post_id': postId,
      'comment_id': commentId,
      'message_id': messageId,
      'message': message,
      'conversation_id': conversationId,
      'metadata': metadata,
      'is_read': isRead,
      'created_at': timestamp.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? actorId,
    String? actorName,
    String? actorAvatar,
    String? postId,
    String? commentId,
    String? messageId,
    String? message,
    String? conversationId,
    Map<String, dynamic>? metadata,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      messageId: messageId ?? this.messageId,
      message: message ?? this.message,
      conversationId: conversationId ?? this.conversationId,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;

    switch (type) {
      case 'dm':
        return actorName ?? 'New Message';
      case 'like':
        return 'New Like';
      case 'comment':
        return 'New Comment';
      case 'follow':
        return 'New Follower';
      case 'follow_request':
        return 'Follow Request';
      case 'mention':
        return 'Mentioned You';
      case 'canvas_pulse':
        return 'Canvas Pulse';
      default:
        return 'New Notification';
    }
  }

  String getNotificationText() {
    switch (type) {
      case 'like':
        return '${actorName ?? 'Someone'} liked your post';
      case 'comment':
        return '${actorName ?? 'Someone'} commented on your post';
      case 'follow':
        return '${actorName ?? 'Someone'} started following you';
      case 'follow_request':
        return '${actorName ?? 'Someone'} requested to follow you';
      case 'mention':
        return '${actorName ?? 'Someone'} mentioned you in a comment';
      case 'dm':
        return message ?? 'New message';
      case 'canvas_pulse':
        return '${actorName ?? 'Someone'} ${message ?? 'is on the Canvas'}';
      default:
        return message ?? 'New notification';
    }
  }

  IconData getNotificationIcon() {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      case 'follow_request':
        return Icons.person_add_alt_1_rounded;
      case 'mention':
        return Icons.alternate_email;
      case 'dm':
        return Icons.chat_outlined;
      case 'canvas_pulse':
        return Icons.blur_on_rounded;
      default:
        return Icons.notifications;
    }
  }
}

enum NotificationType {
  like,
  comment,
  follow,
  follow_request,
  mention,
  dm,
  ripple,
  system,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.like:
        return 'Like';
      case NotificationType.comment:
        return 'Comment';
      case NotificationType.follow:
        return 'Follow';
      case NotificationType.follow_request:
        return 'Follow Request';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.dm:
        return 'Message';
      case NotificationType.ripple:
        return 'Ripple';
      case NotificationType.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.follow_request:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.dm:
        return Icons.message;
      case NotificationType.ripple:
        return Icons.waves;
      case NotificationType.system:
        return Icons.info;
    }
  }
}
