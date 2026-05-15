import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/features/capsules/domain/repositories/capsule_repository.dart';
import 'package:uuid/uuid.dart';

/// Implementation of CapsuleRepository wrapping existing TimeCapsuleService logic
class CapsuleRepositoryImpl implements CapsuleRepository {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  @override
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

      if (response.isEmpty) return [];

      // Fetch profile for the current user
      final profileResponse = await _supabase
          .from(SupabaseConfig.profilesTable)
          .select('id, username, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      return (response as List).map((e) {
        final mergedData = Map<String, dynamic>.from(e);
        if (profileResponse != null) {
          mergedData[SupabaseConfig.profilesTable] = profileResponse;
        }
        return _transformResponse(mergedData);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<TimeCapsule?> getCapsuleById(String capsuleId) async {
    try {
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
      mergedData[SupabaseConfig.profilesTable] = profileResponse;

      return _transformResponse(mergedData);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<TimeCapsule> createCapsule({
    required String userId,
    required String content,
    required DateTime unlockDate,
    String? mediaUrl,
    String mediaType = 'none',
  }) async {
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

    final capsuleId = _uuid.v4();

    final capsuleData = {
      'id': capsuleId,
      'user_id': userId,
      'content': content,
      'unlock_date': unlockDate.toIso8601String(),
      'media_url': mediaUrl,
      'media_type': mediaType,
      'is_locked': true,
    };

    await _supabase.from(SupabaseConfig.timeCapsulesTable).insert(capsuleData);

    // Fetch the created capsule
    final response = await _supabase
        .from(SupabaseConfig.timeCapsulesTable)
        .select()
        .eq('id', capsuleId)
        .single();

    // Fetch profile separately
    final profileResponse = await _supabase
        .from(SupabaseConfig.profilesTable)
        .select('username, avatar_url')
        .eq('id', userId)
        .single();

    final mergedData = Map<String, dynamic>.from(response);
    mergedData[SupabaseConfig.profilesTable] = profileResponse;

    return _transformResponse(mergedData);
  }

  @override
  Future<TimeCapsule> openCapsule(String capsuleId) async {
    // Get the capsule to check unlock date
    final capsule = await getCapsuleById(capsuleId);
    if (capsule == null) {
      throw Exception('Capsule not found');
    }

    // Recalculate is_locked based on unlock date
    final now = DateTime.now();
    final unlockDate = capsule.unlockDate;

    // Update in database only if needed
    if (now.isAfter(unlockDate) && capsule.isLocked) {
      await _supabase
          .from(SupabaseConfig.timeCapsulesTable)
          .update({'is_locked': false})
          .eq('id', capsuleId);
    }

    // Return updated capsule
    final updated = await getCapsuleById(capsuleId);
    if (updated == null) {
      throw Exception('Failed to open capsule');
    }
    return updated;
  }

  @override
  Future<TimeCapsule> contributeToCapsule({
    required String capsuleId,
    required String content,
    String? mediaUrl,
    String mediaType = 'none',
  }) async {
    throw UnimplementedError('Contribute to capsule not yet implemented');
  }

  @override
  Future<void> deleteCapsule(String capsuleId) async {
    await _supabase
        .from(SupabaseConfig.timeCapsulesTable)
        .delete()
        .eq('id', capsuleId);
  }

  TimeCapsule _transformResponse(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final profile = map[SupabaseConfig.profilesTable];

    if (profile != null) {
      map['username'] = profile['username'];
      map['user_avatar'] = profile['avatar_url'];
    }

    // Recalculate is_locked based on unlock date vs current time
    final unlockDate = DateTime.parse(map['unlock_date']);
    map['is_locked'] = DateTime.now().isBefore(unlockDate);

    return TimeCapsule.fromJson(map);
  }
}
