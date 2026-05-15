class Collection {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPrivate;
  final int itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? previewImages; // URLs of first 4 images

  Collection({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isPrivate = true,
    this.itemsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.previewImages,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPrivate: json['is_private'] as bool? ?? true,
      itemsCount: json['items_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      previewImages: (json['preview_images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'is_private': isPrivate,
      'items_count': itemsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'preview_images': previewImages,
    };
  }

  Collection copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    bool? isPrivate,
    int? itemsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? previewImages,
  }) {
    return Collection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      itemsCount: itemsCount ?? this.itemsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      previewImages: previewImages ?? this.previewImages,
    );
  }

  bool get hasPreview => previewImages != null && previewImages!.isNotEmpty;
}
