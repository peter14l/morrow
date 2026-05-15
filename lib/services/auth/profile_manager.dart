import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';

class ProfileManager {
  SupabaseClient get _supabase => SupabaseService().client;

  // Update profile
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final updates = <String, dynamic>{};

    if (username != null) {
      // Check if username is available
      final usernameCheck = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id')
          .eq('username', username)
          .neq('id', userId)
          .maybeSingle();

      if (usernameCheck != null) {
        throw const AuthException('Username is already taken');
      }
      updates['username'] = username;
    }

    if (displayName != null) {
      updates['full_name'] = displayName;
    }

    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    if (updates.isNotEmpty) {
      await _supabase
          .from(SupabaseConfig.profilesTable)
          .update(updates)
          .eq('id', userId);

      // Update auth user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'username':
                username ??
                _supabase.auth.currentUser?.userMetadata?['username'],
            'full_name':
                displayName ??
                _supabase.auth.currentUser?.userMetadata?['full_name'],
            'avatar_url':
                avatarUrl ??
                _supabase.auth.currentUser?.userMetadata?['avatar_url'],
          },
        ),
      );
    }
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(String filePath) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final fileExt = filePath.split('.').last;
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final file = File(filePath);

    await _supabase.storage
        .from(SupabaseConfig.profilePicturesBucket)
        .upload(
          'profiles/$userId/$fileName',
          file,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl =
        '${SupabaseConfig.supabaseUrl}/storage/v1/object/public/${SupabaseConfig.profilePicturesBucket}/profiles/$userId/$fileName';

    // Update profile with new avatar URL
    await updateProfile(avatarUrl: publicUrl);

    return publicUrl;
  }

  // Get public keys for a list of user IDs
  Future<Map<String, String>> getPublicKeys(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id, public_key')
          .inFilter('id', userIds);

      final Map<String, String> keys = {};
      for (final profile in response) {
        final pk = profile['public_key'] as String?;
        final id = profile['id'] as String;
        if (pk != null) {
          keys[id] = pk;
        }
      }
      return keys;
    } catch (e) {
      debugPrint('[ProfileManager] Error fetching public keys: $e');
      return {};
    }
  }

  // Get public key for a single user ID
  Future<String?> getPublicKey(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('public_key')
          .eq('id', userId)
          .maybeSingle();

      return response?['public_key'] as String?;
    } catch (e) {
      debugPrint('[ProfileManager] Error fetching public key: $e');
      return null;
    }
  }

  // Helper method to create a user profile
  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String username,
    String? displayName,
    String? avatarUrl,
  }) async {
    await _supabase.from(SupabaseConfig.profilesTable).upsert({
      'id': userId,
      'email': email,
      'username': username.toLowerCase(),
      'full_name': displayName ?? username,
      'avatar_url': avatarUrl,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
