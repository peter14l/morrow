import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/services/notification_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationManager Sender Avatar Tests', () {
    late NotificationManager notificationManager;

    setUp(() {
      notificationManager = NotificationManager.instance;
    });

    test('showNotification accepts senderAvatar parameter', () async {
      // This is a smoke test to ensure the API works without crashing
      // Actual native notification display cannot be tested in pure unit tests
      await notificationManager.initialize();

      expect(
        () => notificationManager.showNotification(
          title: 'Test',
          body: 'Body',
          senderAvatar: 'https://example.com/avatar.png',
        ),
        returnsNormally,
      );
    });
  });
}
