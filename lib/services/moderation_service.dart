import 'package:flutter/foundation.dart';
import 'package:oasis/models/moderation.dart';
import 'package:oasis/core/network/supabase_client.dart';

class ModerationService {
  final _supabase = SupabaseService().client;

  // =====================================================
  // REPORTING
  // =====================================================

  /// Submit a report
  Future<String?> submitReport({
    String? reportedUserId,
    String? postId,
    String? commentId,
    String? messageId,
    required String category,
    required String reason,
    String? description,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final reportId = await _supabase.rpc(
        'submit_report',
        params: {
          'reporter': userId,
          'report_category': category,
          'report_reason': reason,
          'reported_user': reportedUserId,
          'reported_post': postId,
          'reported_comment': commentId,
          'reported_message': messageId,
          'report_description': description,
        },
      );

      return reportId as String?;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return null;
    }
  }

  /// Get user's submitted reports
  Future<List<Report>> getUserReports() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_user_reports',
        params: {'requesting_user_id': userId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => Report.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      return [];
    }
  }

  // =====================================================
  // BLOCKING
  // =====================================================

  /// Block a user
  Future<bool> blockUser(String blockedUserId, {String? reason}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase.from('blocked_users').insert({
        'blocker_id': userId,
        'blocked_id': blockedUserId,
        'reason': reason,
      });

      return true;
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String blockedUserId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', blockedUserId);

      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return false;
    }
  }

  /// Get blocked users list
  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_blocked_users',
        params: {'requesting_user_id': userId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => BlockedUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
      return [];
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String otherUserId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase.rpc(
        'is_user_blocked',
        params: {'user_a': userId, 'user_b': otherUserId},
      );

      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  // =====================================================
  // MUTING
  // =====================================================

  /// Mute a user
  Future<bool> muteUser(
    String mutedUserId, {
    String? reason,
    Duration? duration,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final expiresAt = duration != null
          ? DateTime.now().add(duration).toIso8601String()
          : null;

      await _supabase.from('muted_users').insert({
        'muter_id': userId,
        'muted_id': mutedUserId,
        'reason': reason,
        'expires_at': expiresAt,
      });

      return true;
    } catch (e) {
      debugPrint('Error muting user: $e');
      return false;
    }
  }

  /// Unmute a user
  Future<bool> unmuteUser(String mutedUserId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('muted_users')
          .delete()
          .eq('muter_id', userId)
          .eq('muted_id', mutedUserId);

      return true;
    } catch (e) {
      debugPrint('Error unmuting user: $e');
      return false;
    }
  }

  /// Get muted users list
  Future<List<MutedUser>> getMutedUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_muted_users',
        params: {'requesting_user_id': userId},
      );

      if (response == null || response.isEmpty) return [];

      return (response as List)
          .map((json) => MutedUser.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching muted users: $e');
      return [];
    }
  }

  /// Check if a user is muted
  Future<bool> isUserMuted(String otherUserId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final result = await _supabase.rpc(
        'is_user_muted',
        params: {'muter': userId, 'muted': otherUserId},
      );

      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking if user is muted: $e');
      return false;
    }
  }

  /// Clean up expired mutes
  Future<void> cleanupExpiredMutes() async {
    try {
      await _supabase.rpc('cleanup_expired_mutes');
    } catch (e) {
      debugPrint('Error cleaning up expired mutes: $e');
    }
  }

  // =====================================================
  // CONTENT FILTERING
  // =====================================================

  /// Filter posts to exclude blocked/muted users
  List<T> filterBlockedContent<T>(
    List<T> items,
    Set<String> blockedUserIds,
    Set<String> mutedUserIds,
    String Function(T) getUserId,
  ) {
    return items.where((item) {
      final userId = getUserId(item);
      return !blockedUserIds.contains(userId) && !mutedUserIds.contains(userId);
    }).toList();
  }

  /// Get all blocked and muted user IDs for filtering
  Future<Set<String>> getFilteredUserIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final blocked = await getBlockedUsers();
      final muted = await getMutedUsers();

      return {
        ...blocked.map((b) => b.blockedId),
        ...muted.map((m) => m.mutedId),
      };
    } catch (e) {
      debugPrint('Error getting filtered user IDs: $e');
      return {};
    }
  }
}
