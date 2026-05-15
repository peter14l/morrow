import 'package:flutter/foundation.dart';
import 'package:oasis/features/feed/domain/models/hashtag.dart';
import 'package:oasis/core/network/supabase_client.dart';

class HashtagService {
  final _supabase = SupabaseService().client;

  /// Search hashtags by query
  Future<List<Hashtag>> searchHashtags(String query, {int limit = 10}) async {
    try {
      // Remove # if present
      final cleanQuery = query.replaceAll('#', '');

      if (cleanQuery.isEmpty) return [];

      final response = await _supabase.rpc(
        'search_hashtags',
        params: {'search_query': cleanQuery, 'limit_count': limit},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => Hashtag.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error searching hashtags: $e');
      return [];
    }
  }

  /// Get trending hashtags
  Future<List<Hashtag>> getTrendingHashtags({int limit = 10}) async {
    try {
      final response = await _supabase.rpc(
        'get_trending_hashtags',
        params: {'limit_count': limit},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => Hashtag.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching trending hashtags: $e');
      return [];
    }
  }

  /// Get posts for a specific hashtag
  Future<List<Map<String, dynamic>>> getPostsByHashtag(
    String tag, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Remove # if present
      final cleanTag = tag.replaceAll('#', '');

      // Get hashtag ID
      final hashtag = await _supabase
          .from('hashtags')
          .select('id')
          .eq('normalized_tag', cleanTag.toLowerCase())
          .maybeSingle();

      if (hashtag == null) return [];

      // Get posts with this hashtag
      final response = await _supabase
          .from('post_hashtags')
          .select('''
            posts:post_id (
              id,
              user_id,
              content,
              image_url,
              video_url,
              likes_count,
              comments_count,
              shares_count,
              created_at,
              profiles:user_id (
                username,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('hashtag_id', hashtag['id'])
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((item) => item['posts'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching posts by hashtag: $e');
      return [];
    }
  }

  /// Get hashtag details
  Future<Hashtag?> getHashtagDetails(String tag) async {
    try {
      final cleanTag = tag.replaceAll('#', '');

      final response = await _supabase
          .from('hashtags')
          .select()
          .eq('normalized_tag', cleanTag.toLowerCase())
          .maybeSingle();

      if (response == null) return null;

      return Hashtag.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching hashtag details: $e');
      return null;
    }
  }

  /// Extract hashtags from text
  static List<String> extractHashtags(String text) {
    final regex = RegExp(r'#([a-zA-Z0-9_]+)');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1)!).toList();
  }

  /// Extract mentions from text
  static List<String> extractMentions(String text) {
    final regex = RegExp(r'@([a-z0-9_]+)');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1)!).toList();
  }

  /// Format text with clickable hashtags and mentions
  static String formatText(String text) {
    // This is a helper for UI - actual formatting done in widgets
    return text;
  }
}
