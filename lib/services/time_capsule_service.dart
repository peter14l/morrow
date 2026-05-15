import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:uuid/uuid.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/services/privacy_audit_service.dart';

class TimeCapsuleService {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();
  final _encryption = EncryptionService();
  final _privacyAudit = PrivacyAuditService();

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

        if (activeCapsulesResponse.length >= 2) {
          throw Exception(
            'Free tier is limited to 2 active time capsules. Upgrade to Oasis Pro for unlimited capsules.',
          );
        }
      }

      // E2EE Encryption
      if (!_encryption.isInitialized) await _encryption.init();
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('public_key, username, avatar_url')
          .eq('id', userId)
          .single();

      final publicKey = profileResponse['public_key'] as String?;
      if (publicKey == null) {
        throw Exception(
          'Encryption not set up. Please enable E2EE in settings first.',
        );
      }

      final encrypted = await _encryption.encryptMessage(content, [publicKey]);

      final capsuleId = _uuid.v4();

      final capsuleData = {
        'id': capsuleId,
        'user_id': userId,
        'content': encrypted.encryptedContent,
        'encrypted_keys': encrypted.encryptedKeys,
        'iv': encrypted.iv,
        'unlock_date': unlockDate.toIso8601String(),
        'media_url': mediaUrl,
        'media_type': mediaType,
        'is_locked': true, // Always locked initially
      };

      await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .insert(capsuleData);

      // Privacy Audit: Log WRITE
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'time_capsule',
        action: 'WRITE',
      );

      // Fetch the created capsule
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('id', capsuleId)
          .single();

      final mergedData = Map<String, dynamic>.from(response);
      mergedData[SupabaseConfig.profilesTable] = profileResponse;

      final capsule = _transformResponse(mergedData);
      return _decryptCapsule(capsule);
    } catch (e) {
      debugPrint('Error creating time capsule: $e');
      rethrow;
    }
  }

  /// Get user's own capsules (visible only to the owner)
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

      // Privacy Audit: Log READ
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'time_capsule',
        action: 'READ',
      );

      if (response.isEmpty) return [];

      // Fetch profile for the current user
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final capsules = (response as List).map((e) {
        final mergedData = Map<String, dynamic>.from(e);
        if (profileResponse != null) {
          mergedData[SupabaseConfig.profilesTable] = profileResponse;
        }
        return _transformResponse(mergedData);
      }).toList();

      return Future.wait(capsules.map(_decryptCapsule));
    } catch (e) {
      debugPrint('Error getting capsules: $e');
      rethrow;
    }
  }

  /// Get ONLY unlocked capsules for a user (My Past Capsules)
  Future<List<TimeCapsule>> getMyUnlockedCapsules(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('user_id', userId)
          .lte('unlock_date', now)
          .order('unlock_date', ascending: false);

      // Privacy Audit: Log READ
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'time_capsule',
        action: 'READ',
      );

      if (response.isEmpty) return [];

      // Fetch profile for the current user
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      final capsules = (response as List).map((e) {
        final mergedData = Map<String, dynamic>.from(e);
        if (profileResponse != null) {
          mergedData[SupabaseConfig.profilesTable] = profileResponse;
        }
        return _transformResponse(mergedData);
      }).toList();

      return Future.wait(capsules.map(_decryptCapsule));
    } catch (e) {
      debugPrint('Error getting unlocked capsules: $e');
      rethrow;
    }
  }

  /// Check and update lock status if needed
  /// Use this if we want to update the DB status,
  /// though strictly speaking we can compute isLocked on the fly from unlockDate.
  /// For this implementation, we'll mostly rely on DateTime comparison in the Model/UI.

  /// Get a single capsule by ID
  Future<TimeCapsule> getCapsule(String capsuleId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .select()
          .eq('id', capsuleId)
          .single();

      final userId = response['user_id'] as String;

      // Privacy Audit: Log READ
      await _privacyAudit.logAccess(
        userId: userId,
        resourceType: 'time_capsule',
        action: 'READ',
      );

      // Fetch profile separately
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('username, avatar_url')
          .eq('id', userId)
          .single();

      final mergedData = Map<String, dynamic>.from(response);
      mergedData[SupabaseConfig.profilesTable] = profileResponse;

      final capsule = _transformResponse(mergedData);
      return _decryptCapsule(capsule);
    } catch (e) {
      debugPrint('Error getting capsule: $e');
      rethrow;
    }
  }

  Future<TimeCapsule> _decryptCapsule(TimeCapsule capsule) async {
    // Only decrypt if it's unlocked and has E2EE fields
    if (capsule.isLocked) return capsule;
    if (capsule.encryptedKeys == null || capsule.iv == null) return capsule;

    try {
      if (!_encryption.isInitialized) await _encryption.init();
      final decrypted = await _encryption.decryptMessage(
        capsule.content,
        capsule.encryptedKeys!,
        capsule.iv!,
      );

      if (decrypted != null) {
        return capsule.copyWith(content: decrypted);
      }
    } catch (e) {
      debugPrint('Decryption error for capsule ${capsule.id}: $e');
    }
    return capsule;
  }

  TimeCapsule _transformResponse(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final profile = map[SupabaseConfig.profilesTable];

    if (profile != null) {
      map['username'] = profile['username'];
      map['user_avatar'] = profile['avatar_url'];
    }

    // Recalculate is_locked based on server time or local time vs unlock_date?
    // Let's trust the data for now, but strictly:
    final unlockDate = DateTime.parse(map['unlock_date']);
    map['is_locked'] = DateTime.now().isBefore(unlockDate);

    return TimeCapsule.fromJson(map);
  }
}
