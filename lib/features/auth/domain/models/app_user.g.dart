// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String? ?? '',
  username: json['username'] as String? ?? 'user',
  email: json['email'] as String? ?? '',
  displayName: json['displayName'] as String?,
  photoUrl: json['photoUrl'] as String?,
  bio: json['bio'] as String?,
  location: json['location'] as String?,
  website: json['website'] as String?,
  joinedDate: json['joinedDate'] == null
      ? null
      : DateTime.parse(json['joinedDate'] as String),
  followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
  postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
  isVerified: json['isVerified'] as bool? ?? false,
  isPrivate: json['isPrivate'] as bool? ?? false,
  bannerUrl: json['bannerUrl'] as String?,
  bannerColor: json['bannerColor'] as String?,
  isPro: json['isPro'] as bool? ?? false,
  userMetadata: json['userMetadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'bio': instance.bio,
  'location': instance.location,
  'website': instance.website,
  'joinedDate': instance.joinedDate?.toIso8601String(),
  'followersCount': instance.followersCount,
  'followingCount': instance.followingCount,
  'postsCount': instance.postsCount,
  'isVerified': instance.isVerified,
  'isPrivate': instance.isPrivate,
  'bannerUrl': instance.bannerUrl,
  'bannerColor': instance.bannerColor,
  'isPro': instance.isPro,
  'userMetadata': instance.userMetadata,
};
