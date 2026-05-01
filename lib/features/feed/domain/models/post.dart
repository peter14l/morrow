import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    @JsonKey(name: 'userId') required String userId,
    required String username,
    @JsonKey(name: 'userAvatar') required String userAvatar,
    String? content,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @JsonKey(name: 'dominant_color') String? dominantColor,
    @Default([]) @JsonKey(name: 'media_urls') List<String> mediaUrls,
    @Default([]) @JsonKey(name: 'media_types') List<String> mediaTypes,
    @Default([]) List<String> hashtags,
    @Default(false) @JsonKey(name: 'is_spoiler') bool isSpoiler,
    @JsonKey(name: 'community_id') String? communityId,
    @JsonKey(name: 'community_name') String? communityName,
    @JsonKey(name: 'circle_id') String? circleId,
    required DateTime timestamp,
    @Default(0) int likes,
    @Default(0) int comments,
    @Default(0) int shares,
    @Default(false) @JsonKey(name: 'isLiked') bool isLiked,
    @Default(false) @JsonKey(name: 'isBookmarked') bool isBookmarked,
    @Default(false) @JsonKey(name: 'isAd') bool isAd,
    @Default(false) @JsonKey(name: 'isVerified') bool isVerified,
    @JsonKey(name: 'storage_provider') String? storageProvider,
    String? mood,
    EnhancedPoll? poll,
  }) = _Post;

  const Post._();

  factory Post.fromJson(Map<String, dynamic> json) =>
      _$PostFromJson(_normalizePostJson(json));

  static Map<String, dynamic> _normalizePostJson(Map<String, dynamic> json) {
    final Map<String, dynamic> normalized = Map.from(json);
    normalized['userId'] = json['user_id'] ?? json['userId'];
    normalized['username'] = json['username'] ?? json['full_name'] ?? '';
    normalized['userAvatar'] =
        json['user_avatar'] ?? json['avatar_url'] ?? json['userAvatar'] ?? '';
    normalized['imageUrl'] = json['image_url'] ?? json['imageUrl'];
    normalized['likes'] = json['likes_count'] ?? json['likes'] ?? 0;
    normalized['comments'] = json['comments_count'] ?? json['comments'] ?? 0;
    normalized['shares'] = json['shares_count'] ?? json['shares'] ?? 0;
    normalized['storage_provider'] = json['storage_provider'] ?? json['storageProvider'];
    normalized['timestamp'] =
        json['created_at'] ??
        json['timestamp'] ??
        DateTime.now().toIso8601String();
    normalized['isLiked'] = json['is_liked'] ?? json['isLiked'] ?? false;
    normalized['isBookmarked'] =
        json['is_bookmarked'] ?? json['isBookmarked'] ?? false;
    normalized['isAd'] = json['is_ad'] ?? json['isAd'] ?? false;
    normalized['isVerified'] =
        json['is_verified'] ?? json['isVerified'] ?? false;

    // Handle nested poll data from Supabase
    if (json['polls'] != null) {
      final pollsList = json['polls'] as List;
      if (pollsList.isNotEmpty) {
        normalized['poll'] = pollsList.first;
      }
    } else if (json['poll'] != null) {
      normalized['poll'] = json['poll'];
    }

    return normalized;
  }
}
