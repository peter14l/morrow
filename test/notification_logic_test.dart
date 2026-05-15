import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oasis/models/notification.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockNotificationService extends Mock implements NotificationService {
  @override
  RealtimeChannel subscribeToNotifications({
    required String userId,
    required Function(AppNotification) onNewNotification,
  }) {
    // Return a dummy channel or handle manually in tests
    return MockRealtimeChannel();
  }
}

class MockRealtimeChannel extends Mock implements RealtimeChannel {}

void main() {
  group('Notification Logic Tests', () {
    test('AppNotification displayTitle should handle DM type correctly', () {
      final notification = AppNotification(
        id: '1',
        userId: 'user1',
        type: 'dm',
        actorName: 'John Doe',
        message: 'Hello there!',
        timestamp: DateTime.now(),
      );

      expect(notification.displayTitle, 'John Doe');
      expect(notification.getNotificationText(), 'Hello there!');
    });

    test(
      'AppNotification displayTitle should handle System type correctly',
      () {
        final notification = AppNotification(
          id: '2',
          userId: 'user1',
          type: 'like',
          actorName: 'Jane Smith',
          timestamp: DateTime.now(),
        );

        expect(notification.displayTitle, 'New Like');
        expect(
          notification.getNotificationText(),
          'Jane Smith liked your post',
        );
      },
    );

    test(
      'AppNotification displayTitle should handle Custom title correctly',
      () {
        final notification = AppNotification(
          id: '3',
          userId: 'user1',
          type: 'system',
          title: 'Security Alert',
          message: 'New login detected',
          timestamp: DateTime.now(),
        );

        expect(notification.displayTitle, 'Security Alert');
        expect(notification.getNotificationText(), 'New login detected');
      },
    );
  });
}
