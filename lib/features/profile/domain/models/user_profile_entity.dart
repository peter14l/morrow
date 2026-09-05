class UserProfileEntity {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String? website;
  final bool isVerified;
  final bool isPrivate;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final String? bannerUrl;
  final String? bannerColor;
  final String? fcmToken;
  final String? publicKey;
  final String? encryptedPrivateKey;
  final bool focusModeEnabled;
  final Map<String, dynamic>? focusModeSchedule;
  final bool windDownEnabled;
  final String? windDownTime;
  final int xp;
  final int level;
  final bool isPro;
  final String? moodEmoji;
  final String? pulseStatus;
  final String? pulseText;
  final String? currentMood;
  final String? cozyStatus;
  final bool fortressMode;
  final DateTime createdAt;

  String get displayName =>
      (fullName != null && fullName!.isNotEmpty) ? fullName! : username;

  int get safeFollowersCount => followersCount < 0 ? 0 : followersCount;
  int get safeFollowingCount => followingCount < 0 ? 0 : followingCount;
  int get safePostsCount => postsCount < 0 ? 0 : postsCount;
  int get safeXp => xp < 0 ? 0 : xp;

  bool get hasActivePulse => pulseStatus != null && pulseStatus!.isNotEmpty;
  bool get hasActiveCozyStatus => cozyStatus != null && cozyStatus!.isNotEmpty;

  const UserProfileEntity({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.website,
    this.isVerified = false,
    this.isPrivate = false,
    this.isPro = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.bannerUrl,
    this.bannerColor,
    this.fcmToken,
    this.publicKey,
    this.encryptedPrivateKey,
    this.focusModeEnabled = false,
    this.focusModeSchedule,
    this.windDownEnabled = false,
    this.windDownTime,
    this.xp = 0,
    this.level = 1,
    this.moodEmoji,
    this.pulseStatus,
    this.pulseText,
    this.currentMood,
    this.cozyStatus,
    this.fortressMode = false,
    required this.createdAt,
  });

  factory UserProfileEntity.fromJson(Map<String, dynamic> json) {
    return UserProfileEntity(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'user',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      website: json['website'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isPrivate: json['is_private'] as bool? ?? false,
      isPro: json['is_pro'] as bool? ?? false,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      bannerUrl: json['banner_url'] as String?,
      bannerColor: json['banner_color'] as String?,
      fcmToken: json['fcm_token'] as String?,
      publicKey: json['public_key'] as String?,
      encryptedPrivateKey: json['encrypted_private_key'] as String?,
      focusModeEnabled: json['focus_mode_enabled'] as bool? ?? false,
      focusModeSchedule: json['focus_mode_schedule'] as Map<String, dynamic>?,
      windDownEnabled: json['wind_down_enabled'] as bool? ?? false,
      windDownTime: json['wind_down_time'] as String?,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      moodEmoji: json['mood_emoji'] as String?,
      pulseStatus: json['pulse_status'] as String?,
      pulseText: json['pulse_text'] as String?,
      currentMood: json['current_mood'] as String?,
      cozyStatus: json['cozy_status'] as String?,
      fortressMode: json['fortress_mode'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location': location,
      'website': website,
      'is_verified': isVerified,
      'is_private': isPrivate,
      'is_pro': isPro,
      'followers_count': followersCount,
      'following_count': followingCount,
      'posts_count': postsCount,
      'banner_url': bannerUrl,
      'banner_color': bannerColor,
      'fcm_token': fcmToken,
      'public_key': publicKey,
      'encrypted_private_key': encryptedPrivateKey,
      'focus_mode_enabled': focusModeEnabled,
      'focus_mode_schedule': focusModeSchedule,
      'wind_down_enabled': windDownEnabled,
      'wind_down_time': windDownTime,
      'xp': xp,
      'level': level,
      'mood_emoji': moodEmoji,
      'pulse_status': pulseStatus,
      'pulse_text': pulseText,
      'current_mood': currentMood,
      'cozy_status': cozyStatus,
      'fortress_mode': fortressMode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfileEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? location,
    String? website,
    bool? isVerified,
    bool? isPrivate,
    bool? isPro,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    String? bannerUrl,
    String? bannerColor,
    String? fcmToken,
    String? publicKey,
    String? encryptedPrivateKey,
    bool? focusModeEnabled,
    Map<String, dynamic>? focusModeSchedule,
    bool? windDownEnabled,
    String? windDownTime,
    int? xp,
    int? level,
    String? moodEmoji,
    String? pulseStatus,
    String? pulseText,
    String? currentMood,
    String? cozyStatus,
    bool? fortressMode,
    DateTime? createdAt,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      website: website ?? this.website,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      isPro: isPro ?? this.isPro,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bannerColor: bannerColor ?? this.bannerColor,
      fcmToken: fcmToken ?? this.fcmToken,
      publicKey: publicKey ?? this.publicKey,
      encryptedPrivateKey: encryptedPrivateKey ?? this.encryptedPrivateKey,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      focusModeSchedule: focusModeSchedule ?? this.focusModeSchedule,
      windDownEnabled: windDownEnabled ?? this.windDownEnabled,
      windDownTime: windDownTime ?? this.windDownTime,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      pulseStatus: pulseStatus ?? this.pulseStatus,
      pulseText: pulseText ?? this.pulseText,
      currentMood: currentMood ?? this.currentMood,
      cozyStatus: cozyStatus ?? this.cozyStatus,
      fortressMode: fortressMode ?? this.fortressMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
