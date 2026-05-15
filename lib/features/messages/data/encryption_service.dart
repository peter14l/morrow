import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/storage/secure_storage.dart';
import 'package:oasis/services/key_management_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

export 'package:oasis/services/key_management_service.dart'
    show EncryptionStatus;

/// Isolated cryptographic task parameters.
class _EncryptTask {
  final String content;
  final List<String> recipientPublicKeysPem;
  final String? myPublicKey;
  final String userId;

  _EncryptTask(
    this.content,
    this.recipientPublicKeysPem,
    this.myPublicKey,
    this.userId,
  );
}

class _DecryptTask {
  final String encryptedContentBase64;
  final Map<String, dynamic> encryptedKeys;
  final String ivBase64;
  final String? targetUserId;
  final Map<String, String> cachedAllKeys;
  final String? primaryKey;

  _DecryptTask({
    required this.encryptedContentBase64,
    required this.encryptedKeys,
    required this.ivBase64,
    this.targetUserId,
    required this.cachedAllKeys,
    this.primaryKey,
  });
}

class _MediaEncryptTask {
  final List<int> bytes;
  final List<String> recipientPublicKeysPem;
  final String? myPublicKey;

  _MediaEncryptTask(this.bytes, this.recipientPublicKeysPem, this.myPublicKey);
}

class _MediaDecryptTask {
  final List<int> encryptedBytes;
  final String ivBase64;
  final Map<String, dynamic> encryptedKeys;
  final Map<String, String> cachedAllKeys;
  final String? primaryKey;

  _MediaDecryptTask({
    required this.encryptedBytes,
    required this.ivBase64,
    required this.encryptedKeys,
    required this.cachedAllKeys,
    this.primaryKey,
  });
}

