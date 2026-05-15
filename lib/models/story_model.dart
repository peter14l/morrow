class StoryModel {
  final String id;
  final String userId;
  final String username;
  final String userAvatar;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
  final String? caption;
  final int duration; // seconds to display
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool hasViewed; // has current user viewed this story

  // New Fields for Spotify & Interactivity
  final String? musicId;
  final StoryMusic? musicMetadata;
  final List<StorySticker>? interactiveMetadata;

  StoryModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.caption,
    this.duration = 5,
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.hasViewed = false,
    this.musicId,
    this.musicMetadata,
    this.interactiveMetadata,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'Unknown',
      userAvatar: json['user_avatar'] as String? ?? '',
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      duration: json['duration'] as int? ?? 5,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      viewCount: json['view_count'] as int? ?? 0,
      hasViewed: json['has_viewed'] as bool? ?? false,
      musicId: json['music_id'] as String?,
      musicMetadata: json['music_metadata'] != null
          ? StoryMusic.fromJson(json['music_metadata'] as Map<String, dynamic>)
          : null,
      interactiveMetadata: json['interactive_metadata'] != null
          ? (json['interactive_metadata'] as List<dynamic>)
                .map((s) => StorySticker.fromJson(s as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'user_avatar': userAvatar,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'duration': duration,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'view_count': viewCount,
      'has_viewed': hasViewed,
      'music_id': musicId,
      'music_metadata': musicMetadata?.toJson(),
      'interactive_metadata': interactiveMetadata
          ?.map((s) => s.toJson())
          .toList(),
    };
  }

  StoryModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    String? mediaUrl,
    String? mediaType,
    String? thumbnailUrl,
    String? caption,
    int? duration,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    bool? hasViewed,
    String? musicId,
    StoryMusic? musicMetadata,
    List<StorySticker>? interactiveMetadata,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      hasViewed: hasViewed ?? this.hasViewed,
      musicId: musicId ?? this.musicId,
      musicMetadata: musicMetadata ?? this.musicMetadata,
      interactiveMetadata: interactiveMetadata ?? this.interactiveMetadata,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  bool get hasMusic => musicId != null && musicMetadata != null;
}

class StoryGroup {
  final String userId;
  final String username;
  final String avatarUrl;
  final List<StoryModel> stories;
  final bool hasUnviewed;
  final DateTime latestStoryAt;

  StoryGroup({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
    required this.hasUnviewed,
    required this.latestStoryAt,
  });

  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final storiesList =
        (json['stories'] as List<dynamic>?)?.map((s) {
          final storyMap = s as Map<String, dynamic>;
          // Inject user info into story model
          storyMap['username'] = json['username'];
          storyMap['user_avatar'] = json['avatar_url'];
          return StoryModel.fromJson(storyMap);
        }).toList() ??
        [];

    return StoryGroup(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String? ?? '',
      stories: storiesList,
      hasUnviewed: json['has_unviewed'] as bool? ?? false,
      latestStoryAt: DateTime.parse(json['latest_story_at'] as String),
    );
  }

  int get storyCount => stories.length;
  int get unviewedCount => stories.where((s) => !s.hasViewed).length;
}

class StoryMusic {
  final String trackId;
  final String title;
  final String artist;
  final String albumArtUrl;
  final String previewUrl;

  StoryMusic({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.albumArtUrl,
    required this.previewUrl,
  });

  factory StoryMusic.fromJson(Map<String, dynamic> json) {
    return StoryMusic(
      trackId: json['track_id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      albumArtUrl: json['album_art_url'] as String,
      previewUrl: json['preview_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track_id': trackId,
      'title': title,
      'artist': artist,
      'album_art_url': albumArtUrl,
      'preview_url': previewUrl,
    };
  }
}

class StorySticker {
  final String type; // 'text', 'mention', 'hashtag', 'music', 'location'
  final Map<String, dynamic> data;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  StorySticker({
    required this.type,
    required this.data,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  factory StorySticker.fromJson(Map<String, dynamic> json) {
    return StorySticker(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num? ?? 1.0).toDouble(),
      rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }
}
