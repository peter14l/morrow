// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

 String get id;@JsonKey(name: 'userId') String get userId; String get username;@JsonKey(name: 'userAvatar') String get userAvatar; String? get content;@JsonKey(name: 'image_url') String? get imageUrl;@JsonKey(name: 'thumbnail_url') String? get thumbnailUrl;@JsonKey(name: 'dominant_color') String? get dominantColor;@JsonKey(name: 'media_urls') List<String> get mediaUrls;@JsonKey(name: 'media_types') List<String> get mediaTypes; List<String> get hashtags;@JsonKey(name: 'is_spoiler') bool get isSpoiler;@JsonKey(name: 'community_id') String? get communityId;@JsonKey(name: 'community_name') String? get communityName;@JsonKey(name: 'circle_id') String? get circleId; DateTime get timestamp; int get likes; int get comments; int get shares;@JsonKey(name: 'isLiked') bool get isLiked;@JsonKey(name: 'isBookmarked') bool get isBookmarked;@JsonKey(name: 'isAd') bool get isAd;@JsonKey(name: 'isVerified') bool get isVerified;@JsonKey(name: 'storage_provider') String? get storageProvider; String? get mood; EnhancedPoll? get poll; List<Map<String, dynamic>> get collaborators;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.userAvatar, userAvatar) || other.userAvatar == userAvatar)&&(identical(other.content, content) || other.content == content)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.dominantColor, dominantColor) || other.dominantColor == dominantColor)&&const DeepCollectionEquality().equals(other.mediaUrls, mediaUrls)&&const DeepCollectionEquality().equals(other.mediaTypes, mediaTypes)&&const DeepCollectionEquality().equals(other.hashtags, hashtags)&&(identical(other.isSpoiler, isSpoiler) || other.isSpoiler == isSpoiler)&&(identical(other.communityId, communityId) || other.communityId == communityId)&&(identical(other.communityName, communityName) || other.communityName == communityName)&&(identical(other.circleId, circleId) || other.circleId == circleId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.likes, likes) || other.likes == likes)&&(identical(other.comments, comments) || other.comments == comments)&&(identical(other.shares, shares) || other.shares == shares)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isAd, isAd) || other.isAd == isAd)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.storageProvider, storageProvider) || other.storageProvider == storageProvider)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.poll, poll) || other.poll == poll)&&const DeepCollectionEquality().equals(other.collaborators, collaborators));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,username,userAvatar,content,imageUrl,thumbnailUrl,dominantColor,const DeepCollectionEquality().hash(mediaUrls),const DeepCollectionEquality().hash(mediaTypes),const DeepCollectionEquality().hash(hashtags),isSpoiler,communityId,communityName,circleId,timestamp,likes,comments,shares,isLiked,isBookmarked,isAd,isVerified,storageProvider,mood,poll,const DeepCollectionEquality().hash(collaborators)]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, username: $username, userAvatar: $userAvatar, content: $content, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, dominantColor: $dominantColor, mediaUrls: $mediaUrls, mediaTypes: $mediaTypes, hashtags: $hashtags, isSpoiler: $isSpoiler, communityId: $communityId, communityName: $communityName, circleId: $circleId, timestamp: $timestamp, likes: $likes, comments: $comments, shares: $shares, isLiked: $isLiked, isBookmarked: $isBookmarked, isAd: $isAd, isVerified: $isVerified, storageProvider: $storageProvider, mood: $mood, poll: $poll, collaborators: $collaborators)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'userId') String userId, String username,@JsonKey(name: 'userAvatar') String userAvatar, String? content,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl,@JsonKey(name: 'dominant_color') String? dominantColor,@JsonKey(name: 'media_urls') List<String> mediaUrls,@JsonKey(name: 'media_types') List<String> mediaTypes, List<String> hashtags,@JsonKey(name: 'is_spoiler') bool isSpoiler,@JsonKey(name: 'community_id') String? communityId,@JsonKey(name: 'community_name') String? communityName,@JsonKey(name: 'circle_id') String? circleId, DateTime timestamp, int likes, int comments, int shares,@JsonKey(name: 'isLiked') bool isLiked,@JsonKey(name: 'isBookmarked') bool isBookmarked,@JsonKey(name: 'isAd') bool isAd,@JsonKey(name: 'isVerified') bool isVerified,@JsonKey(name: 'storage_provider') String? storageProvider, String? mood, EnhancedPoll? poll, List<Map<String, dynamic>> collaborators
});




}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? username = null,Object? userAvatar = null,Object? content = freezed,Object? imageUrl = freezed,Object? thumbnailUrl = freezed,Object? dominantColor = freezed,Object? mediaUrls = null,Object? mediaTypes = null,Object? hashtags = null,Object? isSpoiler = null,Object? communityId = freezed,Object? communityName = freezed,Object? circleId = freezed,Object? timestamp = null,Object? likes = null,Object? comments = null,Object? shares = null,Object? isLiked = null,Object? isBookmarked = null,Object? isAd = null,Object? isVerified = null,Object? storageProvider = freezed,Object? mood = freezed,Object? poll = freezed,Object? collaborators = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,userAvatar: null == userAvatar ? _self.userAvatar : userAvatar // ignore: cast_nullable_to_non_nullable
as String,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,dominantColor: freezed == dominantColor ? _self.dominantColor : dominantColor // ignore: cast_nullable_to_non_nullable
as String?,mediaUrls: null == mediaUrls ? _self.mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,mediaTypes: null == mediaTypes ? _self.mediaTypes : mediaTypes // ignore: cast_nullable_to_non_nullable
as List<String>,hashtags: null == hashtags ? _self.hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<String>,isSpoiler: null == isSpoiler ? _self.isSpoiler : isSpoiler // ignore: cast_nullable_to_non_nullable
as bool,communityId: freezed == communityId ? _self.communityId : communityId // ignore: cast_nullable_to_non_nullable
as String?,communityName: freezed == communityName ? _self.communityName : communityName // ignore: cast_nullable_to_non_nullable
as String?,circleId: freezed == circleId ? _self.circleId : circleId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,likes: null == likes ? _self.likes : likes // ignore: cast_nullable_to_non_nullable
as int,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as int,shares: null == shares ? _self.shares : shares // ignore: cast_nullable_to_non_nullable
as int,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isAd: null == isAd ? _self.isAd : isAd // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,storageProvider: freezed == storageProvider ? _self.storageProvider : storageProvider // ignore: cast_nullable_to_non_nullable
as String?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as String?,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as EnhancedPoll?,collaborators: null == collaborators ? _self.collaborators : collaborators // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String userId,  String username, @JsonKey(name: 'userAvatar')  String userAvatar,  String? content, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'dominant_color')  String? dominantColor, @JsonKey(name: 'media_urls')  List<String> mediaUrls, @JsonKey(name: 'media_types')  List<String> mediaTypes,  List<String> hashtags, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'community_id')  String? communityId, @JsonKey(name: 'community_name')  String? communityName, @JsonKey(name: 'circle_id')  String? circleId,  DateTime timestamp,  int likes,  int comments,  int shares, @JsonKey(name: 'isLiked')  bool isLiked, @JsonKey(name: 'isBookmarked')  bool isBookmarked, @JsonKey(name: 'isAd')  bool isAd, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'storage_provider')  String? storageProvider,  String? mood,  EnhancedPoll? poll,  List<Map<String, dynamic>> collaborators)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.username,_that.userAvatar,_that.content,_that.imageUrl,_that.thumbnailUrl,_that.dominantColor,_that.mediaUrls,_that.mediaTypes,_that.hashtags,_that.isSpoiler,_that.communityId,_that.communityName,_that.circleId,_that.timestamp,_that.likes,_that.comments,_that.shares,_that.isLiked,_that.isBookmarked,_that.isAd,_that.isVerified,_that.storageProvider,_that.mood,_that.poll,_that.collaborators);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'userId')  String userId,  String username, @JsonKey(name: 'userAvatar')  String userAvatar,  String? content, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'dominant_color')  String? dominantColor, @JsonKey(name: 'media_urls')  List<String> mediaUrls, @JsonKey(name: 'media_types')  List<String> mediaTypes,  List<String> hashtags, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'community_id')  String? communityId, @JsonKey(name: 'community_name')  String? communityName, @JsonKey(name: 'circle_id')  String? circleId,  DateTime timestamp,  int likes,  int comments,  int shares, @JsonKey(name: 'isLiked')  bool isLiked, @JsonKey(name: 'isBookmarked')  bool isBookmarked, @JsonKey(name: 'isAd')  bool isAd, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'storage_provider')  String? storageProvider,  String? mood,  EnhancedPoll? poll,  List<Map<String, dynamic>> collaborators)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.userId,_that.username,_that.userAvatar,_that.content,_that.imageUrl,_that.thumbnailUrl,_that.dominantColor,_that.mediaUrls,_that.mediaTypes,_that.hashtags,_that.isSpoiler,_that.communityId,_that.communityName,_that.circleId,_that.timestamp,_that.likes,_that.comments,_that.shares,_that.isLiked,_that.isBookmarked,_that.isAd,_that.isVerified,_that.storageProvider,_that.mood,_that.poll,_that.collaborators);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'userId')  String userId,  String username, @JsonKey(name: 'userAvatar')  String userAvatar,  String? content, @JsonKey(name: 'image_url')  String? imageUrl, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl, @JsonKey(name: 'dominant_color')  String? dominantColor, @JsonKey(name: 'media_urls')  List<String> mediaUrls, @JsonKey(name: 'media_types')  List<String> mediaTypes,  List<String> hashtags, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'community_id')  String? communityId, @JsonKey(name: 'community_name')  String? communityName, @JsonKey(name: 'circle_id')  String? circleId,  DateTime timestamp,  int likes,  int comments,  int shares, @JsonKey(name: 'isLiked')  bool isLiked, @JsonKey(name: 'isBookmarked')  bool isBookmarked, @JsonKey(name: 'isAd')  bool isAd, @JsonKey(name: 'isVerified')  bool isVerified, @JsonKey(name: 'storage_provider')  String? storageProvider,  String? mood,  EnhancedPoll? poll,  List<Map<String, dynamic>> collaborators)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.username,_that.userAvatar,_that.content,_that.imageUrl,_that.thumbnailUrl,_that.dominantColor,_that.mediaUrls,_that.mediaTypes,_that.hashtags,_that.isSpoiler,_that.communityId,_that.communityName,_that.circleId,_that.timestamp,_that.likes,_that.comments,_that.shares,_that.isLiked,_that.isBookmarked,_that.isAd,_that.isVerified,_that.storageProvider,_that.mood,_that.poll,_that.collaborators);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post extends Post {
  const _Post({this.id = '', @JsonKey(name: 'userId') this.userId = '', this.username = 'user', @JsonKey(name: 'userAvatar') this.userAvatar = '', this.content, @JsonKey(name: 'image_url') this.imageUrl, @JsonKey(name: 'thumbnail_url') this.thumbnailUrl, @JsonKey(name: 'dominant_color') this.dominantColor, @JsonKey(name: 'media_urls') final  List<String> mediaUrls = const [], @JsonKey(name: 'media_types') final  List<String> mediaTypes = const [], final  List<String> hashtags = const [], @JsonKey(name: 'is_spoiler') this.isSpoiler = false, @JsonKey(name: 'community_id') this.communityId, @JsonKey(name: 'community_name') this.communityName, @JsonKey(name: 'circle_id') this.circleId, required this.timestamp, this.likes = 0, this.comments = 0, this.shares = 0, @JsonKey(name: 'isLiked') this.isLiked = false, @JsonKey(name: 'isBookmarked') this.isBookmarked = false, @JsonKey(name: 'isAd') this.isAd = false, @JsonKey(name: 'isVerified') this.isVerified = false, @JsonKey(name: 'storage_provider') this.storageProvider, this.mood, this.poll, final  List<Map<String, dynamic>> collaborators = const []}): _mediaUrls = mediaUrls,_mediaTypes = mediaTypes,_hashtags = hashtags,_collaborators = collaborators,super._();
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'userId') final  String userId;
@override@JsonKey() final  String username;
@override@JsonKey(name: 'userAvatar') final  String userAvatar;
@override final  String? content;
@override@JsonKey(name: 'image_url') final  String? imageUrl;
@override@JsonKey(name: 'thumbnail_url') final  String? thumbnailUrl;
@override@JsonKey(name: 'dominant_color') final  String? dominantColor;
 final  List<String> _mediaUrls;
