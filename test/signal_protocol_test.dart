import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

void main() {
  group('Signal Protocol E2EE Flow', () {
    test('Simulate Alice to Bob encrypted message exchange', () async {
      // 1. Setup Alice and Bob stores
      final aliceStore = InMemorySignalProtocolStore(
        generateIdentityKeyPair(),
        11111,
      );
      final bobStore = InMemorySignalProtocolStore(
        generateIdentityKeyPair(),
        22222,
      );

      // 2. Bob generates keys for his bundle
      final bobIdentityKeyPair = await bobStore.getIdentityKeyPair();
      final bobRegistrationId = await bobStore.getLocalRegistrationId();

      final bobSignedPreKey = generateSignedPreKey(bobIdentityKeyPair, 1);
      await bobStore.storeSignedPreKey(1, bobSignedPreKey);

      final bobPreKeys = generatePreKeys(1, 1);
      await bobStore.storePreKey(1, bobPreKeys[0]);

      // 3. Bob publishes his bundle (simulate uploading to server)
      final bobBundle = PreKeyBundle(
        bobRegistrationId,
        1, // deviceId
        1, // preKeyId
        bobPreKeys[0].getKeyPair().publicKey,
        1, // signedPreKeyId
        bobSignedPreKey.getKeyPair().publicKey,
        bobSignedPreKey.signature,
        bobIdentityKeyPair.getPublicKey(),
      );

      // 4. Alice fetches Bob's bundle and builds a session
      const bobAddress = SignalProtocolAddress('bob', 1);
      final sessionBuilder = SessionBuilder(
        aliceStore,
        aliceStore,
        aliceStore,
        aliceStore,
        bobAddress,
      );

      // Process Bob's prekey bundle
      await sessionBuilder.processPreKeyBundle(bobBundle);

      // 5. Alice encrypts a message for Bob
      final sessionCipherAlice = SessionCipher(
        aliceStore,
        aliceStore,
        aliceStore,
        aliceStore,
        bobAddress,
      );
      const plaintext = 'Hello Bob, this is a secret message!';
      final ciphertextMessage = await sessionCipherAlice.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );

      // Verify it's a PreKeySignalMessage since it's the first message
      expect(ciphertextMessage.getType(), CiphertextMessage.prekeyType);

      // 6. Bob receives the message and decrypts it
      const aliceAddress = SignalProtocolAddress('alice', 1);
      final sessionCipherBob = SessionCipher(
        bobStore,
        bobStore,
        bobStore,
        bobStore,
        aliceAddress,
      );

      // Bob decodes it as a PreKeySignalMessage
      final preKeySignalMessage = PreKeySignalMessage(
        ciphertextMessage.serialize(),
      );
      final decryptedBytes = await sessionCipherBob.decrypt(
        preKeySignalMessage,
      );

      final decryptedText = utf8.decode(decryptedBytes);
      expect(decryptedText, plaintext);

      // 7. Bob replies to Alice
      const bobReply = 'Hello Alice, message received!';
      final bobCiphertext = await sessionCipherBob.encrypt(
        Uint8List.fromList(utf8.encode(bobReply)),
      );

      // It should now be a regular SignalMessage because the session is established
      expect(bobCiphertext.getType(), CiphertextMessage.whisperType);

      // 8. Alice decrypts Bob's reply
      final signalMessage = SignalMessage.fromSerialized(
        bobCiphertext.serialize(),
      );
      final aliceDecryptedBytes = await sessionCipherAlice.decryptFromSignal(
        signalMessage,
      );

      final aliceDecryptedText = utf8.decode(aliceDecryptedBytes);
      expect(aliceDecryptedText, bobReply);
    });
  });
}
