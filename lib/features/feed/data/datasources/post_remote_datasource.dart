import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Remote datasource for post operations.
///
/// Handles raw Supabase CRUD for posts, likes, bookmarks.
class PostRemoteDatasource {
  final SupabaseClient _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  /// Create a post in Supabase with media uploads.
  Future<Map<String, dynamic>> createPost({
    required String userId,
    required String? content,
    List<File>? mediaFiles, // Changed from List<String>?
    List<String>? mediaTypes,
    String? communityId,
    String? mood,
    bool isSpoiler = false,
  }) async {
    final postId = _uuid.v4();
    final List<String> uploadedUrls = [];

    // Temporary: Upload to Supabase instead of Backblaze
    if (mediaFiles != null && mediaFiles.isNotEmpty) {
      for (var i = 0; i < mediaFiles.length; i++) {
        final file = mediaFiles[i];
        final extension = file.path.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
        final path = '$userId/$fileName';

        await _supabase.storage
            .from(SupabaseConfig.postImagesBucket)
            .upload(path, file);

        final url = _supabase.storage
            .from(SupabaseConfig.postImagesBucket)
            .getPublicUrl(path);
        uploadedUrls.add(url);
      }
    }

    final postData = {
      'id': postId,
      'user_id': userId,
      'community_id': communityId,
      'content': content,
      'image_url': uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
      'media_urls': uploadedUrls,
      'media_types': mediaTypes ?? [],
      'mood': mood,
      'is_spoiler': isSpoiler,
      'storage_provider': 'supabase', // Mark as supabase for now
    };

    await _supabase.from(SupabaseConfig.postsTable).insert(postData);

    final response = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            full_name,
            avatar_url,
            is_verified
          ),
          communities:community_id (name),
          polls:polls (
            *,
            options:poll_options (*)
          )
        ''')
        .eq('id', postId)
        .single();

    final postMap = Map<String, dynamic>.from(response);
    _enrichWithProfile(postMap);
    _enrichWithCommunity(postMap);

    return postMap;
  }

  /// Get a single post by ID.
  Future<Map<String, dynamic>> getPost(String postId, String userId) async {
    final response = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            full_name,
            avatar_url,
            is_verified
          ),
          collaborators:post_collaborators (
            user_id,
            status,
            profiles:user_id (
              username,
              avatar_url,
              is_verified
            )
          )
        ''')
        .eq('id', postId)
        .single();

    final postMap = Map<String, dynamic>.from(response);
    _enrichWithProfile(postMap);

    // Check like/bookmark status
    final likeResponse = await _supabase
        .from(SupabaseConfig.likesTable)
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    final bookmarkResponse = await _supabase
        .from(SupabaseConfig.bookmarksTable)
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    postMap['is_liked'] = likeResponse != null;
    postMap['is_bookmarked'] = bookmarkResponse != null;

    return postMap;
  }

  /// Get posts by a specific user.
  Future<List<Map<String, dynamic>>> getUserPosts({
    required String userId,
    required String currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    // 1. Get IDs of posts where user is an accepted collaborator
    final collabResponse = await _supabase
        .from('post_collaborators')
        .select('post_id')
        .eq('user_id', userId)
        .eq('status', 'accepted');

    final List<String> collabPostIds =
        (collabResponse as List).map((e) => e['post_id'] as String).toList();

    // 2. Build OR filter: owner is user OR post is in collabPostIds
    String orFilter = 'user_id.eq.$userId';
    if (collabPostIds.isNotEmpty) {
      orFilter += ',id.in.(${collabPostIds.map((id) => '"$id"').join(",")})';
    }

    final response = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            full_name,
            avatar_url,
            is_verified
          ),
          collaborators:post_collaborators (
            user_id,
            status,
            profiles:user_id (
              username,
              avatar_url,
              is_verified
            )
          )
        ''')
        .or(orFilter)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (response.isEmpty) return [];
    return response.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item);
      _enrichWithProfile(map);
      return map;
    }).toList();
  }

  /// Get posts from a specific community.
  Future<List<Map<String, dynamic>>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            full_name,
            avatar_url,
            is_verified
          )
        ''')
        .eq('community_id', communityId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (response.isEmpty) return [];
    return response.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item);
      _enrichWithProfile(map);
      return map;
    }).toList();
  }

  /// Delete a post (verifies ownership).
  Future<void> deletePost(String postId, String userId) async {
    final post = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('user_id, image_url')
        .eq('id', postId)
        .single();

    if (post['user_id'] != userId) {
      throw Exception('Not authorized to delete this post');
    }

    // Delete image from storage if exists
    final imageUrl = post['image_url'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final fileName = imageUrl.split('/').last;
        await _supabase.storage.from(SupabaseConfig.postImagesBucket).remove([
          '$userId/$fileName',
        ]);
      } catch (e) {
        debugPrint('[PostRemoteDatasource] Delete image error: $e');
      }
    }

    await _supabase.from(SupabaseConfig.postsTable).delete().eq('id', postId);
  }

  /// Like a post.
  Future<void> likePost({
    required String userId,
    required String postId,
  }) async {
    try {
      final existingLike = await _supabase
          .from(SupabaseConfig.likesTable)
          .select('id')
          .eq('user_id', userId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existingLike != null) return;
    } catch (e) {
      debugPrint('[PostRemoteDatasource] Could not check existing like: $e');
    }

    await _supabase.from(SupabaseConfig.likesTable).insert({
      'user_id': userId,
      'post_id': postId,
    });
  }

  /// Unlike a post.
  Future<void> unlikePost({
    required String userId,
    required String postId,
  }) async {
    await _supabase
        .from(SupabaseConfig.likesTable)
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  /// Bookmark a post.
  Future<void> bookmarkPost({
    required String userId,
    required String postId,
  }) async {
    await _supabase.from(SupabaseConfig.bookmarksTable).insert({
      'user_id': userId,
      'post_id': postId,
    });
  }

  /// Remove bookmark.
  Future<void> unbookmarkPost({
    required String userId,
    required String postId,
  }) async {
    await _supabase
        .from(SupabaseConfig.bookmarksTable)
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  /// Get bookmarked posts.
  Future<List<Map<String, dynamic>>> getBookmarkedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase
        .from(SupabaseConfig.bookmarksTable)
        .select('''
          post_id,
          ${SupabaseConfig.postsTable} (
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (response.isEmpty) return [];

    final posts = <Map<String, dynamic>>[];
    for (final item in response) {
      final postData = item['posts'] as Map<String, dynamic>?;
      if (postData != null) {
        final profile = postData['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          postData['username'] = profile['username'];
          postData['user_avatar'] = profile['avatar_url'];
        }
        posts.add(postData);
      }
    }
    return posts;
  }

  /// Increment post views.
  Future<void> incrementViews(String postId) async {
    try {
      await _supabase.rpc('increment_post_views', params: {'post_id': postId});
    } catch (e) {
      debugPrint('[PostRemoteDatasource] Increment views error: $e');
    }
  }

  /// Share a post.
  Future<void> sharePost(String postId) async {
    final response = await _supabase
        .from(SupabaseConfig.postsTable)
        .select('shares_count')
        .eq('id', postId)
        .single();

    final currentCount = response['shares_count'] as int? ?? 0;

    await _supabase
        .from(SupabaseConfig.postsTable)
        .update({'shares_count': currentCount + 1})
        .eq('id', postId);
  }

  /// Vote in a poll.
  Future<void> voteInPoll({
    required String userId,
    required String pollId,
    required String optionId,
  }) async {
    try {
      // Check if user has already voted in this poll
      final existingVote = await _supabase
          .from(SupabaseConfig.pollVotesTable)
          .select()
          .eq('poll_id', pollId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingVote != null) {
        throw Exception('User has already voted in this poll');
      }

      await _supabase.from(SupabaseConfig.pollVotesTable).insert({
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('[PostRemoteDatasource] Vote in poll error: $e');
      rethrow;
    }
  }

  /// Get poll details with current vote counts.
  Future<Map<String, dynamic>> getPoll(String pollId, String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.pollsTable)
          .select('''
            *,
            options:${SupabaseConfig.pollOptionsTable} (*)
          ''')
          .eq('id', pollId)
          .single();

      final pollMap = Map<String, dynamic>.from(response);

      // Check if current user has voted
      final voteResponse = await _supabase
          .from(SupabaseConfig.pollVotesTable)
          .select('option_id')
          .eq('poll_id', pollId)
          .eq('user_id', userId)
          .maybeSingle();

      pollMap['has_voted'] = voteResponse != null;
      pollMap['user_voted_option_id'] = voteResponse?['option_id'];

      // Calculate total votes and percentages if not handled by DB views/triggers
      final List<dynamic> options = pollMap['options'] ?? [];
      int totalVotes = 0;
      for (var opt in options) {
        totalVotes += (opt['vote_count'] as int? ?? 0);
      }
      pollMap['total_votes'] = totalVotes;

      return pollMap;
    } catch (e) {
      debugPrint('[PostRemoteDatasource] Get poll error: $e');
      rethrow;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _enrichWithProfile(Map<String, dynamic> postMap) {
    final profile = postMap[SupabaseConfig.profilesTable];
    if (profile != null) {
      postMap['username'] = profile['username'];
      postMap['user_avatar'] = profile['avatar_url'];
      postMap['is_verified'] = profile['is_verified'] ?? false;
    }
  }

  void _enrichWithCommunity(Map<String, dynamic> postMap) {
    final community = postMap['communities'];
    if (community != null) {
      postMap['community_name'] = community['name'];
    }
  }
}