@override@JsonKey(name: 'media_urls') List<String> get mediaUrls {
  if (_mediaUrls is EqualUnmodifiableListView) return _mediaUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mediaUrls);
}

 final  List<String> _mediaTypes;
@override@JsonKey(name: 'media_types') List<String> get mediaTypes {
  if (_mediaTypes is EqualUnmodifiableListView) return _mediaTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mediaTypes);
}

 final  List<String> _hashtags;
@override@JsonKey() List<String> get hashtags {
  if (_hashtags is EqualUnmodifiableListView) return _hashtags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hashtags);
}

@override@JsonKey(name: 'is_spoiler') final  bool isSpoiler;
@override@JsonKey(name: 'community_id') final  String? communityId;
@override@JsonKey(name: 'community_name') final  String? communityName;
@override@JsonKey(name: 'circle_id') final  String? circleId;
@override final  DateTime timestamp;
@override@JsonKey() final  int likes;
@override@JsonKey() final  int comments;
@override@JsonKey() final  int shares;
@override@JsonKey(name: 'isLiked') final  bool isLiked;
@override@JsonKey(name: 'isBookmarked') final  bool isBookmarked;
@override@JsonKey(name: 'isAd') final  bool isAd;
@override@JsonKey(name: 'isVerified') final  bool isVerified;
@override@JsonKey(name: 'storage_provider') final  String? storageProvider;
@override final  String? mood;
@override final  EnhancedPoll? poll;
 final  List<Map<String, dynamic>> _collaborators;
