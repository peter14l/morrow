/// Ripple entity representing a public video post in the Ripples feature.
/// This is the core domain model for ripples - a short video sharing feature
/// similar to Instagram Reels or TikTok.
class RippleEntity {
  final String id;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final bool isPrivate;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final bool isLiked;
  final bool isSaved;
  final bool isAd;
  final DateTime createdAt;

  const RippleEntity({
    required this.id,
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    this.isPrivate = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.savesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isAd = false,
    required this.createdAt,
  });

  factory RippleEntity.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return RippleEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: profile?['username'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isSaved: json['is_saved'] as bool? ?? false,
      isAd: json['is_ad'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'is_private': isPrivate,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'saves_count': savesCount,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'is_ad': isAd,
      'created_at': createdAt.toIso8601String(),
      'profiles': {
        'username': username,
        'avatar_url': avatarUrl,
      },
    };
  }

  RippleEntity copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? caption,
    bool? isPrivate,
    int? likesCount,
    int? commentsCount,
    int? savesCount,
    bool? isLiked,
    bool? isSaved,
    bool? isAd,
    DateTime? createdAt,
  }) {
    return RippleEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      isPrivate: isPrivate ?? this.isPrivate,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      savesCount: savesCount ?? this.savesCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isAd: isAd ?? this.isAd,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Ripple comment entity representing a comment on a ripple.
class RippleCommentEntity {
  final String id;
  final String rippleId;
  final String userId;
  final String? username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const RippleCommentEntity({
    required this.id,
    required this.rippleId,
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory RippleCommentEntity.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'];
    return RippleCommentEntity(
      id: json['id'] as String,
      rippleId: json['ripple_id'] as String,
      userId: json['user_id'] as String,
      username: profile?['username'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ripple_id': rippleId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'profiles': {
        'username': username,
        'avatar_url': avatarUrl,
      },
    };
  }
}

/// Layout type for ripples display.
enum RipplesLayoutType { kineticCardStack, choiceMosaic }
