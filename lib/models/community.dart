class Community {
  final String id;
  final String name;
  final String description;
  final String? rules;
  final String? imageUrl;
  final String creatorId;
  final bool isPrivate;
  final int membersCount;
  final int postsCount;
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.rules,
    this.imageUrl,
    required this.creatorId,
    this.isPrivate = false,
    this.membersCount = 0,
    this.postsCount = 0,
    required this.createdAt,
  });

  factory Community.fromJson(Map<String, dynamic> json) {
    return Community(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rules: json['rules'] as String?,
      imageUrl: json['image_url'] as String?,
      creatorId: json['creator_id'] as String,
      isPrivate: json['is_private'] as bool? ?? false,
      membersCount: json['members_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'rules': rules,
      'image_url': imageUrl,
      'creator_id': creatorId,
      'is_private': isPrivate,
      'members_count': membersCount,
      'posts_count': postsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? rules,
    String? imageUrl,
    String? creatorId,
    bool? isPrivate,
    int? membersCount,
    int? postsCount,
    DateTime? createdAt,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rules: rules ?? this.rules,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorId: creatorId ?? this.creatorId,
      isPrivate: isPrivate ?? this.isPrivate,
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