@override@JsonKey() List<Map<String, dynamic>> get collaborators {
  if (_collaborators is EqualUnmodifiableListView) return _collaborators;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_collaborators);
}


/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.userAvatar, userAvatar) || other.userAvatar == userAvatar)&&(identical(other.content, content) || other.content == content)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.dominantColor, dominantColor) || other.dominantColor == dominantColor)&&const DeepCollectionEquality().equals(other._mediaUrls, _mediaUrls)&&const DeepCollectionEquality().equals(other._mediaTypes, _mediaTypes)&&const DeepCollectionEquality().equals(other._hashtags, _hashtags)&&(identical(other.isSpoiler, isSpoiler) || other.isSpoiler == isSpoiler)&&(identical(other.communityId, communityId) || other.communityId == communityId)&&(identical(other.communityName, communityName) || other.communityName == communityName)&&(identical(other.circleId, circleId) || other.circleId == circleId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.likes, likes) || other.likes == likes)&&(identical(other.comments, comments) || other.comments == comments)&&(identical(other.shares, shares) || other.shares == shares)&&(identical(other.isLiked, isLiked) || other.isLiked == isLiked)&&(identical(other.isBookmarked, isBookmarked) || other.isBookmarked == isBookmarked)&&(identical(other.isAd, isAd) || other.isAd == isAd)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.storageProvider, storageProvider) || other.storageProvider == storageProvider)&&(identical(other.mood, mood) || other.mood == mood)&&(identical(other.poll, poll) || other.poll == poll)&&const DeepCollectionEquality().equals(other._collaborators, _collaborators));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,username,userAvatar,content,imageUrl,thumbnailUrl,dominantColor,const DeepCollectionEquality().hash(_mediaUrls),const DeepCollectionEquality().hash(_mediaTypes),const DeepCollectionEquality().hash(_hashtags),isSpoiler,communityId,communityName,circleId,timestamp,likes,comments,shares,isLiked,isBookmarked,isAd,isVerified,storageProvider,mood,poll,const DeepCollectionEquality().hash(_collaborators)]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, username: $username, userAvatar: $userAvatar, content: $content, imageUrl: $imageUrl, thumbnailUrl: $thumbnailUrl, dominantColor: $dominantColor, mediaUrls: $mediaUrls, mediaTypes: $mediaTypes, hashtags: $hashtags, isSpoiler: $isSpoiler, communityId: $communityId, communityName: $communityName, circleId: $circleId, timestamp: $timestamp, likes: $likes, comments: $comments, shares: $shares, isLiked: $isLiked, isBookmarked: $isBookmarked, isAd: $isAd, isVerified: $isVerified, storageProvider: $storageProvider, mood: $mood, poll: $poll, collaborators: $collaborators)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'userId') String userId, String username,@JsonKey(name: 'userAvatar') String userAvatar, String? content,@JsonKey(name: 'image_url') String? imageUrl,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl,@JsonKey(name: 'dominant_color') String? dominantColor,@JsonKey(name: 'media_urls') List<String> mediaUrls,@JsonKey(name: 'media_types') List<String> mediaTypes, List<String> hashtags,@JsonKey(name: 'is_spoiler') bool isSpoiler,@JsonKey(name: 'community_id') String? communityId,@JsonKey(name: 'community_name') String? communityName,@JsonKey(name: 'circle_id') String? circleId, DateTime timestamp, int likes, int comments, int shares,@JsonKey(name: 'isLiked') bool isLiked,@JsonKey(name: 'isBookmarked') bool isBookmarked,@JsonKey(name: 'isAd') bool isAd,@JsonKey(name: 'isVerified') bool isVerified,@JsonKey(name: 'storage_provider') String? storageProvider, String? mood, EnhancedPoll? poll, List<Map<String, dynamic>> collaborators
});




}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? username = null,Object? userAvatar = null,Object? content = freezed,Object? imageUrl = freezed,Object? thumbnailUrl = freezed,Object? dominantColor = freezed,Object? mediaUrls = null,Object? mediaTypes = null,Object? hashtags = null,Object? isSpoiler = null,Object? communityId = freezed,Object? communityName = freezed,Object? circleId = freezed,Object? timestamp = null,Object? likes = null,Object? comments = null,Object? shares = null,Object? isLiked = null,Object? isBookmarked = null,Object? isAd = null,Object? isVerified = null,Object? storageProvider = freezed,Object? mood = freezed,Object? poll = freezed,Object? collaborators = null,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,userAvatar: null == userAvatar ? _self.userAvatar : userAvatar // ignore: cast_nullable_to_non_nullable
as String,content: freezed == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,dominantColor: freezed == dominantColor ? _self.dominantColor : dominantColor // ignore: cast_nullable_to_non_nullable
as String?,mediaUrls: null == mediaUrls ? _self._mediaUrls : mediaUrls // ignore: cast_nullable_to_non_nullable
as List<String>,mediaTypes: null == mediaTypes ? _self._mediaTypes : mediaTypes // ignore: cast_nullable_to_non_nullable
as List<String>,hashtags: null == hashtags ? _self._hashtags : hashtags // ignore: cast_nullable_to_non_nullable
as List<String>,isSpoiler: null == isSpoiler ? _self.isSpoiler : isSpoiler // ignore: cast_nullable_to_non_nullable
as bool,communityId: freezed == communityId ? _self.communityId : communityId // ignore: cast_nullable_to_non_nullable
as String?,communityName: freezed == communityName ? _self.communityName : communityName // ignore: cast_nullable_to_non_nullable
as String?,circleId: freezed == circleId ? _self.circleId : circleId // ignore: cast_nullable_to_non_nullable
as String?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,likes: null == likes ? _self.likes : likes // ignore: cast_nullable_to_non_nullable
as int,comments: null == comments ? _self.comments : comments // ignore: cast_nullable_to_non_nullable
as int,shares: null == shares ? _self.shares : shares // ignore: cast_nullable_to_non_nullable
as int,isLiked: null == isLiked ? _self.isLiked : isLiked // ignore: cast_nullable_to_non_nullable
as bool,isBookmarked: null == isBookmarked ? _self.isBookmarked : isBookmarked // ignore: cast_nullable_to_non_nullable
as bool,isAd: null == isAd ? _self.isAd : isAd // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,storageProvider: freezed == storageProvider ? _self.storageProvider : storageProvider // ignore: cast_nullable_to_non_nullable
as String?,mood: freezed == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as String?,poll: freezed == poll ? _self.poll : poll // ignore: cast_nullable_to_non_nullable
as EnhancedPoll?,collaborators: null == collaborators ? _self._collaborators : collaborators // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
