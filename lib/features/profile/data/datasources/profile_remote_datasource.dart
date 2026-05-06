import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfileRemoteDatasource {
  final SupabaseClient _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  Future<Map<String, dynamic>> getProfile(String userId) async {
    if (userId.isEmpty) {
      debugPrint('[ProfileRemoteDatasource] Blocking getProfile attempt with empty userId');
      return {}; // Return empty map or throw error. Calling code handles empty map or errors.
    }
    try {
      final response =
          await _supabase
              .from(SupabaseConfig.profilesTable)
              .select('id, username, full_name, avatar_url, bio, location, website, is_verified, is_private, followers_count, following_count, posts_count, is_pro, created_at, xp, level, public_key, banner_url, banner_color')
              .eq('id', userId)
              .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error fetching profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getProfileByUsername(String username) async {
    try {
      final response =
          await _supabase
              .from(SupabaseConfig.profilesTable)
              .select('id, username, full_name, avatar_url, bio, location, website, is_verified, is_private, followers_count, following_count, posts_count, is_pro, created_at, xp, level, public_key, banner_url, banner_color')
              .eq('username', username)
              .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint(
        '[ProfileRemoteDatasource] Error fetching profile by username: $e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    String? location,
    String? website,
    String? bannerColor,
    String? avatarFilePath,
    String? bannerFilePath,
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      if (!isPro && bannerColor != null) {
        throw Exception(
          'Upgrade to Oasis Pro to use custom banner colors and themes.',
        );
      }

      String? avatarUrl;
      String? bannerUrl;

      if (avatarFilePath != null) {
        try {
          final fileExt = avatarFilePath.split('.').last;
          final fileName = '${_uuid.v4()}.$fileExt';
          final fileBytes = await _readFileBytes(avatarFilePath);

          await _supabase.storage
              .from(SupabaseConfig.profilePicturesBucket)
              .uploadBinary(
                '$userId/$fileName',
                fileBytes,
                fileOptions: FileOptions(
                  contentType: 'image/$fileExt',
                  upsert: true,
                ),
              );

          avatarUrl = _supabase.storage
              .from(SupabaseConfig.profilePicturesBucket)
              .getPublicUrl('$userId/$fileName');
        } catch (e) {
          debugPrint('[ProfileRemoteDatasource] Error uploading avatar: $e');
          throw Exception('Failed to upload avatar');
        }
      }

      if (bannerFilePath != null) {
        try {
          final fileExt = bannerFilePath.split('.').last;
          final fileName = 'banner_${_uuid.v4()}.$fileExt';
          final fileBytes = await _readFileBytes(bannerFilePath);

          await _supabase.storage
              .from(SupabaseConfig.profilePicturesBucket)
              .uploadBinary(
                '$userId/$fileName',
                fileBytes,
                fileOptions: FileOptions(
                  contentType: 'image/$fileExt',
                  upsert: true,
                ),
              );

          bannerUrl = _supabase.storage
              .from(SupabaseConfig.profilePicturesBucket)
              .getPublicUrl('$userId/$fileName');
        } catch (e) {
          debugPrint('[ProfileRemoteDatasource] Error uploading banner: $e');
        }
      }

      final updateData = <String, dynamic>{};
      if (username != null) updateData['username'] = username;
      if (fullName != null) updateData['full_name'] = fullName;
      if (bio != null) updateData['bio'] = bio;
      if (location != null) updateData['location'] = location;
      if (website != null) updateData['website'] = website;
      if (bannerColor != null) updateData['banner_color'] = bannerColor;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      if (bannerUrl != null) updateData['banner_url'] = bannerUrl;

      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update(updateData)
          .eq('id', userId);

      return getProfile(userId);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error updating profile: $e');
      if (e is PostgrestException && e.code == '23505') {
        throw Exception('Username is already taken');
      }
      rethrow;
    }
  }

  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) {
      debugPrint('[ProfileRemoteDatasource] Blocking self-follow attempt: $followerId');
      return;
    }
    try {
      await _supabase.from(SupabaseConfig.followsTable).insert({
        'follower_id': followerId,
        'following_id': followingId,
      });
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error following user: $e');
      rethrow;
    }
  }

  Future<void> sendFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _supabase.from('follow_requests').insert({
        'follower_id': followerId,
        'following_id': followingId,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error sending follow request: $e');
      rethrow;
    }
  }

  Future<void> acceptFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _supabase
          .from('follow_requests')
          .update({'status': 'accepted'})
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error accepting follow request: $e');
      rethrow;
    }
  }

  Future<void> declineFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _supabase
          .from('follow_requests')
          .update({'status': 'declined'})
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error declining follow request: $e');
      rethrow;
    }
  }

  Future<bool> hasSentFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final response = await _supabase
          .from('follow_requests')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .eq('status', 'pending')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error checking follow request: $e');
      return false;
    }
  }

  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.followsTable)
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final response =
          await _supabase
              .from(SupabaseConfig.followsTable)
              .select()
              .eq('follower_id', followerId)
              .eq('following_id', followingId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error checking follow status: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFollowers({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.followsTable)
          .select('''
            follower_id,
            ${SupabaseConfig.profilesTable}:follower_id (id, username, full_name, avatar_url, is_verified)
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Map<String, dynamic>> followers = [];
      for (final item in response) {
        final profileData = item[SupabaseConfig.profilesTable];
        if (profileData != null) {
          followers.add(Map<String, dynamic>.from(profileData));
        }
      }

      return followers;
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error fetching followers: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getFollowing({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.followsTable)
          .select('''
            following_id,
            ${SupabaseConfig.profilesTable}:following_id (id, username, full_name, avatar_url, is_verified)
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Map<String, dynamic>> following = [];
      for (final item in response) {
        final profileData = item[SupabaseConfig.profilesTable];
        if (profileData != null) {
          following.add(Map<String, dynamic>.from(profileData));
        }
      }

      return following;
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error fetching following: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id, username, full_name, avatar_url, is_verified')
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(limit);

      if (response.isEmpty) return [];

      return response.map((json) => Map<String, dynamic>.from(json)).toList();
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error searching users: $e');
      rethrow;
    }
  }

  Future<void> updatePrivacy({
    required String userId,
    required bool isPrivate,
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update({'is_private': isPrivate})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[ProfileRemoteDatasource] Error updating privacy: $e');
      rethrow;
    }
  }

  Future<Uint8List> _readFileBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }
}
