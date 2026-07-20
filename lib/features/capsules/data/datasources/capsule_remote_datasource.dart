import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Remote datasource for Time Capsule operations via Supabase
class CapsuleRemoteDatasource {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  /// Get all capsules for a user
  Future<List<TimeCapsule>> getCapsules({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if ((response as List).isEmpty) return [];

      // Fetch profile for the current user
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      return (response as List).map((e) {
        final mergedData = Map<String, dynamic>.from(e);
        if (profileResponse != null) {
          mergedData['username'] = profileResponse['username'];
          mergedData['user_avatar'] = profileResponse['avatar_url'];
        }

        // Recalculate is_locked based on unlock_date
        final unlockDate = DateTime.parse(mergedData['unlock_date']);
        mergedData['is_locked'] = DateTime.now().isBefore(unlockDate);

        return TimeCapsule.fromJson(mergedData);
      }).toList();
    } catch (e) {
      debugPrint('Error getting capsules: $e');
      rethrow;
    }
  }

  /// Get a single capsule by ID
  Future<TimeCapsule?> getCapsuleById(String capsuleId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('id', capsuleId)
          .maybeSingle();

      if (response == null) return null;

      // Fetch profile separately
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, avatar_url')
          .eq('id', response['user_id'])
          .maybeSingle();

      final mergedData = Map<String, dynamic>.from(response);
      if (profileResponse != null) {
        mergedData['username'] = profileResponse['username'];
        mergedData['user_avatar'] = profileResponse['avatar_url'];
      }

      final unlockDate = DateTime.parse(mergedData['unlock_date']);
      mergedData['is_locked'] = DateTime.now().isBefore(unlockDate);

      return TimeCapsule.fromJson(mergedData);
    } catch (e) {
      debugPrint('Error getting capsule: $e');
      rethrow;
    }
  }

  /// Create a new time capsule
  Future<TimeCapsule> createCapsule({
    required String userId,
    required String content,
    required DateTime unlockDate,
    String? mediaUrl,
    String mediaType = 'none',
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      if (!isPro) {
        final activeCapsulesResponse = await _supabase
            .from(SupabaseConfig.timeCapsulesTable)
            .select('id')
            .eq('user_id', userId)
            .eq('is_locked', true);

        if ((activeCapsulesResponse as List).length >= 2) {
          throw Exception(
            'Free tier is limited to 2 active time capsules. Upgrade to Oasis Pro for unlimited capsules.',
          );
        }
      }

      final capsuleId = _uuid.v4();

      final capsuleData = {
        'id': capsuleId,
        'user_id': userId,
        'content': content,
        'unlock_date': unlockDate.toIso8601String(),
        'media_url': mediaUrl,
        'media_type': mediaType,
        'is_locked': true, // Always locked initially
      };

      await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .insert(capsuleData);

      // Fetch the created capsule
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('id', capsuleId)
          .single();

      // Fetch profile separately to avoid relationship error
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, avatar_url')
          .eq('id', userId)
          .single();

      final mergedData = Map<String, dynamic>.from(response);
      mergedData['username'] = profileResponse['username'];
      mergedData['user_avatar'] = profileResponse['avatar_url'];

      final actualUnlockDate = DateTime.parse(mergedData['unlock_date']);
      mergedData['is_locked'] = DateTime.now().isBefore(actualUnlockDate);

      return TimeCapsule.fromJson(mergedData);
    } catch (e) {
      debugPrint('Error creating time capsule: $e');
      rethrow;
    }
  }

  /// Open/unlock a capsule
  Future<TimeCapsule> openCapsule(String capsuleId) async {
    final capsule = await getCapsuleById(capsuleId);
    if (capsule == null) throw Exception('Capsule not found');

    if (DateTime.now().isBefore(capsule.unlockDate)) {
      throw Exception('Capsule is still locked until ${capsule.unlockDate}');
    }

    await _supabase
        .from(SupabaseConfig.timeCapsulesTable)
        .update({'is_locked': false})
        .eq('id', capsuleId);

    return capsule.copyWith(isLocked: false);
  }

  /// Contribute to an existing capsule
  Future<TimeCapsule> contributeToCapsule({
    required String capsuleId,
    required String content,
    String? mediaUrl,
    String mediaType = 'none',
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .update({
            'content': content,
            if (mediaUrl != null) 'media_url': mediaUrl,
            'media_type': mediaType,
          })
          .eq('id', capsuleId);

      // Fetch the updated capsule
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('id', capsuleId)
          .single();

      // Fetch profile separately
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, avatar_url')
          .eq('id', response['user_id'])
          .single();

      final mergedData = Map<String, dynamic>.from(response);
      mergedData['username'] = profileResponse['username'];
      mergedData['user_avatar'] = profileResponse['avatar_url'];

      final unlockDate = DateTime.parse(mergedData['unlock_date']);
      mergedData['is_locked'] = DateTime.now().isBefore(unlockDate);

      return TimeCapsule.fromJson(mergedData);
    } catch (e) {
      debugPrint('Error contributing to capsule: $e');
      rethrow;
    }
  }

  /// Delete a capsule
  Future<void> deleteCapsule(String capsuleId) async {
    try {
      await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .delete()
          .eq('id', capsuleId);
    } catch (e) {
      debugPrint('Error deleting capsule: $e');
      rethrow;
    }
  }
}
