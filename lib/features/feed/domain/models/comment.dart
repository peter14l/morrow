import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    @Default('') String id,
    @JsonKey(name: 'post_id') @Default('') String postId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @Default('user') String username,
    @JsonKey(name: 'user_avatar') @Default('') String userAvatar,
    @Default('') String content,
    @Default(0) @JsonKey(name: 'likes_count') int likes,
    @Default(0) @JsonKey(name: 'replies_count') int repliesCount,
    @Default(false) @JsonKey(name: 'is_liked') bool isLiked,
    @JsonKey(name: 'created_at') required DateTime timestamp,
  }) = _Comment;

  const Comment._();

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(_normalizeCommentJson(json));

  static Map<String, dynamic> _normalizeCommentJson(Map<String, dynamic> json) {
    final Map<String, dynamic> normalized = Map.from(json);

    // Handle nested profile data if present
    final profile = json['profiles'];
    if (profile != null && profile is Map<String, dynamic>) {
      normalized['username'] = profile['username'] ?? normalized['username'];
      normalized['user_avatar'] =
          profile['avatar_url'] ?? normalized['user_avatar'];
    }

    normalized['user_avatar'] =
        normalized['user_avatar'] ??
        json['user_avatar'] ??
        json['avatar_url'] ??
        '';
    normalized['likes_count'] = json['likes_count'] ?? json['likes'] ?? 0;
    normalized['replies_count'] = json['replies_count'] ?? json['replies'] ?? 0;
    normalized['is_liked'] = json['is_liked'] ?? false;
    normalized['created_at'] =
        json['created_at'] ?? DateTime.now().toIso8601String();
    return normalized;
  }
}
