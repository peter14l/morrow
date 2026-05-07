// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Comment _$CommentFromJson(Map<String, dynamic> json) => _Comment(
  id: json['id'] as String? ?? '',
  postId: json['post_id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  parentCommentId: json['parent_comment_id'] as String?,
  username: json['username'] as String? ?? 'user',
  userAvatar: json['user_avatar'] as String? ?? '',
  content: json['content'] as String? ?? '',
  likes: (json['likes_count'] as num?)?.toInt() ?? 0,
  repliesCount: (json['replies_count'] as num?)?.toInt() ?? 0,
  isLiked: json['is_liked'] as bool? ?? false,
  timestamp: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CommentToJson(_Comment instance) => <String, dynamic>{
  'id': instance.id,
  'post_id': instance.postId,
  'user_id': instance.userId,
  'parent_comment_id': instance.parentCommentId,
  'username': instance.username,
  'user_avatar': instance.userAvatar,
  'content': instance.content,
  'likes_count': instance.likes,
  'replies_count': instance.repliesCount,
  'is_liked': instance.isLiked,
  'created_at': instance.timestamp.toIso8601String(),
};
