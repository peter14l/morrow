import 'package:equatable/equatable.dart';

class CollectionEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final bool isPrivate;
  final int itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? previewImages;

  const CollectionEntity({
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

  CollectionEntity copyWith({
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
    return CollectionEntity(
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

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    description,
    isPrivate,
    itemsCount,
    createdAt,
    updatedAt,
    previewImages,
  ];
}
