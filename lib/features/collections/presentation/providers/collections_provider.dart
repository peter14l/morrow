import 'package:flutter/foundation.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/collections/domain/repositories/collection_repository.dart';
import 'package:oasis/features/collections/presentation/providers/collections_state.dart';

class CollectionsProvider extends ChangeNotifier {
  final CollectionRepository _repository;

  CollectionsState _state = const CollectionsState();

  CollectionsState get state => _state;

  CollectionsProvider({
    required CollectionRepository repository,
  }) : _repository = repository {
    loadCollections();
  }

  void _setState(CollectionsState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> loadCollections() async {
    _setState(_state.copyWith(status: CollectionsStatus.loading));

    final result = await _repository.getUserCollections();

    result.fold(
      onSuccess: (collections) {
        _setState(
          _state.copyWith(
            status: CollectionsStatus.success,
            collections: collections,
          ),
        );
      },
      onFailure: (exception) {
        _setState(
          _state.copyWith(
            status: CollectionsStatus.failure,
            errorMessage: exception.toString(),
          ),
        );
      },
    );
  }

  Future<bool> createCollection({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final result = await _repository.createCollection(
      name: name,
      description: description,
      isPrivate: isPrivate,
    );

    bool isSuccess = false;
    result.fold(
      onSuccess: (newCollection) {
        // Optimistically add to list
        _setState(
          _state.copyWith(collections: [..._state.collections, newCollection]),
        );
        isSuccess = true;
      },
      onFailure: (e) {
        debugPrint('Failed to create collection: $e');
        isSuccess = false;
      },
    );
    return isSuccess;
  }

  Future<bool> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    final result = await _repository.updateCollection(
      collectionId: collectionId,
      name: name,
      description: description,
      isPrivate: isPrivate,
    );

    bool isSuccess = false;
    result.fold(
      onSuccess: (success) {
        if (success) {
          loadCollections(); // Reload to get updated data
          isSuccess = true;
        }
      },
      onFailure: (e) => isSuccess = false,
    );
    return isSuccess;
  }

  Future<bool> deleteCollection(String collectionId) async {
    final result = await _repository.deleteCollection(collectionId);
    bool isSuccess = false;
    result.fold(
      onSuccess: (success) {
        if (success) {
          _setState(
            _state.copyWith(
              collections: _state.collections
                  .where((c) => c.id != collectionId)
                  .toList(),
            ),
          );
          isSuccess = true;
        }
      },
      onFailure: (e) => isSuccess = false,
    );
    return isSuccess;
  }

  Future<bool> addToCollection(String collectionId, String postId) async {
    final result = await _repository.addToCollection(collectionId, postId);
    bool isSuccess = false;
    result.fold(
      onSuccess: (success) {
        if (success) {
          loadCollections();
          isSuccess = true;
        }
      },
      onFailure: (e) => isSuccess = false,
    );
    return isSuccess;
  }

  Future<bool> removeFromCollection(String collectionId, String postId) async {
    final result = await _repository.removeFromCollection(collectionId, postId);
    bool isSuccess = false;
    result.fold(
      onSuccess: (success) {
        if (success) {
          // Remove from detail list if present
          if (_state.collectionItems.any((item) => item.id == postId)) {
            _setState(
              _state.copyWith(
                collectionItems: _state.collectionItems
                    .where((item) => item.id != postId)
                    .toList(),
              ),
            );
          }
          loadCollections(); // Update counts
          isSuccess = true;
        }
      },
      onFailure: (e) => isSuccess = false,
    );
    return isSuccess;
  }

  Future<void> loadCollectionDetail(String collectionId) async {
    _setState(_state.copyWith(detailStatus: CollectionsStatus.loading));

    final result = await _repository.getCollectionItems(collectionId);

    result.fold(
      onSuccess: (items) {
        _setState(
          _state.copyWith(
            detailStatus: CollectionsStatus.success,
            collectionItems: items,
          ),
        );
      },
      onFailure: (e) {
        _setState(
          _state.copyWith(
            detailStatus: CollectionsStatus.failure,
            errorMessage: e.toString(),
          ),
        );
      },
    );
  }

  Future<bool> isPostInCollection(String collectionId, String postId) async {
    final result = await _repository.isPostInCollection(collectionId, postId);
    return result.fold(
      onSuccess: (inCollection) => inCollection,
      onFailure: (_) => false,
    );
  }

  Future<List<CollectionEntity>> getCollectionsForPost(String postId) async {
    final result = await _repository.getCollectionsForPost(postId);
    return result.fold(
      onSuccess: (collections) => collections,
      onFailure: (_) => [],
    );
  }
}
