import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/core/errors/app_exception.dart';

class CollectionRemoteDatasource {
  final SupabaseClient _supabase;

  CollectionRemoteDatasource({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseService().client;

  Future<List<CollectionEntity>> getUserCollections() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw const AuthenticationException('Not authenticated');

    final response = await _supabase.rpc(
      'get_user_collections',
      params: {'target_user_id': userId},
    );

    if (response == null || (response as List).isEmpty) return [];

    return response
        .map((json) => _fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CollectionEntity> createCollection({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw const AuthenticationException('Not authenticated');

    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final collections = await getUserCollections();
      if (collections.length >= 3) {
        throw const ValidationException(
          'Free tier is limited to 3 collections. Upgrade to Oasis Pro for unlimited collections.',
        );
      }
    }

    final response = await _supabase
        .from('collections')
        .insert({
          'user_id': userId,
          'name': name,
          'description': description,
          'is_private': isPrivate,
        })
        .select()
        .single();

    return _fromJson(response);
  }

  Future<bool> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPrivate != null) updates['is_private'] = isPrivate;

    if (updates.isEmpty) return false;

    await _supabase.from('collections').update(updates).eq('id', collectionId);

    return true;
  }

  Future<bool> deleteCollection(String collectionId) async {
    await _supabase.from('collections').delete().eq('id', collectionId);
    return true;
  }

  Future<bool> addToCollection(String collectionId, String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw const AuthenticationException('Not authenticated');

    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      final items = await getCollectionItems(collectionId);
      if (items.length >= 50) {
        throw const ValidationException(
          'Free tier collections are limited to 50 items. Upgrade to Oasis Pro for unlimited items.',
        );
      }
    }

    await _supabase.rpc(
      'add_to_collection',
      params: {
        'target_collection_id': collectionId,
        'target_post_id': postId,
        'requesting_user_id': userId,
      },
    );

    return true;
  }

  Future<bool> removeFromCollection(String collectionId, String postId) async {
    await _supabase
        .from('collection_items')
        .delete()
        .eq('collection_id', collectionId)
        .eq('post_id', postId);

    return true;
  }

  Future<List<Post>> getCollectionItems(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw const AuthenticationException('Not authenticated');

    final response = await _supabase.rpc(
      'get_collection_items',
      params: {
        'target_collection_id': collectionId,
        'requesting_user_id': userId,
      },
    );

    if (response == null || (response as List).isEmpty) return [];

    return response.map((item) {
      final json = item as Map<String, dynamic>;
      return Post(
        id: json['post_id'] as String,
        userId: json['author_id'] as String,
        username: json['author_username'] as String,
        userAvatar: json['author_avatar_url'] as String? ?? '',
        content: json['post_content'] as String?,
        imageUrl: json['post_image_url'] as String?,
        timestamp: DateTime.parse(json['post_created_at'] as String),
        likes: json['post_likes_count'] as int? ?? 0,
        comments: json['post_comments_count'] as int? ?? 0,
      );
    }).toList();
  }

  Future<bool> isPostInCollection(String collectionId, String postId) async {
    final response = await _supabase
        .from('collection_items')
        .select('id')
        .eq('collection_id', collectionId)
        .eq('post_id', postId)
        .maybeSingle();

    return response != null;
  }

  Future<List<CollectionEntity>> getCollectionsForPost(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw const AuthenticationException('Not authenticated');

    final response = await _supabase
        .from('collection_items')
        .select('''
          collections:collection_id (
            id,
            user_id,
            name,
            description,
            is_private,
            items_count,
            created_at,
            updated_at
          )
        ''')
        .eq('post_id', postId);

    return (response as List)
        .map((item) => _fromJson(item['collections'] as Map<String, dynamic>))
        .where((collection) => collection.userId == userId)
        .toList();
  }

  CollectionEntity _fromJson(Map<String, dynamic> json) {
    return CollectionEntity(
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
}
