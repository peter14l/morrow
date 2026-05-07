// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppUser {

 String get id; String get username; String get email; String? get displayName; String? get photoUrl; String? get bio; String? get location; String? get website; DateTime? get joinedDate; int get followersCount; int get followingCount; int get postsCount; bool get isVerified; bool get isPrivate; String? get bannerUrl; String? get bannerColor; bool get isPro; Map<String, dynamic>? get userMetadata;
/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppUserCopyWith<AppUser> get copyWith => _$AppUserCopyWithImpl<AppUser>(this as AppUser, _$identity);

  /// Serializes this AppUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.location, location) || other.location == location)&&(identical(other.website, website) || other.website == website)&&(identical(other.joinedDate, joinedDate) || other.joinedDate == joinedDate)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postsCount, postsCount) || other.postsCount == postsCount)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.bannerUrl, bannerUrl) || other.bannerUrl == bannerUrl)&&(identical(other.bannerColor, bannerColor) || other.bannerColor == bannerColor)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&const DeepCollectionEquality().equals(other.userMetadata, userMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,email,displayName,photoUrl,bio,location,website,joinedDate,followersCount,followingCount,postsCount,isVerified,isPrivate,bannerUrl,bannerColor,isPro,const DeepCollectionEquality().hash(userMetadata));

@override
String toString() {
  return 'AppUser(id: $id, username: $username, email: $email, displayName: $displayName, photoUrl: $photoUrl, bio: $bio, location: $location, website: $website, joinedDate: $joinedDate, followersCount: $followersCount, followingCount: $followingCount, postsCount: $postsCount, isVerified: $isVerified, isPrivate: $isPrivate, bannerUrl: $bannerUrl, bannerColor: $bannerColor, isPro: $isPro, userMetadata: $userMetadata)';
}


}

/// @nodoc
abstract mixin class $AppUserCopyWith<$Res>  {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) _then) = _$AppUserCopyWithImpl;
@useResult
$Res call({
 String id, String username, String email, String? displayName, String? photoUrl, String? bio, String? location, String? website, DateTime? joinedDate, int followersCount, int followingCount, int postsCount, bool isVerified, bool isPrivate, String? bannerUrl, String? bannerColor, bool isPro, Map<String, dynamic>? userMetadata
});




}
/// @nodoc
class _$AppUserCopyWithImpl<$Res>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._self, this._then);

  final AppUser _self;
  final $Res Function(AppUser) _then;

