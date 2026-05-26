import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/services/notification_decryption_service.dart';
import 'package:oasis/features/notifications/domain/models/notification_entity.dart';


void main() {
  late NotificationDecryptionService decryptionService;
  // Note: Since NotificationDecryptionService is a singleton and creates its own services,
  // we might need to adjust it to allow injection for testing, or use a more complex mocking setup.
  // For this test, we'll focus on the logic that doesn't strictly depend on service initialization
  // OR we can try to initialize a minimal mock environment.

  setUp(() {
    decryptionService = NotificationDecryptionService();
  });

  group('NotificationDecryptionService Logic Tests', () {
    test(
      'decryptMessage should return content as is if not encrypted',
      () async {
        final data = {'body': 'Hello world'};
        final result = await decryptionService.decryptMessage(data);
        expect(result, 'Hello world');
      },
    );

    test(
      'decryptMessage should return placeholder if content looks like ciphertext and metadata is missing',
      () async {
        // Long string without spaces (likely ciphertext)
        const ciphertext =
            'SGVsbG8gd29ybGQgdGhpcyBpcyBhIHZlcnkgbG9uZyBlbmNyeXB0ZWQgbWVzc2FnZSB0aGF0IHNob3VsZCBiZSBkZXRlY3RlZA==';
        final data = {'body': ciphertext};
        final result = await decryptionService.decryptMessage(data);
        expect(result, '🔒 Encrypted message');
      },
    );

    test(
      'decryptMessage should return placeholder if content is short but looks like base64 and metadata is missing',
      () async {
        // Short base64 string
        const ciphertext = 'SGVsbG8gd29ybGQ=';
        final data = {'body': ciphertext};
        final result = await decryptionService.decryptMessage(data);
        expect(result, '🔒 Encrypted message');
      },
    );

    test(
      'decryptMessage should return content if it contains spaces even if it has no metadata',
      () async {
        final data = {'body': 'This is a normal message with spaces'};
        final result = await decryptionService.decryptMessage(data);
        expect(result, 'This is a normal message with spaces');
      },
    );

    test(
      'decryptNotification should work with AppNotification entity',
      () async {
        final notification = AppNotification(
          id: '1',
          userId: 'user1',
          type: 'dm',
          actorId: 'sender1',
          message: 'Normal message',
          timestamp: DateTime.now(),
        );

        final result = await decryptionService.decryptNotification(
          notification,
        );
        expect(result, 'Normal message');
      },
    );

    test(
      'decryptNotification should return placeholder for encrypted notification without metadata',
      () async {
        final notification = AppNotification(
          id: '1',
          userId: 'user1',
          type: 'dm',
          actorId: 'sender1',
          message:
              'SGVsbG8gd29ybGQgdGhpcyBpcyBhIHZlcnkgbG9uZyBlbmNyeXB0ZWQgbWVzc2FnZQ==',
          timestamp: DateTime.now(),
        );

        final result = await decryptionService.decryptNotification(
          notification,
        );
        expect(result, '🔒 Encrypted message');
      },
    );
  });
}
