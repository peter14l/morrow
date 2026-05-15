import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:uuid/uuid.dart';

class StoriesService {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  /// Get story groups from following users
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
      debugPrint('Error fetching following stories: $e');
      return [];
    }
  }

  /// Get active stories for a specific user
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
      debugPrint('Error fetching user stories: $e');
      return [];
    }
  }

  /// Get current user's own stories
  Future<List<StoryEntity>> getMyStories() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      return await getUserStories(userId);
    } catch (e) {
      debugPrint('Error fetching my stories: $e');
      return [];
    }
  }

  /// Create a new story
  Future<StoryEntity?> createStory({
    required File file,
    required String mediaType, // 'image' or 'video'
    String? caption,
    int duration = 5,
    bool autoPostToSocial = false,
    String? musicId,
    Map<String, dynamic>? musicMetadata,
    List<Map<String, dynamic>>? interactiveMetadata,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final isPro = SubscriptionService().isPro;

      if (!isPro) {
        if (autoPostToSocial) {
          throw Exception(
            'Upgrade to Oasis Pro to auto-share stories to social platforms.',
          );
        }

        final myStories = await getMyStories();
        if (myStories.length >= 3) {
          throw Exception(
            'Free tier is limited to 3 active stories. Upgrade to Oasis Pro for unlimited stories.',
          );
        }
      }

      // 1. Upload file to storage
      final fileExt = file.path.split('.').last;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.$fileExt';

      await _supabase.storage.from('stories').upload('$userId/$fileName', file);

      final mediaUrl = _supabase.storage
          .from('stories')
          .getPublicUrl('$userId/$fileName');

      // 2. Create story record
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final response = await _supabase
          .from('stories')
          .insert({
            'user_id': userId,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'caption': caption,
            'duration': duration,
            'created_at': now.toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'music_id': musicId,
            'music_metadata': musicMetadata,
            'interactive_metadata': interactiveMetadata,
          })
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url
            )
          ''')
          .single();

      // 3. Parse response
      final storyData = Map<String, dynamic>.from(response);
      final profile = storyData['profiles'];

      if (profile != null) {
        storyData['username'] = profile['username'];
        storyData['user_avatar'] = profile['avatar_url'];
      }

      return StoryEntity.fromJson(storyData);
    } catch (e) {
      debugPrint('Error creating story: $e');
      return null;
    }
  }

  /// Mark story as viewed
  Future<bool> viewStory(String storyId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': userId,
      });

      return true;
    } catch (e) {
      // Ignore duplicate view errors
      if (e is PostgrestException && e.code == '23505') {
        return true; // Already viewed
      }
      debugPrint('Error viewing story: $e');
      return false;
    }
  }

  /// Get viewers of a story (for story owner)
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
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

      return (response as List)
          .map(
            (item) => {
              'viewed_at': item['viewed_at'],
              'user': item['profiles'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching story viewers: $e');
      return [];
    }
  }

  /// Delete a story
  Future<bool> deleteStory(String storyId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      // Get story to delete media file
      final story = await _supabase
          .from('stories')
          .select('media_url, user_id')
          .eq('id', storyId)
          .single();

      // Verify ownership
      if (story['user_id'] != userId) {
        throw Exception('Not authorized to delete this story');
      }

      // Delete from database (will cascade delete views and reactions)
      await _supabase.from('stories').delete().eq('id', storyId);

      // Delete media file from storage
      try {
        final mediaUrl = story['media_url'] as String;
        final path = mediaUrl.split('/stories/').last;
        await _supabase.storage.from('stories').remove([path]);
      } catch (e) {
        debugPrint('Error deleting story media: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting story: $e');
      return false;
    }
  }

  /// React to a story
  Future<bool> reactToStory(String storyId, String emoji) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('story_reactions').upsert({
        'story_id': storyId,
        'user_id': userId,
        'emoji': emoji,
      });

      return true;
    } catch (e) {
      debugPrint('Error reacting to story: $e');
      return false;
    }
  }

  /// Remove reaction from a story
  Future<bool> removeReaction(String storyId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('story_reactions')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      return false;
    }
  }

  /// Clean up expired stories (call this periodically)
  Future<void> cleanupExpiredStories() async {
    try {
      await _supabase.rpc('delete_expired_stories');
    } catch (e) {
      debugPrint('Error cleaning up expired stories: $e');
    }
  }
}
