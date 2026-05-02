// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: json['id'] as String,
  userId: json['userId'] as String,
  username: json['username'] as String,
  userAvatar: json['userAvatar'] as String,
  content: json['content'] as String?,
  imageUrl: json['image_url'] as String?,
  thumbnailUrl: json['thumbnail_url'] as String?,
  dominantColor: json['dominant_color'] as String?,
  mediaUrls:
      (json['media_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  mediaTypes:
      (json['media_types'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  hashtags:
      (json['hashtags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  isSpoiler: json['is_spoiler'] as bool? ?? false,
  communityId: json['community_id'] as String?,
  communityName: json['community_name'] as String?,
  circleId: json['circle_id'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  likes: (json['likes'] as num?)?.toInt() ?? 0,
  comments: (json['comments'] as num?)?.toInt() ?? 0,
  shares: (json['shares'] as num?)?.toInt() ?? 0,
  isLiked: json['isLiked'] as bool? ?? false,
  isBookmarked: json['isBookmarked'] as bool? ?? false,
  isAd: json['isAd'] as bool? ?? false,
  isVerified: json['isVerified'] as bool? ?? false,
  storageProvider: json['storage_provider'] as String?,
  mood: json['mood'] as String?,
  poll: json['poll'] == null
      ? null
      : EnhancedPoll.fromJson(json['poll'] as Map<String, dynamic>),
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'username': instance.username,
  'userAvatar': instance.userAvatar,
  'content': instance.content,
  'image_url': instance.imageUrl,
  'thumbnail_url': instance.thumbnailUrl,
  'dominant_color': instance.dominantColor,
  'media_urls': instance.mediaUrls,
  'media_types': instance.mediaTypes,
  'hashtags': instance.hashtags,
  'is_spoiler': instance.isSpoiler,
  'community_id': instance.communityId,
  'community_name': instance.communityName,
  'circle_id': instance.circleId,
  'timestamp': instance.timestamp.toIso8601String(),
  'likes': instance.likes,
  'comments': instance.comments,
  'shares': instance.shares,
  'isLiked': instance.isLiked,
  'isBookmarked': instance.isBookmarked,
  'isAd': instance.isAd,
  'isVerified': instance.isVerified,
  'storage_provider': instance.storageProvider,
  'mood': instance.mood,
  'poll': instance.poll,
};
