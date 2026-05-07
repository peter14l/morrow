import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oasis/core/crypto/pq_aura_bridge.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Persistent storage for PQ-Aura session states.
/// Uses flutter_secure_storage for keys and file-system for atomic session states.
class PQAuraStore {
  static PQAuraStore? _instance;
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _identityKeyPairKey = 'pq_aura_identity_keypair';
  static const String _signedPreKeyKey = 'pq_aura_signed_prekey';
  static const String _stateEncryptionKey = 'pq_aura_state_encryption_key';
  static const String _sessionsKeyPrefix = 'pq_aura_session_';

  PQAuraStore._() : _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      groupId: 'group.com.oasis.app',
    ),
  );

  static PQAuraStore get instance {
    _instance ??= PQAuraStore._();
    return _instance!;
  }

  // ============================================================================
  // Encryption Key Management
  // ============================================================================

  /// Get or create the dedicated key for encrypting session states on disk
  Future<Uint8List> _getStateEncryptionKey() async {
    final stored = await _secureStorage.read(key: _stateEncryptionKey);
    if (stored != null) {
      return base64Decode(stored);
    }

    // Generate a fresh 32-byte key
    final random = Random.secure();
    final key = Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    await _secureStorage.write(key: _stateEncryptionKey, value: base64Encode(key));
    return key;
  }

  // ============================================================================
  // Identity Key Management
  // ============================================================================

  /// Check if we have local identity keys
  Future<bool> hasIdentityKeys() async {
    final keys = await _secureStorage.read(key: _identityKeyPairKey);
    return keys != null;
  }

  /// Generate and store new identity keys
  Future<PQAuraKeyPair?> generateAndStoreIdentityKeys() async {
    final bridge = PQAuraBridge.instance;
    if (!bridge.load()) {
      debugPrint('[PQAuraStore] Failed to load PQ-Aura bridge');
      return null;
    }

    final keyPair = bridge.generateKeypair();
    if (keyPair == null) {
      debugPrint('[PQAuraStore] Failed to generate keypair');
      return null;
    }

    // Store the keys as base64
    await _secureStorage.write(
      key: _identityKeyPairKey,
      value: base64Encode(Uint8List.fromList(keyPair.publicKey)) +
          ':' +
          base64Encode(Uint8List.fromList(keyPair.secretKey)),
    );

    return keyPair;
  }

  /// Get stored identity keys
  Future<PQAuraKeyPairData?> getIdentityKeys() async {
    final stored = await _secureStorage.read(key: _identityKeyPairKey);
    if (stored == null) return null;

    final parts = stored.split(':');
    if (parts.length != 2) return null;

    return PQAuraKeyPairData(
      publicKey: base64Decode(parts[0]),
      secretKey: base64Decode(parts[1]),
    );
  }

  /// Store identity keys
  Future<void> storeIdentityKeys(Uint8List publicKey, Uint8List secretKey) async {
    await _secureStorage.write(
      key: _identityKeyPairKey,
      value: base64Encode(publicKey) + ':' + base64Encode(secretKey),
    );
  }

  /// Delete identity keys
  Future<void> deleteIdentityKeys() async {
    await _secureStorage.delete(key: _identityKeyPairKey);
  }

  // ============================================================================
  // Pre-Key Bundle Management
  // ============================================================================

  /// Create and store a pre-key bundle from identity keys
  Future<PQAuraPreKeyBundleData?> createPreKeyBundle() async {
    final identityKeys = await getIdentityKeys();
    if (identityKeys == null) {
      debugPrint('[PQAuraStore] No identity keys to create bundle');
      return null;
    }

    final bridge = PQAuraBridge.instance;
    if (!bridge.load()) return null;

    final bundle = bridge.createBundle(identityKeys.publicKey);
    if (bundle == null) return null;

    // Store the pre-key bundle
    await _secureStorage.write(
      key: _signedPreKeyKey,
      value: jsonEncode({
        'identity_pk': base64Encode(Uint8List.fromList(bundle.identityPk)),
        'signed_prekey': base64Encode(Uint8List.fromList(bundle.signedPreKey)),
        'one_time_prekey': bundle.oneTimePreKey != null
            ? base64Encode(Uint8List.fromList(bundle.oneTimePreKey!))
            : null,
      }),
    );

    // Don't forget to free the native bundle
    bridge.freeBundle(bundle.nativePtr);

    return PQAuraPreKeyBundleData(
      identityPk: Uint8List.fromList(bundle.identityPk),
      signedPreKey: Uint8List.fromList(bundle.signedPreKey),
      oneTimePreKey: bundle.oneTimePreKey != null
          ? Uint8List.fromList(bundle.oneTimePreKey!)
          : null,
    );
  }

  /// Get stored pre-key bundle
  Future<PQAuraPreKeyBundleData?> getPreKeyBundle() async {
    final stored = await _secureStorage.read(key: _signedPreKeyKey);
    if (stored == null) return null;

    final data = jsonDecode(stored) as Map<String, dynamic>;
    return PQAuraPreKeyBundleData(
      identityPk: base64Decode(data['identity_pk'] as String),
      signedPreKey: base64Decode(data['signed_prekey'] as String),
      oneTimePreKey: data['one_time_prekey'] != null
          ? base64Decode(data['one_time_prekey'] as String)
          : null,
    );
  }

  // ============================================================================
  // Session State Management (Atomic File-Based)
  // ============================================================================

  /// Get the local file path for a session state
  Future<String> _getSessionPath(String remoteUserId) async {
    final dir = await getApplicationSupportDirectory();
    final pqaDir = Directory(p.join(dir.path, 'pqa_sessions'));
    if (!await pqaDir.exists()) {
      await pqaDir.create(recursive: true);
    }
    return p.join(pqaDir.path, 'session_$remoteUserId.pqa');
  }

  /// Check if we have a session with a specific user
  Future<bool> hasSession(String remoteUserId) async {
    final path = await _getSessionPath(remoteUserId);
    return File(path).exists();
  }

  /// Save session state atomically using Rust FFI
  Future<bool> saveSessionAtomic(String remoteUserId, Pointer<RatchetState> state) async {
    final path = await _getSessionPath(remoteUserId);
    final key = await _getStateEncryptionKey();
    
    final success = PQAuraBridge.instance.saveStateAtomic(state, path, key);
    if (!success) {
      debugPrint('[PQAuraStore] FAILED to save session atomically for: $remoteUserId');
    }
    return success;
  }

  /// Load session state atomically using Rust FFI
  Future<Pointer<RatchetState>?> loadSessionAtomic(String remoteUserId) async {
    final path = await _getSessionPath(remoteUserId);
    if (!await File(path).exists()) return null;

    final key = await _getStateEncryptionKey();
    return PQAuraBridge.instance.loadStateAtomic(path, key);
  }

  /// Delete session state file
  Future<void> deleteSession(String remoteUserId) async {
    final path = await _getSessionPath(remoteUserId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    // Also cleanup legacy secure storage if it exists
    await _secureStorage.delete(key: '$_sessionsKeyPrefix$remoteUserId');
  }

  /// Get all session user IDs
  Future<List<String>> getAllSessionUserIds() async {
    final dir = await getApplicationSupportDirectory();
    final pqaDir = Directory(p.join(dir.path, 'pqa_sessions'));
    if (!await pqaDir.exists()) return [];

    final files = await pqaDir.list().toList();
    final userIds = <String>[];
    
    for (final entity in files) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (name.startsWith('session_') && name.endsWith('.pqa')) {
          userIds.add(name.substring(8, name.length - 4));
        }
      }
    }
    
    return userIds;
  }

  // Legacy methods kept for compatibility or internal use during transition
  
  /// Load session state (Legacy)
  Future<Uint8List?> loadSession(String remoteUserId) async {
    final stored = await _secureStorage.read(key: '$_sessionsKeyPrefix$remoteUserId');
    if (stored == null) return null;
    return base64Decode(stored);
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Clear all PQ-Aura data
  Future<void> clearAll() async {
    final keys = await _secureStorage.readAll();
    for (final key in keys.keys) {
      if (key == _identityKeyPairKey ||
          key == _signedPreKeyKey ||
          key == _stateEncryptionKey ||
          key.startsWith(_sessionsKeyPrefix)) {
        await _secureStorage.delete(key: key);
      }
    }

    // Clear session directory
    final dir = await getApplicationSupportDirectory();
    final pqaDir = Directory(p.join(dir.path, 'pqa_sessions'));
    if (await pqaDir.exists()) {
      await pqaDir.delete(recursive: true);
    }
  }
}

/// Data class for identity key pair
class PQAuraKeyPairData {
  final Uint8List publicKey;
  final Uint8List secretKey;

  PQAuraKeyPairData({
    required this.publicKey,
    required this.secretKey,
  });
}

/// Data class for pre-key bundle
class PQAuraPreKeyBundleData {
  final Uint8List identityPk;
  final Uint8List signedPreKey;
  final Uint8List? oneTimePreKey;

  PQAuraPreKeyBundleData({
    required this.identityPk,
    required this.signedPreKey,
    this.oneTimePreKey,
  });
}