/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? username = null,Object? email = null,Object? displayName = freezed,Object? photoUrl = freezed,Object? bio = freezed,Object? location = freezed,Object? website = freezed,Object? joinedDate = freezed,Object? followersCount = null,Object? followingCount = null,Object? postsCount = null,Object? isVerified = null,Object? isPrivate = null,Object? bannerUrl = freezed,Object? bannerColor = freezed,Object? isPro = null,Object? userMetadata = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,joinedDate: freezed == joinedDate ? _self.joinedDate : joinedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postsCount: null == postsCount ? _self.postsCount : postsCount // ignore: cast_nullable_to_non_nullable
as int,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,bannerUrl: freezed == bannerUrl ? _self.bannerUrl : bannerUrl // ignore: cast_nullable_to_non_nullable
as String?,bannerColor: freezed == bannerColor ? _self.bannerColor : bannerColor // ignore: cast_nullable_to_non_nullable
as String?,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,userMetadata: freezed == userMetadata ? _self.userMetadata : userMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppUser].
extension AppUserPatterns on AppUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppUser value)  $default,){
final _that = this;
switch (_that) {
case _AppUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppUser value)?  $default,){
final _that = this;
switch (_that) {
case _AppUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String username,  String email,  String? displayName,  String? photoUrl,  String? bio,  String? location,  String? website,  DateTime? joinedDate,  int followersCount,  int followingCount,  int postsCount,  bool isVerified,  bool isPrivate,  String? bannerUrl,  String? bannerColor,  bool isPro,  Map<String, dynamic>? userMetadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppUser() when $default != null:
return $default(_that.id,_that.username,_that.email,_that.displayName,_that.photoUrl,_that.bio,_that.location,_that.website,_that.joinedDate,_that.followersCount,_that.followingCount,_that.postsCount,_that.isVerified,_that.isPrivate,_that.bannerUrl,_that.bannerColor,_that.isPro,_that.userMetadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String username,  String email,  String? displayName,  String? photoUrl,  String? bio,  String? location,  String? website,  DateTime? joinedDate,  int followersCount,  int followingCount,  int postsCount,  bool isVerified,  bool isPrivate,  String? bannerUrl,  String? bannerColor,  bool isPro,  Map<String, dynamic>? userMetadata)  $default,) {final _that = this;
switch (_that) {
case _AppUser():
return $default(_that.id,_that.username,_that.email,_that.displayName,_that.photoUrl,_that.bio,_that.location,_that.website,_that.joinedDate,_that.followersCount,_that.followingCount,_that.postsCount,_that.isVerified,_that.isPrivate,_that.bannerUrl,_that.bannerColor,_that.isPro,_that.userMetadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String username,  String email,  String? displayName,  String? photoUrl,  String? bio,  String? location,  String? website,  DateTime? joinedDate,  int followersCount,  int followingCount,  int postsCount,  bool isVerified,  bool isPrivate,  String? bannerUrl,  String? bannerColor,  bool isPro,  Map<String, dynamic>? userMetadata)?  $default,) {final _that = this;
switch (_that) {
case _AppUser() when $default != null:
return $default(_that.id,_that.username,_that.email,_that.displayName,_that.photoUrl,_that.bio,_that.location,_that.website,_that.joinedDate,_that.followersCount,_that.followingCount,_that.postsCount,_that.isVerified,_that.isPrivate,_that.bannerUrl,_that.bannerColor,_that.isPro,_that.userMetadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppUser extends AppUser {
  const _AppUser({this.id = '', this.username = 'user', this.email = '', this.displayName, this.photoUrl, this.bio, this.location, this.website, this.joinedDate, this.followersCount = 0, this.followingCount = 0, this.postsCount = 0, this.isVerified = false, this.isPrivate = false, this.bannerUrl, this.bannerColor, this.isPro = false, final  Map<String, dynamic>? userMetadata}): _userMetadata = userMetadata,super._();
  factory _AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String username;
@override@JsonKey() final  String email;
@override final  String? displayName;
@override final  String? photoUrl;
@override final  String? bio;
@override final  String? location;
@override final  String? website;
@override final  DateTime? joinedDate;
@override@JsonKey() final  int followersCount;
@override@JsonKey() final  int followingCount;
@override@JsonKey() final  int postsCount;
@override@JsonKey() final  bool isVerified;
@override@JsonKey() final  bool isPrivate;
@override final  String? bannerUrl;
@override final  String? bannerColor;
@override@JsonKey() final  bool isPro;
 final  Map<String, dynamic>? _userMetadata;
@override Map<String, dynamic>? get userMetadata {
  final value = _userMetadata;
  if (value == null) return null;
  if (_userMetadata is EqualUnmodifiableMapView) return _userMetadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppUserCopyWith<_AppUser> get copyWith => __$AppUserCopyWithImpl<_AppUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppUser&&(identical(other.id, id) || other.id == id)&&(identical(other.username, username) || other.username == username)&&(identical(other.email, email) || other.email == email)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.location, location) || other.location == location)&&(identical(other.website, website) || other.website == website)&&(identical(other.joinedDate, joinedDate) || other.joinedDate == joinedDate)&&(identical(other.followersCount, followersCount) || other.followersCount == followersCount)&&(identical(other.followingCount, followingCount) || other.followingCount == followingCount)&&(identical(other.postsCount, postsCount) || other.postsCount == postsCount)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isPrivate, isPrivate) || other.isPrivate == isPrivate)&&(identical(other.bannerUrl, bannerUrl) || other.bannerUrl == bannerUrl)&&(identical(other.bannerColor, bannerColor) || other.bannerColor == bannerColor)&&(identical(other.isPro, isPro) || other.isPro == isPro)&&const DeepCollectionEquality().equals(other._userMetadata, _userMetadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,username,email,displayName,photoUrl,bio,location,website,joinedDate,followersCount,followingCount,postsCount,isVerified,isPrivate,bannerUrl,bannerColor,isPro,const DeepCollectionEquality().hash(_userMetadata));

@override
String toString() {
  return 'AppUser(id: $id, username: $username, email: $email, displayName: $displayName, photoUrl: $photoUrl, bio: $bio, location: $location, website: $website, joinedDate: $joinedDate, followersCount: $followersCount, followingCount: $followingCount, postsCount: $postsCount, isVerified: $isVerified, isPrivate: $isPrivate, bannerUrl: $bannerUrl, bannerColor: $bannerColor, isPro: $isPro, userMetadata: $userMetadata)';
}


}

/// @nodoc
abstract mixin class _$AppUserCopyWith<$Res> implements $AppUserCopyWith<$Res> {
  factory _$AppUserCopyWith(_AppUser value, $Res Function(_AppUser) _then) = __$AppUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String username, String email, String? displayName, String? photoUrl, String? bio, String? location, String? website, DateTime? joinedDate, int followersCount, int followingCount, int postsCount, bool isVerified, bool isPrivate, String? bannerUrl, String? bannerColor, bool isPro, Map<String, dynamic>? userMetadata
});




}
/// @nodoc
class __$AppUserCopyWithImpl<$Res>
    implements _$AppUserCopyWith<$Res> {
  __$AppUserCopyWithImpl(this._self, this._then);

  final _AppUser _self;
  final $Res Function(_AppUser) _then;

/// Create a copy of AppUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? username = null,Object? email = null,Object? displayName = freezed,Object? photoUrl = freezed,Object? bio = freezed,Object? location = freezed,Object? website = freezed,Object? joinedDate = freezed,Object? followersCount = null,Object? followingCount = null,Object? postsCount = null,Object? isVerified = null,Object? isPrivate = null,Object? bannerUrl = freezed,Object? bannerColor = freezed,Object? isPro = null,Object? userMetadata = freezed,}) {
  return _then(_AppUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,website: freezed == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String?,joinedDate: freezed == joinedDate ? _self.joinedDate : joinedDate // ignore: cast_nullable_to_non_nullable
as DateTime?,followersCount: null == followersCount ? _self.followersCount : followersCount // ignore: cast_nullable_to_non_nullable
as int,followingCount: null == followingCount ? _self.followingCount : followingCount // ignore: cast_nullable_to_non_nullable
as int,postsCount: null == postsCount ? _self.postsCount : postsCount // ignore: cast_nullable_to_non_nullable
as int,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isPrivate: null == isPrivate ? _self.isPrivate : isPrivate // ignore: cast_nullable_to_non_nullable
as bool,bannerUrl: freezed == bannerUrl ? _self.bannerUrl : bannerUrl // ignore: cast_nullable_to_non_nullable
as String?,bannerColor: freezed == bannerColor ? _self.bannerColor : bannerColor // ignore: cast_nullable_to_non_nullable
as String?,isPro: null == isPro ? _self.isPro : isPro // ignore: cast_nullable_to_non_nullable
as bool,userMetadata: freezed == userMetadata ? _self._userMetadata : userMetadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
