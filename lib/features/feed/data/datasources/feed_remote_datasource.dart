import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote datasource for feed operations.
///
/// Handles raw Supabase RPC calls and table queries for feed retrieval.
/// Does NOT handle business logic — that belongs in the repository.
class FeedRemoteDatasource {
  final SupabaseService _supabaseService = SupabaseService();
  SupabaseClient get _supabase => _supabaseService.client;

  /// Fetch "For You" feed posts via RPC function.
  Future<List<Map<String, dynamic>>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    // Note: The RPC returns a fixed table. To get collaborators, we might need a separate query
    // or update the RPC. For now, we'll fetch the posts then hydrate them with collaborators.
    final response = await _supabase.rpc(
      SupabaseConfig.getFeedPostsFn,
      params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_cursor_timestamp': cursor,
      },
    );

    if (response == null) return [];
    final posts = (response as List<dynamic>).map((json) {
      final map = Map<String, dynamic>.from(json as Map);
      if (map['comments_count'] == null && map['comments'] != null) {
        map['comments_count'] = map['comments'];
      }
      return map;
    }).toList();

    await _hydrateCollaborators(posts);
    return _hydratePolls(posts);
  }

  /// Fetch "Following" feed posts via RPC function.
  Future<List<Map<String, dynamic>>> getFollowingFeedPosts({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    final response = await _supabase.rpc(
      SupabaseConfig.getFollowingFeedPostsFn,
      params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_cursor_timestamp': cursor,
      },
    );

    if (response == null) return [];
    final posts = (response as List<dynamic>).map((json) {
      final map = Map<String, dynamic>.from(json as Map);
      if (map['comments_count'] == null && map['comments'] != null) {
        map['comments_count'] = map['comments'];
      }
      return map;
    }).toList();

    await _hydrateCollaborators(posts);
    return _hydratePolls(posts);
  }

  /// Fetch unified feed posts (Following + Public).
  Future<List<Map<String, dynamic>>> getUnifiedFeed({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    final response = await _supabase.rpc(
      SupabaseConfig.getUnifiedFeedFn,
      params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_cursor_timestamp': cursor,
      },
    );

    if (response == null) return [];
    final posts = (response as List<dynamic>).map((json) {
      final map = Map<String, dynamic>.from(json as Map);
      if (map['comments_count'] == null && map['comments'] != null) {
        map['comments_count'] = map['comments'];
      }
      return map;
    }).toList();

    await _hydrateCollaborators(posts);
    return _hydratePolls(posts);
  }

  /// Hydrate posts with collaborator info.
  Future<List<Map<String, dynamic>>> _hydrateCollaborators(
    List<Map<String, dynamic>> posts,
  ) async {
    if (posts.isEmpty) return posts;

    final postIds = posts.map((p) => p['id'] as String).toList();

    try {
      final collabResponse = await _supabase
          .from('post_collaborators')
          .select('''
            post_id,
            user_id,
            status,
            profiles:user_id (
              username,
              avatar_url,
              is_verified
            )
          ''')
          .inFilter('post_id', postIds);

      if (collabResponse.isNotEmpty) {
        for (final post in posts) {
          final postCollabs = (collabResponse as List)
              .where((c) => c['post_id'] == post['id'])
              .toList();
          if (postCollabs.isNotEmpty) {
            post['collaborators'] = postCollabs;
          }
        }
      }
    } catch (e) {
      debugPrint('[FeedRemoteDatasource] Collaborator hydration error: $e');
    }

    return posts;
  }

  /// Hydrate posts with their corresponding polls and options.
  Future<List<Map<String, dynamic>>> _hydratePolls(
    List<Map<String, dynamic>> posts,
  ) async {
    if (posts.isEmpty) return posts;

    final postIds = posts.map((p) => p['id'] as String).toList();

    try {
      final pollsResponse = await _supabase
          .from(SupabaseConfig.pollsTable)
          .select('*, poll_options(*)')
          .inFilter('post_id', postIds);

      if (pollsResponse.isNotEmpty) {
        final pollsList = pollsResponse;
        for (final post in posts) {
          final postPolls = pollsList
              .where((poll) => poll['post_id'] == post['id'])
              .toList();
          if (postPolls.isNotEmpty) {
            post['polls'] = postPolls;
          }
        }
      }
    } catch (e) {
      debugPrint('[FeedRemoteDatasource] Poll hydration error: $e');
    }

    return posts;
  }

  /// Stream posts table for real-time updates.
  Stream<List<Map<String, dynamic>>> watchFeedPosts({
    required String userId,
    int limit = 20,
  }) {
    return _supabase
        .from(SupabaseConfig.postsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .handleError((error) {
          debugPrint('[FeedRemoteDatasource] Realtime stream error: $error');
          return <Map<String, dynamic>>[];
        });
  }
}
