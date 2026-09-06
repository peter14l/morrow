import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';

void main() {
  group('Media Attachment Encryption & Decryption Metadata Verification', () {
    test('ChatMediaService.parseMediaUrl properly extracts type and userId/fileId', () {
      const url = 'https://pub-367b2ec139244405b5e1c1ab74e78467.r2.dev/images/user-abc-123/1725619200000_uuid-456.jpg';
      final parsed = ChatMediaService.parseMediaUrl(url);

      expect(parsed, isNotNull);
      expect(parsed!.type, equals('images'));
      expect(parsed.fileId, equals('user-abc-123/1725619200000_uuid-456.jpg'));
    });

    test('ChatMediaService.parseMediaUrl returns null for invalid or non-HTTP URLs', () {
      expect(ChatMediaService.parseMediaUrl('/local/path/to/file.png'), isNull);
      expect(ChatMediaService.parseMediaUrl('https://example.com/'), isNull);
      expect(ChatMediaService.parseMediaUrl(''), isNull);
    });

    test('Message model correctly normalizes media_url and message_type for image attachments', () {
      final json = {
        'id': 'msg-img-001',
        'conversation_id': 'conv-001',
        'sender_id': 'user-a',
        'created_at': DateTime.now().toIso8601String(),
        'image_url': 'https://pub-367b2ec139244405b5e1c1ab74e78467.r2.dev/images/user-a/pic.jpg',
        'content': '',
        'share_data': {
          'media_iv': 'iv-base64-xyz',
          'media_keys': {'user-b': 'encrypted-aes-key-for-b'},
        },
      };

      final message = Message.fromJson(json);

      expect(message.messageType, equals(MessageType.image));
      expect(message.mediaUrl, equals('https://pub-367b2ec139244405b5e1c1ab74e78467.r2.dev/images/user-a/pic.jpg'));
      expect(message.shareData?['media_iv'], equals('iv-base64-xyz'));
      expect(message.shareData?['media_keys'], isA<Map>());
      expect((message.shareData?['media_keys'] as Map)['user-b'], equals('encrypted-aes-key-for-b'));
    });

    test('Resolves media encryption keys from share_data with fallback to top-level encrypted_keys', () {
      // Case 1: Standard v1.1.22+ format with share_data
      final msgWithShareData = Message(
        id: 'msg-001',
        conversationId: 'conv-001',
        senderId: 'user-a',
        timestamp: DateTime.now(),
        mediaUrl: 'https://example.com/images/user-a/photo.jpg',
        messageType: MessageType.image,
        shareData: {
          'media_iv': 'share-iv-123',
          'media_keys': {'user-b': 'share-key-b'},
        },
      );

      final keys1 = msgWithShareData.shareData?['media_keys'] as Map<String, dynamic>? ??
          (msgWithShareData.encryptedKeys != null
              ? Map<String, dynamic>.from(msgWithShareData.encryptedKeys!)
              : null);
      final iv1 = msgWithShareData.shareData?['media_iv'] as String? ?? msgWithShareData.iv;

      expect(keys1?['user-b'], equals('share-key-b'));
      expect(iv1, equals('share-iv-123'));

      // Case 2: Legacy fallback format with top-level encrypted_keys/iv
      final msgWithLegacyKeys = Message(
        id: 'msg-002',
        conversationId: 'conv-001',
        senderId: 'user-a',
        timestamp: DateTime.now(),
        mediaUrl: 'https://example.com/images/user-a/photo.jpg',
        messageType: MessageType.image,
        encryptedKeys: {'user-b': 'legacy-key-b'},
        iv: 'legacy-iv-123',
      );

      final keys2 = msgWithLegacyKeys.shareData?['media_keys'] as Map<String, dynamic>? ??
          (msgWithLegacyKeys.encryptedKeys != null
              ? Map<String, dynamic>.from(msgWithLegacyKeys.encryptedKeys!)
              : null);
      final iv2 = msgWithLegacyKeys.shareData?['media_iv'] as String? ?? msgWithLegacyKeys.iv;

      expect(keys2?['user-b'], equals('legacy-key-b'));
      expect(iv2, equals('legacy-iv-123'));
    });
  });
}