/// Provider for cryptographic operations.
///
/// Handles RSA/AES and PQ-Aura encryption and decryption for messages and media.
/// Orchestrates the initialization and restoration of encryption keys
/// via [KeyManagementService].
///
/// 🚀 PERFORMANCE UPGRADE: Heavy cryptographic operations are offloaded to
/// background isolates to ensure zero UI jank during bulk message processing.
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final KeyManagementService _keyManager = KeyManagementService();
  final SecureStorage _secureStorage = SecureStorage();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool get isInitialized => _isInitialized;

  EncryptionStatus? _lastStatus;

  // Cache for private keys to prevent massive lag during bulk decryption
  String? _cachedPrimaryKey;
  Map<String, String>? _cachedAllKeys;

  /// Initializes the encryption system.
  Future<EncryptionStatus> init() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return EncryptionStatus.error;

    if (_isInitialized &&
        _lastStatus != EncryptionStatus.needsSecurityUpgrade) {
      return _lastStatus ?? EncryptionStatus.ready;
    }

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _lastStatus ??
          (_isInitialized
              ? EncryptionStatus.ready
              : EncryptionStatus.needsSetup);
    }

    _isInitializing = true;
    try {
      // 1. Migration of legacy ghost keys
      final legacyPrivate = await _secureStorage.read(key: 'rsa_private_key');
      final legacyPublic = await _secureStorage.read(key: 'rsa_public_key');

      if (legacyPrivate != null && legacyPublic != null) {
        debugPrint('[Encryption] Migrating legacy keys for $userId...');
        await _secureStorage.write(
          key: KeyManagementService.privateKeyKey(userId),
          value: legacyPrivate,
        );
        await _secureStorage.write(
          key: KeyManagementService.publicKeyKey(userId),
          value: legacyPublic,
        );

        final backupKey = _keyManager.deriveLegacyBackupKey(userId);
        final encryptedPrivateKey = _keyManager.encryptWithKey(
          legacyPrivate,
          backupKey,
        );
        await _supabase
            .from('profiles')
            .update({
              'public_key': legacyPublic,
              'encrypted_private_key': encryptedPrivateKey,
            })
            .eq('id', userId);

        await _secureStorage.delete(key: 'rsa_private_key');
        await _secureStorage.delete(key: 'rsa_public_key');

        _isInitialized = true;
        _isInitializing = false;
        _lastStatus = EncryptionStatus.ready;
        return EncryptionStatus.ready;
      }

      // 2. Check local prefixed keys & Server Status for Upgrade
      final privateKeyPem = await _secureStorage.read(
        key: KeyManagementService.privateKeyKey(userId),
      );
      final publicKeyPem = await _secureStorage.read(
        key: KeyManagementService.publicKeyKey(userId),
      );

      final response = await _supabase
          .from('profiles')
          .select(
            'encrypted_private_key, encrypted_private_key_v2, encrypted_private_key_recovery, key_salt, public_key, has_upgraded_security',
          )
          .eq('id', userId)
          .maybeSingle();

      if (privateKeyPem != null && publicKeyPem != null) {
        try {
          CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
          _cachedPrimaryKey = privateKeyPem;

          if (response != null) {
            if (response['has_upgraded_security'] != true &&
                response['encrypted_private_key'] != null) {
              _isInitialized = true;
              _isInitializing = false;
              _lastStatus = EncryptionStatus.needsSecurityUpgrade;
              return EncryptionStatus.needsSecurityUpgrade;
            }

            if (response['has_upgraded_security'] == true &&
                response['encrypted_private_key_recovery'] == null) {
              _isInitialized = true;
              _isInitializing = false;
              _lastStatus = EncryptionStatus.needsRecoveryBackup;
              return EncryptionStatus.needsRecoveryBackup;
            }
          }

          _isInitialized = true;
          _isInitializing = false;
          _lastStatus = EncryptionStatus.ready;
          return EncryptionStatus.ready;
        } catch (e) {
          debugPrint('[Encryption] Local key corruption detected.');
        }
      }

      if (response != null) {
        if (response['encrypted_private_key_v2'] != null) {
          _isInitializing = false;
          _lastStatus = EncryptionStatus.needsRestore;
          return EncryptionStatus.needsRestore;
        }

        if (response['encrypted_private_key'] != null) {
          debugPrint(
            '[Encryption] Legacy v1 backup detected. Blocking auto-restore for security.',
          );
          _isInitializing = false;
          _lastStatus = EncryptionStatus.needsSetup;
          return EncryptionStatus.needsSetup;
        }
      }

      _isInitializing = false;
      _lastStatus = EncryptionStatus.needsSetup;
      return EncryptionStatus.needsSetup;
    } catch (e) {
      _isInitializing = false;
      _lastStatus = EncryptionStatus.error;
      debugPrint('[Encryption] Init Error: $e');
      return EncryptionStatus.error;
    }
  }

  /// Restores keys from the server backup using PIN-derived decryption (v2).
  Future<bool> restoreSecureKeys(String pin) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('encrypted_private_key_v2, key_salt, public_key')
          .eq('id', userId)
          .single();

      final encryptedPrivateKey =
          response['encrypted_private_key_v2'] as String?;
      final salt = response['key_salt'] as String?;
      final publicKeyPem = response['public_key'] as String?;

      if (encryptedPrivateKey == null || salt == null || publicKeyPem == null) {
        return false;
      }

      final secureKey = _keyManager.deriveSecureBackupKey(pin, salt);
      final privateKeyPem = _keyManager.decryptWithKey(
        encryptedPrivateKey,
        secureKey,
      );
      if (privateKeyPem == null) return false;

      await _secureStorage.write(
        key: KeyManagementService.privateKeyKey(userId),
        value: privateKeyPem,
      );
      await _secureStorage.write(
        key: KeyManagementService.publicKeyKey(userId),
        value: publicKeyPem,
      );

      _cachedPrimaryKey = privateKeyPem;
      _isInitialized = true;
      _lastStatus = EncryptionStatus.ready;
      return true;
    } catch (e) {
      debugPrint('[Encryption] Secure Restore Error: $e');
      return false;
    }
  }

  /// Restores keys using a recovery key.
  Future<bool> restoreWithRecoveryKey(String recoveryKey) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('encrypted_private_key_recovery, key_salt, public_key')
          .eq('id', userId)
          .single();

      final encryptedPrivateKey =
          response['encrypted_private_key_recovery'] as String?;
      final salt = response['key_salt'] as String?;
      final publicKeyPem = response['public_key'] as String?;

      if (encryptedPrivateKey == null || salt == null || publicKeyPem == null) {
        return false;
      }

      final recoveryDerivedKey = _keyManager.deriveRecoveryKey(
        recoveryKey,
        salt,
      );
      final privateKeyPem = _keyManager.decryptWithKey(
        encryptedPrivateKey,
        recoveryDerivedKey,
      );

      if (privateKeyPem == null) return false;

      await _secureStorage.write(
        key: KeyManagementService.privateKeyKey(userId),
        value: privateKeyPem,
      );
      await _secureStorage.write(
        key: KeyManagementService.publicKeyKey(userId),
        value: publicKeyPem,
      );

      _cachedPrimaryKey = privateKeyPem;
      _isInitialized = true;
      _lastStatus = EncryptionStatus.ready;
      return true;
    } catch (e) {
      debugPrint('[Encryption] Recovery Restore Error: $e');
      return false;
    }
  }

  /// Upgrades a user from v1 (legacy) to v2 (PIN-based) security.
  Future<({bool success, String? recoveryKey})> upgradeSecurity(
    String pin,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return (success: false, recoveryKey: null);

      final privateKeyPem = await _secureStorage.read(
        key: KeyManagementService.privateKeyKey(userId),
      );
      if (privateKeyPem == null) return (success: false, recoveryKey: null);

      final salt = _keyManager.generateSalt();
      final recoveryKey = _keyManager.generateRecoveryKey();

      final secureKey = _keyManager.deriveSecureBackupKey(pin, salt);
      final recoveryDerivedKey = _keyManager.deriveRecoveryKey(
        recoveryKey,
        salt,
      );

      final encryptedPrivateKeyV2 = _keyManager.encryptWithKey(
        privateKeyPem,
        secureKey,
      );
      final encryptedPrivateKeyRecovery = _keyManager.encryptWithKey(
        privateKeyPem,
        recoveryDerivedKey,
      );

      await _supabase
          .from('profiles')
          .update({
            'encrypted_private_key_v2': encryptedPrivateKeyV2,
            'encrypted_private_key_recovery': encryptedPrivateKeyRecovery,
            'key_salt': salt,
            'has_upgraded_security': true,
            'encrypted_private_key': null,
          })
          .eq('id', userId);

      _lastStatus = EncryptionStatus.ready;
      return (success: true, recoveryKey: recoveryKey);
    } catch (e) {
      debugPrint('[Encryption] Security Upgrade Error: $e');
      return (success: false, recoveryKey: null);
    }
  }

  /// Sets up a new encryption identity (RSA keys) and backs them up to the server.
  Future<({bool success, String? recoveryKey})> setupEncryption({
    String? pin,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return (success: false, recoveryKey: null);

      const keySize = kIsWeb ? 1024 : 2048;
      final keyPair = await _keyManager.generateKeyPair(keySize);

      final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(
        keyPair.privateKey as dynamic,
      );
      final publicKeyPem = CryptoUtils.encodeRSAPublicKeyToPem(
        keyPair.publicKey as dynamic,
      );

      String? recoveryKey;

      if (pin != null) {
        final salt = _keyManager.generateSalt();
        recoveryKey = _keyManager.generateRecoveryKey();

        final secureKey = _keyManager.deriveSecureBackupKey(pin, salt);
        final recoveryDerivedKey = _keyManager.deriveRecoveryKey(
          recoveryKey,
          salt,
        );

        final encryptedPrivateKeyV2 = _keyManager.encryptWithKey(
          privateKeyPem,
          secureKey,
        );
        final encryptedPrivateKeyRecovery = _keyManager.encryptWithKey(
          privateKeyPem,
          recoveryDerivedKey,
        );

        await _supabase
            .from('profiles')
            .update({
              'public_key': publicKeyPem,
              'encrypted_private_key_v2': encryptedPrivateKeyV2,
              'encrypted_private_key_recovery': encryptedPrivateKeyRecovery,
              'key_salt': salt,
              'has_upgraded_security': true,
            })
            .eq('id', userId);
      } else {
        final backupKey = _keyManager.deriveLegacyBackupKey(userId);
        final encryptedPrivateKey = _keyManager.encryptWithKey(
          privateKeyPem,
          backupKey,
        );

        await _supabase
            .from('profiles')
            .update({
              'public_key': publicKeyPem,
              'encrypted_private_key': encryptedPrivateKey,
            })
            .eq('id', userId);
      }

      await _secureStorage.write(
        key: KeyManagementService.privateKeyKey(userId),
        value: privateKeyPem,
      );
      await _secureStorage.write(
        key: KeyManagementService.publicKeyKey(userId),
        value: publicKeyPem,
      );

      _cachedPrimaryKey = privateKeyPem;
      _isInitialized = true;
      _lastStatus = EncryptionStatus.ready;
      return (success: true, recoveryKey: recoveryKey);
    } catch (e) {
      debugPrint('[Encryption] Setup Error: $e');
      return (success: false, recoveryKey: null);
    }
  }

  // --- Cryptographic Operations (Isolated) ---

  /// Encrypts a message using RSA/AES.
  /// Runs in a background isolate via [compute].
  Future<EncryptedMessage> encryptMessage(
    String content,
    List<String> recipientPublicKeysPem, {
    encrypt.Key? reuseKey,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || !_isInitialized) {
      throw Exception('Encryption not ready');
    }

    final myPublicKey = await _secureStorage.read(
      key: KeyManagementService.publicKeyKey(userId),
    );

    // If reuseKey is provided, we can't easily pass it to compute without serializing it.
    // However, most calls don't reuse keys. For isolation, we prioritize fresh encryption.
    final result = await compute(
      _isolateEncrypt,
      _EncryptTask(content, recipientPublicKeysPem, myPublicKey, userId),
    );

    return EncryptedMessage(
      encryptedContent: result['content'] as String,
      iv: result['iv'] as String,
      encryptedKeys: Map<String, String>.from(result['keys'] as Map),
    );
  }

  /// Decrypts a message using RSA/AES.
  /// Runs in a background isolate via [compute].
  Future<String?> decryptMessage(
    String encryptedContentBase64,
    Map<String, dynamic> encryptedKeys,
    String ivBase64, {
    String? userId,
  }) async {
    if (encryptedContentBase64.isEmpty) return '';

    final currentUserId = userId ?? _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    if (userId == null && !_isInitialized) await init();

    if (_cachedAllKeys == null) {
      _cachedAllKeys = await _secureStorage.readAll();
    }

    return await compute(
      _isolateDecrypt,
      _DecryptTask(
        encryptedContentBase64: encryptedContentBase64,
        encryptedKeys: encryptedKeys,
        ivBase64: ivBase64,
        targetUserId: currentUserId,
        cachedAllKeys: _cachedAllKeys ?? {},
        primaryKey: _cachedPrimaryKey,
      ),
    );
  }

  /// Encrypts a media file for E2EE storage.
  /// Runs in a background isolate via [compute].
  Future<Map<String, dynamic>> encryptMediaFile({
    required File file,
    required List<String> recipientPublicKeysPem,
    List<String>? recipientUserIds,
    String? recipientUserId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || !_isInitialized) {
      throw Exception('Encryption not ready');
    }

    final bytes = await file.readAsBytes();
    final myPublicKey = await _secureStorage.read(
      key: KeyManagementService.publicKeyKey(userId),
    );

    final rsaResult = await compute(
      _isolateMediaEncrypt,
      _MediaEncryptTask(bytes.toList(), recipientPublicKeysPem, myPublicKey),
    );

    final aesKeyBytes = rsaResult['aesKey'] as Uint8List;
    final encryptedKeys = Map<String, String>.from(rsaResult['keys'] as Map);

    // 2. PQ-Aura (Primary/Advanced Security) - Synchronous as it's already isolated in PQAuraService
    final ids =
        recipientUserIds ?? (recipientUserId != null ? [recipientUserId] : []);

    if (ids.isNotEmpty && PQAuraService.instance.isReady) {
      try {
        Map<String, String>? pqaResult;
        if (ids.length == 1) {
          pqaResult = await PQAuraService.instance.encryptMediaKey(
            ids.first,
            aesKeyBytes,
          );
        } else {
          pqaResult = await PQAuraService.instance.encryptGroupMediaKey(
            ids,
            aesKeyBytes,
          );
        }
        if (pqaResult != null) encryptedKeys.addAll(pqaResult);
      } catch (e) {
        debugPrint(
          '[EncryptionService] PQ-Aura media key encryption failed: $e',
        );
      }
    }

    return {
      'encryptedBytes': rsaResult['bytes'],
      'iv': rsaResult['iv'],
      'encryptedKeys': encryptedKeys,
    };
  }

  /// Decrypts media bytes using the provided encryption metadata.
  Future<Uint8List?> decryptMediaFile({
    required Uint8List encryptedBytes,
    required String ivBase64,
    required Map<String, dynamic> encryptedKeys,
    String? senderId,
  }) async {
    try {
      // 1. Try PQ-Aura first (Isolate-friendly via PQAuraService internally)
      if (senderId != null &&
          encryptedKeys['protocol'] == 'pq_aura' &&
          PQAuraService.instance.isReady) {
        final decryptedKey = await PQAuraService.instance.decryptMediaKey(
          senderId,
          encryptedKeys,
        );
        if (decryptedKey != null) {
          return await compute(_isolateMediaDecryptWithKey, {
            'bytes': encryptedBytes,
            'iv': ivBase64,
            'key': decryptedKey,
          });
        }
      }

      // 2. Fallback to RSA
      if (_cachedAllKeys == null)
        _cachedAllKeys = await _secureStorage.readAll();

      return await compute(
        _isolateMediaDecrypt,
        _MediaDecryptTask(
          encryptedBytes: encryptedBytes.toList(),
          ivBase64: ivBase64,
          encryptedKeys: encryptedKeys,
          cachedAllKeys: _cachedAllKeys ?? {},
          primaryKey: _cachedPrimaryKey,
        ),
      );
    } catch (e) {
      debugPrint('[Encryption] Media Decrypt Error: $e');
      return null;
    }
  }

  // --- Static Isolate Workers ---

  static Map<String, dynamic> _isolateEncrypt(_EncryptTask task) {
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encryptedContent = encrypter.encrypt(task.content, iv: iv);

    final encryptedKeys = <String, String>{};
    final allKeys = {...task.recipientPublicKeysPem};
    if (task.myPublicKey != null) allKeys.add(task.myPublicKey!);

    for (final pubKeyPem in allKeys) {
      try {
        final rsaEncrypter = encrypt.Encrypter(
          encrypt.RSA(publicKey: CryptoUtils.rsaPublicKeyFromPem(pubKeyPem)),
        );
        final encryptedKey = rsaEncrypter.encrypt(base64.encode(aesKey.bytes));
        encryptedKeys[_hashPublicKey(pubKeyPem)] = encryptedKey.base64;
      } catch (_) {}
    }

    return {
      'content': encryptedContent.base64,
      'iv': iv.base64,
      'keys': encryptedKeys,
    };
  }

  static String? _isolateDecrypt(_DecryptTask task) {
    encrypt.Key? key;

    // Try primary key first
    if (task.primaryKey != null) {
      key = _tryDecryptWithPrivateKey(task.primaryKey!, task.encryptedKeys);
    }

    // Fallback to all cached keys
    if (key == null) {
      for (final entry in task.cachedAllKeys.entries) {
        if (entry.key.startsWith('rsa_private_key_')) {
          key = _tryDecryptWithPrivateKey(entry.value, task.encryptedKeys);
          if (key != null) break;
        }
      }
    }

    if (key == null) return null;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(task.encryptedContentBase64),
        iv: encrypt.IV.fromBase64(task.ivBase64),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _isolateMediaEncrypt(_MediaEncryptTask task) {
    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encrypted = encrypter.encryptBytes(task.bytes, iv: iv);

    final encryptedKeys = <String, String>{};
    final allKeys = {...task.recipientPublicKeysPem};
    if (task.myPublicKey != null) allKeys.add(task.myPublicKey!);

    for (final pubKeyPem in allKeys) {
      try {
        final rsaEncrypter = encrypt.Encrypter(
          encrypt.RSA(publicKey: CryptoUtils.rsaPublicKeyFromPem(pubKeyPem)),
        );
        final encryptedKey = rsaEncrypter.encrypt(base64.encode(aesKey.bytes));
        encryptedKeys[_hashPublicKey(pubKeyPem)] = encryptedKey.base64;
      } catch (_) {}
    }

    return {
      'bytes': Uint8List.fromList(encrypted.bytes),
      'iv': iv.base64,
      'keys': encryptedKeys,
      'aesKey': aesKey.bytes,
    };
  }

  static Uint8List? _isolateMediaDecrypt(_MediaDecryptTask task) {
    encrypt.Key? key;
    if (task.primaryKey != null) {
      key = _tryDecryptWithPrivateKey(task.primaryKey!, task.encryptedKeys);
    }
    if (key == null) {
      for (final entry in task.cachedAllKeys.entries) {
        if (entry.key.startsWith('rsa_private_key_')) {
          key = _tryDecryptWithPrivateKey(entry.value, task.encryptedKeys);
          if (key != null) break;
        }
      }
    }
    if (key == null) return null;

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(task.encryptedBytes)),
      iv: encrypt.IV.fromBase64(task.ivBase64),
    );
    return Uint8List.fromList(decrypted);
  }

  static Uint8List _isolateMediaDecryptWithKey(Map<String, dynamic> data) {
    final key = encrypt.Key(data['key'] as Uint8List);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(data['bytes'] as Uint8List),
      iv: encrypt.IV.fromBase64(data['iv'] as String),
    );
    return Uint8List.fromList(decrypted);
  }

  static encrypt.Key? _tryDecryptWithPrivateKey(
    String privateKeyPem,
    Map<String, dynamic> encryptedKeys,
  ) {
    try {
      final rsaEncrypter = encrypt.Encrypter(
        encrypt.RSA(
          privateKey: CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem),
        ),
      );
      for (final entry in encryptedKeys.entries) {
        try {
          return encrypt.Key(
            base64.decode(
              rsaEncrypter.decrypt(
                encrypt.Encrypted.fromBase64(entry.value as String),
              ),
            ),
          );
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  static String _hashPublicKey(String pem) {
    return sha256.convert(utf8.encode(pem)).toString();
  }

  /// Generates a brand new identity, replacing any existing backup.
  /// Used for manual "reset" when restore is impossible.
  Future<bool> generateNewKeys() async {
    final result = await setupEncryption();
    return result.success;
  }

  /// Wrapper for [setupEncryption] for PIN-based key generation.
  Future<({bool success, String? recoveryKey})> generateNewKeysWithPin(
    String pin,
  ) async {
    return await setupEncryption(pin: pin);
  }

  /// Attempts to restore keys automatically (legacy).
  Future<bool> restoreKeys() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from('profiles')
        .select('encrypted_private_key, public_key')
        .eq('id', userId)
        .maybeSingle();

    if (response == null || response['encrypted_private_key'] == null) {
      return false;
    }

    final backupKey = _keyManager.deriveLegacyBackupKey(userId);
    final privateKeyPem = _keyManager.decryptWithKey(
      response['encrypted_private_key'],
      backupKey,
    );

    if (privateKeyPem == null) return false;

    await _secureStorage.write(
      key: KeyManagementService.privateKeyKey(userId),
      value: privateKeyPem,
    );
    await _secureStorage.write(
      key: KeyManagementService.publicKeyKey(userId),
      value: response['public_key'],
    );

    _cachedPrimaryKey = privateKeyPem;
    _isInitialized = true;
    _lastStatus = EncryptionStatus.ready;
    return true;
  }

  /// Backs up the Signal identity key pair securely.
  Future<bool> backupSignalIdentity(
    String identityKeyPairBase64,
    int registrationId,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    if (_cachedPrimaryKey == null) {
      final pk = await _secureStorage.read(
        key: KeyManagementService.privateKeyKey(userId),
      );
      if (pk == null) return false;
      _cachedPrimaryKey = pk;
    }

    final aesKey = encrypt.Key.fromSecureRandom(32);
    final iv = encrypt.IV.fromSecureRandom(16);

    final data = jsonEncode({
      'identityKeyPair': identityKeyPairBase64,
      'registrationId': registrationId,
    });

    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
    final encryptedData = encrypter.encrypt(data, iv: iv);

    final pubKeyPem = await _secureStorage.read(
      key: KeyManagementService.publicKeyKey(userId),
    );
    if (pubKeyPem == null) return false;

    final rsaEncrypter = encrypt.Encrypter(
      encrypt.RSA(publicKey: CryptoUtils.rsaPublicKeyFromPem(pubKeyPem)),
    );
    final encryptedKey = rsaEncrypter.encrypt(base64.encode(aesKey.bytes));

    await _supabase
        .from('profiles')
        .update({
          'encrypted_signal_identity': jsonEncode({
            'data': encryptedData.base64,
            'iv': iv.base64,
            'key': encryptedKey.base64,
          }),
        })
        .eq('id', userId);

    return true;
  }

  /// Restores the Signal identity from the server.
  Future<Map<String, dynamic>?> restoreSignalIdentity() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('profiles')
        .select('encrypted_signal_identity')
        .eq('id', userId)
        .maybeSingle();

    if (response == null || response['encrypted_signal_identity'] == null) {
      return null;
    }

    if (_cachedPrimaryKey == null) {
      final pk = await _secureStorage.read(
        key: KeyManagementService.privateKeyKey(userId),
      );
      if (pk == null) return null;
      _cachedPrimaryKey = pk;
    }

    try {
      final backup =
          jsonDecode(response['encrypted_signal_identity'])
              as Map<String, dynamic>;

      final rsaEncrypter = encrypt.Encrypter(
        encrypt.RSA(
          privateKey: CryptoUtils.rsaPrivateKeyFromPem(_cachedPrimaryKey!),
        ),
      );
      final decryptedKeyBase64 = rsaEncrypter.decrypt(
        encrypt.Encrypted.fromBase64(backup['key']),
      );
      final aesKey = encrypt.Key(base64.decode(decryptedKeyBase64));

      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
      final decryptedData = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(backup['data']),
        iv: encrypt.IV.fromBase64(backup['iv']),
      );

      return jsonDecode(decryptedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[Encryption] Signal identity restore failed: $e');
      return null;
    }
  }

  /// Clears local keys (Logout/Reset).
  Future<void> clearKeys() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _secureStorage.delete(
        key: KeyManagementService.privateKeyKey(userId),
      );
      await _secureStorage.delete(
        key: KeyManagementService.publicKeyKey(userId),
      );
    }
    reset();
  }

  // --- Helpers & Cleanup ---

  void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _lastStatus = null;
    _cachedPrimaryKey = null;
    _cachedAllKeys = null;
    debugPrint('[EncryptionService] State reset.');
  }
}

class EncryptedMessage {
  final String encryptedContent;
  final String iv;
  final Map<String, String> encryptedKeys;
  EncryptedMessage({
    required this.encryptedContent,
    required this.iv,
    required this.encryptedKeys,
  });
}
