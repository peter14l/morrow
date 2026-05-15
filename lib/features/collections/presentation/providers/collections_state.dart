import 'package:equatable/equatable.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

enum CollectionsStatus { initial, loading, success, failure }

class CollectionsState extends Equatable {
  final CollectionsStatus status;
  final List<CollectionEntity> collections;
  final String? errorMessage;

  // Detail view state
  final CollectionsStatus detailStatus;
  final List<Post> collectionItems;

  const CollectionsState({
    this.status = CollectionsStatus.initial,
    this.collections = const [],
    this.errorMessage,
    this.detailStatus = CollectionsStatus.initial,
    this.collectionItems = const [],
  });

  CollectionsState copyWith({
    CollectionsStatus? status,
    List<CollectionEntity>? collections,
    String? errorMessage,
    CollectionsStatus? detailStatus,
    List<Post>? collectionItems,
  }) {
    return CollectionsState(
      status: status ?? this.status,
      collections: collections ?? this.collections,
      errorMessage: errorMessage ?? this.errorMessage,
      detailStatus: detailStatus ?? this.detailStatus,
      collectionItems: collectionItems ?? this.collectionItems,
    );
  }

  @override
  List<Object?> get props => [
    status,
    collections,
    errorMessage,
    detailStatus,
    collectionItems,
  ];
}
