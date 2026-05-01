import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String username,
    required String email,
    String? displayName,
    String? photoUrl,
    String? bio,
    String? location,
    String? website,
    DateTime? joinedDate,
    @Default(0) int followersCount,
    @Default(0) int followingCount,
    @Default(0) int postsCount,
    @Default(false) bool isVerified,
    @Default(false) bool isPrivate,
    String? bannerUrl,
    String? bannerColor,
    @Default(false) bool isPro,
    Map<String, dynamic>? userMetadata,
  }) = _AppUser;

  const AppUser._();

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  int get safeFollowersCount => followersCount < 0 ? 0 : followersCount;
  int get safeFollowingCount => followingCount < 0 ? 0 : followingCount;
  int get safePostsCount => postsCount < 0 ? 0 : postsCount;

  String get displayNameOrUsername => displayName ?? username;

  static const empty = AppUser(id: '', username: '', email: '');
  bool get isEmpty => id.isEmpty;
  bool get isNotEmpty => id.isNotEmpty;
}
