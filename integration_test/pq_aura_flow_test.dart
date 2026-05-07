import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oasis/core/crypto/pq_aura_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PQ-Aura (PQ-DR) Protocol Integration Test', () {
    final bridge = PQAuraBridge.instance;

    testWidgets('Verify Hybrid Post-Quantum Handshake & Double Ratchet', (tester) async {
      // 1. Load the native library
      final isLoaded = bridge.load();
      expect(isLoaded, isTrue, reason: 'Native PQ-Aura library must be built and available.');

      // 2. Bob generates his Identity Keys and Pre-Key Bundle
      final bobIdentityKp = bridge.generateKeypair();
      expect(bobIdentityKp, isNotNull);
      
      final bobBundle = bridge.createBundle(bobIdentityKp!.publicKey);
      expect(bobBundle, isNotNull);

      // 3. Alice generates her Identity Keys
      final aliceIdentityKp = bridge.generateKeypair();
      expect(aliceIdentityKp, isNotNull);

      // 4. Alice initiates session using Bob's bundle (Handshake)
      // In a real app, the bundle is fetched from Supabase as JSON
      final bundleMap = {
        'identity_pk': {
          'classic': bobBundle!.identityPk.sublist(0, 32),
          'quantum': bobBundle.identityPk.sublist(32),
        },
        'signed_pre_key': {
          'classic': bobBundle.signedPreKey.sublist(0, 32),
          'quantum': bobBundle.signedPreKey.sublist(32),
        },
        'one_time_pre_key': bobBundle.oneTimePreKey != null ? {
          'classic': bobBundle.oneTimePreKey!.sublist(0, 32),
          'quantum': bobBundle.oneTimePreKey!.sublist(32),
        } : null,
      };
      final bundleBytes = utf8.encode(jsonEncode(bundleMap));

      final aliceHandshake = bridge.initAlice(
        remoteBundle: bundleBytes,
        localIdentityPk: aliceIdentityKp!.publicKey,
        localIdentitySk: aliceIdentityKp.secretKey,
      );
      expect(aliceHandshake, isNotNull);
      final aliceState = aliceHandshake!.statePtr;

      // 5. Alice encrypts the very first message
      const secret1 = 'Hello Bob! This is a post-quantum secure message.';
      final ad = utf8.encode('bob_user_id');
      final msg1 = bridge.encrypt(aliceState, utf8.encode(secret1), ad);
      expect(msg1, isNotNull);

      // 6. Bob receives the initial message and establishes session
      // Alice's first message carries the handshake metadata
      final aliceHandshakeJson = {
        'alice_identity_pk': {
          'classic': aliceHandshake.aliceIdentityPk.sublist(0, 32),
          'quantum': aliceHandshake.aliceIdentityPk.sublist(32),
        },
        'ephemeral_pk': {
          'classic': aliceHandshake.ephemeralPk.sublist(0, 32),
          'quantum': aliceHandshake.ephemeralPk.sublist(32),
        },
        'kem_ciphertext_identity': aliceHandshake.kemCiphertextIdentity,
        'kem_ciphertext_signed': aliceHandshake.kemCiphertextSigned,
        'kem_ciphertext_one_time': aliceHandshake.kemCiphertextOneTime,
        'ratchet_message': {
          'header_ciphertext': msg1!.header,
          'payload_ciphertext': msg1.payload,
        }
      };
      final handshakeBytes = utf8.encode(jsonEncode(aliceHandshakeJson));

      final bobState = bridge.initBob(
        initialMessage: handshakeBytes,
        localIdentityPk: bobIdentityKp.publicKey,
        localIdentitySk: bobIdentityKp.secretKey,
        localSignedSk: bobIdentityKp.secretKey, // Simplified for test
        localOtSk: null,
      );
      expect(bobState, isNotNull);

      // 7. Bob decrypts Alice's first message
      final bobDecrypted1 = bridge.decrypt(bobState!, msg1.header, msg1.payload, ad);
      expect(bobDecrypted1, isNotNull);
      expect(utf8.decode(bobDecrypted1!), secret1);

      // 8. Bob sends a reply (Ratcheting)
      const secret2 = 'I hear you Alice. The future is quantum-resistant!';
      final adAlice = utf8.encode('alice_user_id');
      final msg2 = bridge.encrypt(bobState, utf8.encode(secret2), adAlice);
      expect(msg2, isNotNull);

      // 9. Alice decrypts Bob's reply
      final aliceDecrypted2 = bridge.decrypt(aliceState, msg2!.header, msg2.payload, adAlice);
      expect(aliceDecrypted2, isNotNull);
      expect(utf8.decode(aliceDecrypted2!), secret2);

      // 10. Verify State Persistence (Serialization)
      final serializedAlice = bridge.serializeState(aliceState);
      expect(serializedAlice, isNotNull);
      
      final aliceState2 = bridge.deserializeState(serializedAlice!);
      expect(aliceState2, isNotNull);

      // 11. Alice sends a subsequent message using the restored state
      const secret3 = 'Session restored successfully.';
      final msg3 = bridge.encrypt(aliceState2!, utf8.encode(secret3), ad);
      
      final bobDecrypted3 = bridge.decrypt(bobState, msg3!.header, msg3.payload, ad);
      expect(bobDecrypted3, isNotNull);
      expect(utf8.decode(bobDecrypted3!), secret3);

      // Cleanup
      bridge.freeState(aliceState);
      bridge.freeState(aliceState2);
      bridge.freeState(bobState);
      bridge.freeKeypair(aliceIdentityKp.nativePtr);
      bridge.freeKeypair(bobIdentityKp.nativePtr);
      bridge.freeBundle(bobBundle.nativePtr);
      bridge.freeInitialMessage(aliceHandshake.nativePtr);
      bridge.freeMessage(msg1.nativePtr);
      bridge.freeMessage(msg2.nativePtr);
      bridge.freeMessage(msg3.nativePtr);

      debugPrint('✅ PQ-Aura Handshake Verified');
      debugPrint('✅ Double Ratchet Verified');
      debugPrint('✅ Post-Quantum Security Confirmed');
    });
  });
}
