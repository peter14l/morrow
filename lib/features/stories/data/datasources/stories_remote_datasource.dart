import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';

/// Remote data source for stories - handles all Supabase API calls.
class StoriesRemoteDatasource {
  final SupabaseClient _supabase;

  StoriesRemoteDatasource({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseService().client;

  /// Get story groups from following users via RPC.
  Future<List<StoryGroupEntity>> getFollowingStories() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_following_stories',
        params: {'requesting_user_id': userId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map(
            (json) => StoryGroupEntity.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get active stories for a specific user.
  Future<List<StoryEntity>> getUserStories(String targetUserId) async {
    try {
      final response = await _supabase.rpc(
        'get_active_stories',
        params: {'target_user_id': targetUserId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => StoryEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a new story.
  Future<StoryEntity?> createStory({
    required String userId,
    required String mediaUrl,
    required String mediaType,
    String? thumbnailUrl,
    String? caption,
    int duration = 5,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    final response = await _supabase
        .from('stories')
        .insert({
          'user_id': userId,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'thumbnail_url': thumbnailUrl,
          'caption': caption,
          'duration': duration,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        })
        .select('''
      *,
      profiles:user_id (
        username,
        avatar_url
      )
    ''')
        .single();

    final storyData = Map<String, dynamic>.from(response);
    final profile = storyData['profiles'];

    if (profile != null) {
      storyData['username'] = profile['username'];
      storyData['user_avatar'] = profile['avatar_url'];
    }

    return StoryEntity.fromJson(storyData);
  }

  /// Mark story as viewed.
  Future<bool> viewStory(String storyId, String userId) async {
    try {
      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': userId,
      });
      return true;
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        return true; // Already viewed
      }
      return false;
    }
  }

  /// Get viewers of a story.
  Future<List<StoryViewerEntity>> getStoryViewers(String storyId) async {
    try {
      final response = await _supabase
          .from('story_views')
          .select('''
            viewed_at,
            profiles:viewer_id (
              id,
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('story_id', storyId)
          .order('viewed_at', ascending: false);

      return (response as List).map((item) {
        return StoryViewerEntity.fromJson(
          item['profiles'] as Map<String, dynamic>,
          item['viewed_at'] as String,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete a story.
  Future<bool> deleteStory(String storyId, String userId) async {
    try {
      // Get story to verify ownership and get media URL
      final story = await _supabase
          .from('stories')
          .select('media_url, user_id')
          .eq('id', storyId)
          .single();

      if (story['user_id'] != userId) {
        throw Exception('Not authorized');
      }

      // Delete from database
      await _supabase.from('stories').delete().eq('id', storyId);

      // Delete media from storage
      try {
        final mediaUrl = story['media_url'] as String;
        final path = mediaUrl.split('/stories/').last;
        await _supabase.storage.from('stories').remove([path]);
      } catch (_) {
        // Ignore storage errors
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// React to a story.
  Future<bool> reactToStory(String storyId, String userId, String emoji) async {
    try {
      await _supabase.from('story_reactions').upsert({
        'story_id': storyId,
        'user_id': userId,
        'emoji': emoji,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove reaction from a story.
  Future<bool> removeReaction(String storyId, String userId) async {
    try {
      await _supabase
          .from('story_reactions')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean up expired stories.
  Future<void> cleanupExpiredStories() async {
    try {
      await _supabase.rpc('delete_expired_stories');
    } catch (_) {}
  }
}
