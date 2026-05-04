import 'dart:async';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/notifications/domain/models/notification_entity.dart';

class NotificationRemoteDatasource {
  final _supabase = SupabaseService().client;

  Future<List<AppNotification>> getNotifications({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
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
        .neq('type', 'dm')
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
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from(SupabaseConfig.notificationsTable)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false)
        .neq('type', 'dm');

    return response.length;
  }

  Future<void> deleteAllNotifications(String userId) async {
    await _supabase
        .from(SupabaseConfig.notificationsTable)
        .delete()
        .eq('user_id', userId);
  }
}
