import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    @Default('') String id,
    @JsonKey(name: 'userId') @Default('') String userId,
    @Default('user') String username,
    @JsonKey(name: 'userAvatar') @Default('') String userAvatar,
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
    @Default([]) List<Map<String, dynamic>> collaborators,
  }) = _Post;

  const Post._();

  factory Post.fromJson(Map<String, dynamic> json) =>
      _$PostFromJson(_normalizePostJson(json));

  static Map<String, dynamic> _normalizePostJson(Map<String, dynamic> json) {
    final Map<String, dynamic> normalized = Map.from(json);

    // Handle nested profile data if present (e.g. from joined selects)
    final profile = json['profiles'] ?? json['user'];
    if (profile != null && profile is Map<String, dynamic>) {
      normalized['username'] =
          profile['username'] ?? profile['full_name'] ?? normalized['username'];
      normalized['userAvatar'] =
          profile['avatar_url'] ??
          profile['user_avatar'] ??
          normalized['user_avatar'] ??
          normalized['userAvatar'];
      normalized['isVerified'] =
          profile['is_verified'] ??
          normalized['is_verified'] ??
          normalized['isVerified'];
    }

    normalized['userId'] = json['user_id'] ?? json['userId'];
    normalized['username'] =
        normalized['username'] ?? json['username'] ?? json['full_name'] ?? '';
    normalized['userAvatar'] =
        normalized['userAvatar'] ??
        json['user_avatar'] ??
        json['avatar_url'] ??
        json['userAvatar'] ??
        '';
    normalized['image_url'] = json['image_url'] ?? json['imageUrl'];
    normalized['likes'] = json['likes_count'] ?? json['likes'] ?? 0;
    normalized['comments'] = json['comments_count'] ?? json['comments'] ?? 0;
    normalized['shares'] = json['shares_count'] ?? json['shares'] ?? 0;
    normalized['storage_provider'] =
        json['storage_provider'] ?? json['storageProvider'];
    normalized['timestamp'] =
        json['created_at'] ??
        json['timestamp'] ??
        DateTime.now().toIso8601String();
    normalized['isLiked'] = json['is_liked'] ?? json['isLiked'] ?? false;
    normalized['isBookmarked'] =
        json['is_bookmarked'] ?? json['isBookmarked'] ?? false;
    normalized['is_ad'] = json['is_ad'] ?? json['isAd'] ?? false;
    normalized['isVerified'] =
        normalized['isVerified'] ??
        json['is_verified'] ??
        json['isVerified'] ??
        false;
    normalized['circle_id'] = json['circle_id'] ?? json['circleId'];

    // Handle nested community data
    final community = json['communities'];
    if (community != null && community is Map<String, dynamic>) {
      normalized['community_name'] =
          community['name'] ?? normalized['community_name'];
    }

    // Handle nested poll data from Supabase
    if (json['polls'] != null) {
      final pollsList = json['polls'] as List;
      if (pollsList.isNotEmpty) {
        normalized['poll'] = pollsList.first;
      }
    } else if (json['poll'] != null) {
      normalized['poll'] = json['poll'];
    }

    if (json['collaborators'] != null) {
      final List<dynamic> collabList = json['collaborators'] as List;
      normalized['collaborators'] = collabList.map((c) {
        final Map<String, dynamic> collab = Map.from(c);
        if (c['profiles'] != null) {
          final profile = c['profiles'];
          collab['username'] = profile['username'];
          collab['user_avatar'] = profile['avatar_url'];
          collab['is_verified'] = profile['is_verified'];
        }
        return collab;
      }).toList();
    }

    return normalized;
  }
}
