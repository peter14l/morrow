import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/notifications/domain/models/notification_entity.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final _supabase = SupabaseService().client;

  /// Get user's notifications (excluding chat messages)
  Future<List<AppNotification>> getNotifications({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.notificationsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:actor_id (
              username,
              avatar_url
            )
          ''')
          .eq('user_id', userId)
          .neq('type', 'dm') // Exclude DM notifications from the screen
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<AppNotification> notifications = [];
      for (final item in response) {
        final notificationMap = Map<String, dynamic>.from(item);
        final profile = notificationMap[SupabaseConfig.profilesTable];
        if (profile != null) {
          notificationMap['actor_name'] = profile['username'];
          notificationMap['actor_avatar'] = profile['avatar_url'];
        }
        notifications.add(AppNotification.fromJson(notificationMap));
      }

      return notifications;
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from(SupabaseConfig.notificationsTable)
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from(SupabaseConfig.notificationsTable)
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Clear all notifications for a user
  Future<void> clearAllNotifications(String userId) async {
    try {
      await _supabase
          .from(SupabaseConfig.notificationsTable)
          .delete()
          .eq('user_id', userId)
          .neq(
            'type',
            'dm',
          ); // Don't delete DM notifications as they are handled differently
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
      rethrow;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.notificationsTable)
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .neq('type', 'dm'); // Only count non-DM notifications

      return response.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from(SupabaseConfig.notificationsTable)
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Subscribe to new notifications
  RealtimeChannel subscribeToNotifications({
    required String userId,
    required Function(AppNotification) onNewNotification,
  }) {
    final channel = _supabase.channel('notifications:$userId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.notificationsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            try {
              final notificationData = Map<String, dynamic>.from(
                payload.newRecord,
              );

              // Fetch actor details for the display name/avatar
              if (notificationData['actor_id'] != null) {
                try {
                  final profile = await _supabase
                      .from(SupabaseConfig.profilesTable)
                      .select('username, avatar_url')
                      .eq('id', notificationData['actor_id'])
                      .maybeSingle();

                  if (profile != null) {
                    notificationData['actor_name'] = profile['username'];
                    notificationData['actor_avatar'] = profile['avatar_url'];
                  }
                } catch (e) {
                  debugPrint(
                    'Could not fetch actor profile for notification: $e',
                  );
                }
              }

              final notification = AppNotification.fromJson(notificationData);
              onNewNotification(notification);
            } catch (e) {
              debugPrint('Error processing new notification: $e');
            }
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              '[NotificationService] Subscription error for user $userId: $error',
            );
          } else {
            debugPrint(
              '[NotificationService] Subscription status for user $userId: $status',
            );
          }
        });

    return channel;
  }

  /// Unsubscribe from notifications
  Future<void> unsubscribeFromNotifications(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  /// Create a notification (for testing or manual creation)
  Future<void> createNotification({
    required String userId,
    required String type,
    required String actorId,
    String? title,
    String? postId,
    String? commentId,
    String? messageId,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Note: 'title' column does not exist in DB, so we don't include it in insert.
      // We will derive the title in the UI/Model from the actor_id/actor_name.
      await _supabase.from(SupabaseConfig.notificationsTable).insert({
        'user_id': userId,
        'type': type,
        'actor_id': actorId,
        'post_id': postId,
        'comment_id': commentId,
        'message_id': messageId,
        'content': message,
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
      // Don't rethrow - notification failures should not crash the caller
    }
  }

  /// Send a "Pulse" notification to all members of a canvas (except the actor)
  Future<void> sendPulseNotification({
    required String canvasId,
    required String canvasTitle,
    required String actorId,
    required List<String> memberIds,
  }) async {
    try {
      final List<Map<String, dynamic>> notifications = [];

      for (final memberId in memberIds) {
        if (memberId == actorId) continue;

        notifications.add({
          'user_id': memberId,
          'type': 'canvas_pulse',
          'actor_id': actorId,
          'content': 'is looking at your "$canvasTitle" Canvas right now.',
        });
      }

      if (notifications.isNotEmpty) {
        await _supabase
            .from(SupabaseConfig.notificationsTable)
            .insert(notifications);
      }
    } catch (e) {
      debugPrint('Error sending pulse notification: $e');
    }
  }

  /// Update FCM token for the user
  Future<void> updateFcmToken(String userId) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _supabase
            .from(SupabaseConfig.profilesTable)
            .update({'fcm_token': fcmToken})
            .eq('id', userId);
        debugPrint('FCM Token updated for user: $userId');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Remove FCM token for the user (on logout)
  Future<void> removeFcmToken(String userId) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        // Only remove if it matches current token, to avoid removing a token from another device
        // if they logged in elsewhere.
        final profile = await _supabase
            .from(SupabaseConfig.profilesTable)
            .select('fcm_token')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null && profile['fcm_token'] == fcmToken) {
          await _supabase
              .from(SupabaseConfig.profilesTable)
              .update({'fcm_token': null})
              .eq('id', userId);
          debugPrint('FCM Token removed for user: $userId');
        }
      }
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }
}
