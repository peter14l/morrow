import 'package:oasis/core/result/result.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/collections/domain/repositories/collection_repository.dart';
import 'package:oasis/features/collections/data/datasources/collection_remote_datasource.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  final CollectionRemoteDatasource _remoteDatasource;

  CollectionRepositoryImpl({CollectionRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? CollectionRemoteDatasource();

  @override
  Future<Result<List<CollectionEntity>>> getUserCollections() async {
    try {
      final collections = await _remoteDatasource.getUserCollections();
      return Result.success(collections);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<CollectionEntity>> createCollection({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    try {
      final collection = await _remoteDatasource.createCollection(
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      return Result.success(collection);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final success = await _remoteDatasource.updateCollection(
        collectionId: collectionId,
        name: name,
        description: description,
        isPrivate: isPrivate,
      );
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> deleteCollection(String collectionId) async {
    try {
      final success = await _remoteDatasource.deleteCollection(collectionId);
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> addToCollection(
    String collectionId,
    String postId,
  ) async {
    try {
      final success = await _remoteDatasource.addToCollection(
        collectionId,
        postId,
      );
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> removeFromCollection(
    String collectionId,
    String postId,
  ) async {
    try {
      final success = await _remoteDatasource.removeFromCollection(
        collectionId,
        postId,
      );
      return Result.success(success);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<List<Post>>> getCollectionItems(String collectionId) async {
    try {
      final items = await _remoteDatasource.getCollectionItems(collectionId);
      return Result.success(items);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<bool>> isPostInCollection(
    String collectionId,
    String postId,
  ) async {
    try {
      final result = await _remoteDatasource.isPostInCollection(
        collectionId,
        postId,
      );
      return Result.success(result);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<Result<List<CollectionEntity>>> getCollectionsForPost(
    String postId,
  ) async {
    try {
      final collections = await _remoteDatasource.getCollectionsForPost(postId);
      return Result.success(collections);
    } catch (e, stackTrace) {
      return Result.failure(
        message: e.toString(),
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
}
