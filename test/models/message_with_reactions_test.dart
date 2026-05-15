import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/messages/domain/models/message.dart';

void main() {
  group('Message parsing with reactions', () {
    test('Message.fromJson should correctly parse reactions if present', () {
      final json = {
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'content': 'Hello',
        'created_at': '2026-03-16T12:00:00Z',
        'reactions': [
          {
            'id': 'r1',
            'message_id': 'm1',
            'user_id': 'u2',
            'username': 'user2',
            'reaction': '👍',
            'created_at': '2026-03-16T12:01:00Z',
          },
        ],
      };

      final message = Message.fromJson(json);

      expect(message.reactions.length, 1);
      expect(message.reactions.first.reaction, '👍');
      expect(message.reactions.first.username, 'user2');
    });

    test(
      'Message.fromJson should return empty list if reactions is missing',
      () {
        final json = {
          'id': 'm1',
          'conversation_id': 'c1',
          'sender_id': 'u1',
          'content': 'Hello',
          'created_at': '2026-03-16T12:00:00Z',
        };

        final message = Message.fromJson(json);

        expect(message.reactions, isEmpty);
      },
    );
  });
}
