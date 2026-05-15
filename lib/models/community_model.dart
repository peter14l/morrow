class Community {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String theme;
  final String? rules;
  final String? privacyPolicy;
  final List<String> moderators;
  final int memberCount;
  final DateTime createdAt;
  final bool isPrivate;

  Community({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.theme,
    this.rules,
    this.privacyPolicy,
    this.moderators = const [],
    this.memberCount = 0,
    required this.createdAt,
    this.isPrivate = false,
  });

  factory Community.fromMap(String id, Map<String, dynamic> map) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      theme: map['theme'] ?? 'General',
      rules: map['rules'],
      privacyPolicy: map['privacyPolicy'],
      moderators: List<String>.from(map['moderators'] ?? []),
      memberCount: map['memberCount'] ?? 0,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      isPrivate: map['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'theme': theme,
      'rules': rules,
      'privacyPolicy': privacyPolicy,
      'moderators': moderators,
      'memberCount': memberCount,
      'created_at': createdAt.toIso8601String(),
      'isPrivate': isPrivate,
    };
  }

  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? theme,
    String? rules,
    String? privacyPolicy,
    List<String>? moderators,
    int? memberCount,
    DateTime? createdAt,
    bool? isPrivate,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      theme: theme ?? this.theme,
      rules: rules ?? this.rules,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      moderators: moderators ?? this.moderators,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
