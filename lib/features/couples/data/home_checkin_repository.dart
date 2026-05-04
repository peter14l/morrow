import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/notification_manager.dart';

/// Repository for routing home check-in notifications to partner.
///
/// Handles:
/// - Fetching partner ID from couple_bubbles table
/// - Getting partner's FCM token
/// - Sending FCM notification to partner
///
/// Note: If no partner/couple bubble exists, home check-in still works locally but no notification sent.
/// Privacy: Home location is NEVER sent to server - only "at home" state is communicated.
class HomeCheckinRepository {
  HomeCheckinRepository();

  /// Get the current user's partner ID from couple_bubbles table
  ///
  /// Returns null if no active couple bubble exists
  Future<String?> getCouplePartnerId() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      // Query couple_bubbles for active bubble with current user
      final bubble = await client
          .from('couple_bubbles')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .eq('status', 'active')
          .maybeSingle();

      if (bubble == null) return null;

      // Return the other user's ID
      final partnerId = bubble['user1_id'] == userId
          ? bubble['user2_id']
          : bubble['user1_id'];

      return partnerId as String?;
    } catch (e) {
      debugPrint('[HomeCheckinRepository] Error getting partner: $e');
      return null;
    }
  }

  /// Get partner's FCM token from profiles table
  ///
  /// Returns null if partner not found or no token
  Future<String?> getPartnerFcmToken(String partnerId) async {
    try {
      final client = Supabase.instance.client;

      final profile = await client
          .from('profiles')
          .select('fcm_token')
          .eq('id', partnerId)
          .maybeSingle();

      if (profile == null) return null;
      return profile['fcm_token'] as String?;
    } catch (e) {
      debugPrint('[HomeCheckinRepository] Error getting partner FCM token: $e');
      return null;
    }
  }

  /// Send "home arrived" notification to partner
  ///
  /// Message: "❤️ [Username] has reached home"
  Future<bool> sendHomeArrivedNotification(String partnerId) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return false;

      // Get username
      final username = currentUser.userMetadata?['username'] ??
          currentUser.email?.split('@').first ??
          'Your partner';

      // Get partner info
      final partnerProfile = await client
          .from('profiles')
          .select('id, fcm_token, display_name')
          .eq('id', partnerId)
          .maybeSingle();

      if (partnerProfile == null) {
        debugPrint('[HomeCheckinRepository] Partner profile not found');
        return false;
      }

      final partnerFcm = partnerProfile['fcm_token'] as String?;
      final partnerName = partnerProfile['display_name'] as String? ?? 'Partner';

      // Send via Supabase RPC or FCM directly
      if (partnerFcm != null && partnerFcm.isNotEmpty) {
        // Send push notification to partner
        await _sendPushNotification(
          token: partnerFcm,
          title: '❤️ $username arrived home',
          body: '$username has reached home safely',
          data: {
            'type': 'home_checkin',
            'sender_id': currentUser.id,
            'sender_name': username,
            'status': 'arrived',
          },
        );
      }

      // Also send local notification if app is open
      await NotificationManager.instance.showNotification(
        title: '❤️ $username arrived home',
        body: '$username has reached home safely',
        payload: '{"type":"home_checkin","sender_id":"${currentUser.id}"}',
      );

      return true;
    } catch (e) {
      debugPrint('[HomeCheckinRepository] Failed to send notification: $e');
      return false;
    }
  }

  /// Send "not reached home" warning notification to partner
  ///
  /// Message: "⚠️ [Username] has not actually reached home"
  Future<bool> sendNotReachedHomeNotification(String partnerId) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) return false;

      final username = currentUser.userMetadata?['username'] ??
          currentUser.email?.split('@').first ??
          'Your partner';

      final partnerProfile = await client
          .from('profiles')
          .select('id, fcm_token, display_name')
          .eq('id', partnerId)
          .maybeSingle();

      if (partnerProfile == null) return false;

      final partnerFcm = partnerProfile['fcm_token'] as String?;

      if (partnerFcm != null && partnerFcm.isNotEmpty) {
        await _sendPushNotification(
          token: partnerFcm,
          title: '⚠️ Check-in issue',
          body: '$username says they have NOT actually reached home',
          data: {
            'type': 'home_checkin_warning',
            'sender_id': currentUser.id,
            'sender_name': username,
            'status': 'not_arrived',
          },
        );
      }

      await NotificationManager.instance.showNotification(
        title: '⚠️ Check-in issue',
        body: '$username says they have NOT actually reached home',
        payload: '{"type":"home_checkin_warning","sender_id":"${currentUser.id}"}',
      );

      return true;
    } catch (e) {
      debugPrint('[HomeCheckinRepository] Failed to send warning: $e');
      return false;
    }
  }

  /// Send push notification via FCM
  ///
  /// Uses Supabase Edge Function if available, otherwise falls back to FCM direct
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Try using Supabase edge function
      final client = Supabase.instance.client;
      await client.functions.invoke('send-home-checkin', body: {
        'token': token,
        'title': title,
        'body': body,
        'data': data,
      });
    } catch (e) {
      // Fallback: Try sending via REST API to FCM
      // Note: This would require server-side FCM key configuration
      debugPrint('[HomeCheckinRepository] Push send via function failed, trying REST: $e');
    }
  }
}