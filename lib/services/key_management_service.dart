import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

enum EncryptionStatus {
  ready,
  needsSetup,
  needsRestore,
  needsSecurityUpgrade,
  needsRecoveryBackup, // PIN set but no recovery key backup
  error,
}

/// Service for managing the lifecycle of cryptographic keys.
///
/// Handles derivation of backup keys from user IDs, generation of RSA key pairs,
/// hashing of public keys for identification, and AES encryption/decryption
/// of private keys for secure server-side storage (auto-restore).
class KeyManagementService {
  /// Returns the secure storage key for a user's private RSA key.
  static String privateKeyKey(String uid) => 'rsa_private_key_$uid';

  /// Returns the secure storage key for a user's public RSA key.
  static String publicKeyKey(String uid) => 'rsa_public_key_$uid';

  /// Derives a 32-byte key from the User ID for legacy seamless backup encryption.
  /// 🚩 CRITICAL VULNERABILITY: This method is deprecated and should NOT be used for new users.
  /// It is kept ONLY for one-time migration to PIN-based (v2) security.
  @Deprecated(
    'Vulnerable to userId harvesting. Use deriveSecureBackupKey instead.',
  )
  encrypt.Key deriveLegacyBackupKey(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  /// Generates a random 32-byte salt and returns it as a Base64 string.
  String generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      salt[i] = random.nextInt(256);
    }
    return base64.encode(salt);
  }

  /// Derives a secure 32-byte AES key from a 6-digit PIN and a Salt using Argon2id.
  encrypt.Key deriveSecureBackupKey(String pin, String saltBase64) {
    final derived = deriveSecureBackupKeyIsolate(Argon2DeriveParams(pin, saltBase64));
    return encrypt.Key(derived);
  }

  Future<encrypt.Key> deriveSecureBackupKeyAsync(String pin, String saltBase64) async {
    if (kIsWeb) {
      // Isolates/Web Workers spawned by compute() can fail or have issues on certain Web configurations
      return deriveSecureBackupKey(pin, saltBase64);
    }
    final derived = await compute(
      deriveSecureBackupKeyIsolate,
      Argon2DeriveParams(pin, saltBase64),
    );
    return encrypt.Key(derived);
  }

  /// Generates a random 24-character recovery key grouped by dashes.
  String generateRecoveryKey() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude ambiguous 0, O, 1, I
    final random = Random.secure();
    final buffer = StringBuffer();

    for (int i = 0; i < 24; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(chars[random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }

  /// Derives a 32-byte AES key from a recovery key using Argon2id.
  encrypt.Key deriveRecoveryKey(String recoveryKey, String saltBase64) {
    // Normalize: remove dashes and spaces, uppercase
    final normalized = recoveryKey
        .replaceAll(RegExp(r'[\s-]'), '')
        .toUpperCase();

    // Reuse the secure derivation logic but with the recovery key as the "pin"
    return deriveSecureBackupKey(normalized, saltBase64);
  }

  /// Normalizes and hashes a public key for consistent identification.
  String hashPublicKey(String publicKeyPem) {
    final normalized = publicKeyPem
        .replaceAll(RegExp(r'-----(BEGIN|END)[\w\s]+-----'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return sha256.convert(utf8.encode(normalized)).toString().substring(0, 16);
  }

  /// Encrypts data with a specific key (used for backups).
  String encryptWithKey(String data, encrypt.Key key) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(data, iv: iv);

    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);

    return base64.encode(combined);
  }

  /// Decrypts data with a specific key (used for restores).
  String? decryptWithKey(String encryptedDataBase64, encrypt.Key key) {
    try {
      final combined = base64.decode(encryptedDataBase64);
      if (combined.length < 16) return null;

      final iv = encrypt.IV(combined.sublist(0, 16));
      final encryptedBytes = combined.sublist(16);
      final encrypted = encrypt.Encrypted(encryptedBytes);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('[KeyManager] Decryption failed: $e');
      return null;
    }
  }

  /// Generates a new RSA key pair.
  Future<AsymmetricKeyPair> generateKeyPair(int keySize) async {
    return await compute(_generateKeyPairInternal, keySize);
  }
}

AsymmetricKeyPair _generateKeyPairInternal(int keySize) {
  return CryptoUtils.generateRSAKeyPair(keySize: keySize);
}

/// Parameters for Argon2 key derivation in background isolates.
class Argon2DeriveParams {
  final String pin;
  final String saltBase64;

  Argon2DeriveParams(this.pin, this.saltBase64);
}

/// Background isolate top-level function for Argon2 key derivation.
Uint8List deriveSecureBackupKeyIsolate(Argon2DeriveParams params) {
  final salt = base64.decode(params.saltBase64);
  final pinBytes = utf8.encode(params.pin);

  final parameters = Argon2Parameters(
    Argon2Parameters.ARGON2_id,
    salt,
    version: Argon2Parameters.ARGON2_VERSION_13,
    iterations: 2,
    memoryPowerOf2: 12, // 4MB key derivation is fast on web and secure on native
    lanes: 1,
    desiredKeyLength: 32,
  );

  final argon2 = Argon2BytesGenerator();
  argon2.init(parameters);

  final derivedKey = argon2.process(Uint8List.fromList(pinBytes));
  return derivedKey.sublist(0, 32);
}

