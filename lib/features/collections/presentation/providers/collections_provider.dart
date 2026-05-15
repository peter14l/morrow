import 'package:flutter/foundation.dart';
import 'package:oasis/features/collections/presentation/providers/collections_state.dart';
import 'package:oasis/features/collections/domain/usecases/get_collections.dart';
import 'package:oasis/features/collections/domain/usecases/create_collection.dart';
import 'package:oasis/features/collections/domain/usecases/update_collection.dart';
import 'package:oasis/features/collections/domain/usecases/delete_collection.dart';
import 'package:oasis/features/collections/domain/usecases/add_to_collection.dart';
import 'package:oasis/features/collections/domain/usecases/remove_from_collection.dart';
import 'package:oasis/features/collections/domain/usecases/get_collection_detail.dart';
import 'package:oasis/features/collections/domain/usecases/check_post_in_collection.dart';
import 'package:oasis/features/collections/domain/usecases/get_collections_for_post.dart';

class CollectionsProvider extends ChangeNotifier {
  final GetCollectionsUseCase _getCollectionsUseCase;
  final CreateCollectionUseCase _createCollectionUseCase;
  final UpdateCollectionUseCase _updateCollectionUseCase;
  final DeleteCollectionUseCase _deleteCollectionUseCase;
  final AddToCollectionUseCase _addToCollectionUseCase;
  final RemoveFromCollectionUseCase _removeFromCollectionUseCase;
  final GetCollectionDetailUseCase _getCollectionDetailUseCase;
  final CheckPostInCollectionUseCase _checkPostInCollectionUseCase;
  final GetCollectionsForPostUseCase _getCollectionsForPostUseCase;

  CollectionsState _state = const CollectionsState();

  CollectionsState get state => _state;

  CollectionsProvider({
    required GetCollectionsUseCase getCollectionsUseCase,
    required CreateCollectionUseCase createCollectionUseCase,
    required UpdateCollectionUseCase updateCollectionUseCase,
    required DeleteCollectionUseCase deleteCollectionUseCase,
    required AddToCollectionUseCase addToCollectionUseCase,
    required RemoveFromCollectionUseCase removeFromCollectionUseCase,
    required GetCollectionDetailUseCase getCollectionDetailUseCase,
    required CheckPostInCollectionUseCase checkPostInCollectionUseCase,
    required GetCollectionsForPostUseCase getCollectionsForPostUseCase,
  }) : _getCollectionsUseCase = getCollectionsUseCase,
       _createCollectionUseCase = createCollectionUseCase,
       _updateCollectionUseCase = updateCollectionUseCase,
       _deleteCollectionUseCase = deleteCollectionUseCase,
       _addToCollectionUseCase = addToCollectionUseCase,
       _removeFromCollectionUseCase = removeFromCollectionUseCase,
       _getCollectionDetailUseCase = getCollectionDetailUseCase,
       _checkPostInCollectionUseCase = checkPostInCollectionUseCase,
       _getCollectionsForPostUseCase = getCollectionsForPostUseCase {
    loadCollections();
  }

  void _setState(CollectionsState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> loadCollections() async {
    _setState(_state.copyWith(status: CollectionsStatus.loading));

    final result = await _getCollectionsUseCase();

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
    final result = await _createCollectionUseCase(
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
    final result = await _updateCollectionUseCase(
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
    final result = await _deleteCollectionUseCase(collectionId);
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
    final result = await _addToCollectionUseCase(collectionId, postId);
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
    final result = await _removeFromCollectionUseCase(collectionId, postId);
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

    final result = await _getCollectionDetailUseCase(collectionId);

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

  // To silence unused variable warnings, we can just consume them or ignore.
  CheckPostInCollectionUseCase get checkPostInCollectionUseCase =>
      _checkPostInCollectionUseCase;
  GetCollectionsForPostUseCase get getCollectionsForPostUseCase =>
      _getCollectionsForPostUseCase;
}
