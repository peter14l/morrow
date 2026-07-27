import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service_stub.dart';

void main() {
  group('PQAuraEncryptedMessage', () {
    test('serializes to base64 JSON correctly', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5]);
      final payload = Uint8List.fromList([6, 7, 8, 9, 10]);
      final msg = PQAuraEncryptedMessage(header: header, payload: payload);

      final json = msg.toJson();

      expect(json['header'], base64Encode(header));
      expect(json['payload'], base64Encode(payload));

      // Test deserialization
      final restored = PQAuraEncryptedMessage.fromJson(json);
      expect(restored.header, equals(header));
      expect(restored.payload, equals(payload));
    });

    test('round-trip with empty data', () {
      final msg = PQAuraEncryptedMessage(
        header: Uint8List(0),
        payload: Uint8List(0),
      );

      final json = msg.toJson();
      expect(json['header'], '');
      expect(json['payload'], '');

      final restored = PQAuraEncryptedMessage.fromJson(json);
      expect(restored.header, isEmpty);
      expect(restored.payload, isEmpty);
    });

    test('round-trip with large data', () {
      final header = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      final payload = Uint8List.fromList(List.generate(5000, (i) => (i * 7) % 256));
      final msg = PQAuraEncryptedMessage(header: header, payload: payload);

      final json = msg.toJson();
      final restored = PQAuraEncryptedMessage.fromJson(json);

      expect(restored.header, equals(header));
      expect(restored.payload, equals(payload));
    });
  });

  group('PQAuraService (via conditional export - uses stub in VM)', () {
    test('service starts uninitialized', () {
      final service = PQAuraService.instance;
      expect(service.isReady, false);
    });

    test('clearAllData resets state', () async {
      final service = PQAuraService.instance;
      await service.clearAllData();
      expect(service.isReady, false);
      expect(service.hasSession('any-user'), false);
    });

    test('getOrCreateSession returns false (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.getOrCreateSession('user123');
      expect(result, false);
    });

    test('loadSession returns false (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.loadSession('user123');
      expect(result, false);
    });

    test('encryptMessage returns null (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.encryptMessage('user123', 'hello');
      expect(result, null);
    });

    test('decryptMessage returns null (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.decryptMessage(
        'user123',
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5, 6]),
      );
      expect(result, null);
    });

    test('encryptMediaKey returns null (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.encryptMediaKey(
        'user123',
        Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
      );
      expect(result, null);
    });

    test('decryptMediaKey returns null (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.decryptMediaKey('user123', {
        'protocol': 'pq_aura',
        'pq_header': base64Encode([1, 2, 3]),
        'pq_payload': base64Encode([4, 5, 6]),
      });
      expect(result, null);
    });

    test('encryptGroupMessage returns null (stub implementation)', () async {
      final service = PQAuraService.instance;
      final result = await service.encryptGroupMessage(['user1', 'user2'], 'hello');
      expect(result, null);
    });
  });

  group('PQAuraServiceStub direct tests', () {
    test('all methods return false/null', () {
      final stub = PQAuraServiceStub();
      expect(stub.isReady, false);
      expect(stub.hasSession('user'), false);
      
      // Test async methods
      expect(stub.init(), completion(false));
      expect(stub.getOrCreateSession('user'), completion(false));
      expect(stub.loadSession('user'), completion(false));
      expect(stub.encryptMessage('user', 'msg'), completion(null));
      expect(stub.decryptMessage('user', Uint8List(0), Uint8List(0)), completion(null));
      expect(stub.encryptMediaKey('user', Uint8List(0)), completion(null));
      expect(stub.decryptMediaKey('user', {}), completion(null));
      expect(stub.encryptGroupMessage(['user'], 'msg'), completion(null));
      
      // Test clearAllData
      stub.clearAllData();
    });
  });
}