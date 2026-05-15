import 'package:flutter/foundation.dart';
import 'package:oasis/models/collection.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/core/network/supabase_client.dart';

class CollectionsService {
  final _supabase = SupabaseService().client;

  /// Get all collections for current user
  Future<List<Collection>> getUserCollections() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_user_collections',
        params: {'target_user_id': userId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => Collection.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching collections: $e');
      return [];
    }
  }

  /// Create a new collection
  Future<Collection?> createCollection({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final isPro = SubscriptionService().isPro;
      if (!isPro) {
        final collections = await getUserCollections();
        if (collections.length >= 3) {
          throw Exception(
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

      return Collection.fromJson(response);
    } catch (e) {
      debugPrint('Error creating collection: $e');
      return null;
    }
  }

  /// Update a collection
  Future<bool> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    bool? isPrivate,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (isPrivate != null) updates['is_private'] = isPrivate;

      if (updates.isEmpty) return false;

      await _supabase
          .from('collections')
          .update(updates)
          .eq('id', collectionId);

      return true;
    } catch (e) {
      debugPrint('Error updating collection: $e');
      return false;
    }
  }

  /// Delete a collection
  Future<bool> deleteCollection(String collectionId) async {
    try {
      await _supabase.from('collections').delete().eq('id', collectionId);
      return true;
    } catch (e) {
      debugPrint('Error deleting collection: $e');
      return false;
    }
  }

  /// Add post to collection (also bookmarks it)
  Future<bool> addToCollection(String collectionId, String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final isPro = SubscriptionService().isPro;
      if (!isPro) {
        final items = await getCollectionItems(collectionId);
        if (items.length >= 50) {
          throw Exception(
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
    } catch (e) {
      debugPrint('Error adding to collection: $e');
      return false;
    }
  }

  /// Remove post from collection
  Future<bool> removeFromCollection(String collectionId, String postId) async {
    try {
      await _supabase
          .from('collection_items')
          .delete()
          .eq('collection_id', collectionId)
          .eq('post_id', postId);

      return true;
    } catch (e) {
      debugPrint('Error removing from collection: $e');
      return false;
    }
  }

  /// Get items in a collection
  Future<List<Post>> getCollectionItems(String collectionId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_collection_items',
        params: {
          'target_collection_id': collectionId,
          'requesting_user_id': userId,
        },
      );

      if (response == null || response.isEmpty) return [];

      return (response as List).map((item) {
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
    } catch (e) {
      debugPrint('Error fetching collection items: $e');
      return [];
    }
  }

  /// Check if post is in a specific collection
  Future<bool> isPostInCollection(String collectionId, String postId) async {
    try {
      final response = await _supabase
          .from('collection_items')
          .select('id')
          .eq('collection_id', collectionId)
          .eq('post_id', postId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking collection item: $e');
      return false;
    }
  }

  /// Get collections containing a specific post
  Future<List<Collection>> getCollectionsForPost(String postId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

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
          .map(
            (item) => Collection.fromJson(
              item['collections'] as Map<String, dynamic>,
            ),
          )
          .where((collection) => collection.userId == userId)
          .toList();
    } catch (e) {
      debugPrint('Error fetching collections for post: $e');
      return [];
    }
  }
}
