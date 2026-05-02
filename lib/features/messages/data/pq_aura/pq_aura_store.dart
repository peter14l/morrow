import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:oasis/core/crypto/pq_aura_bridge.dart';

/// Persistent storage for PQ-Aura session states.
/// Uses flutter_secure_storage for encrypted local storage.
class PQAuraStore {
  static PQAuraStore? _instance;
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _identityKeyPairKey = 'pq_aura_identity_keypair';
  static const String _signedPreKeyKey = 'pq_aura_signed_prekey';
  static const String _oneTimePreKeysKey = 'pq_aura_onetime_prekeys';
  static const String _sessionsKeyPrefix = 'pq_aura_session_';

  PQAuraStore._() : _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static PQAuraStore get instance {
    _instance ??= PQAuraStore._();
    return _instance!;
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
  // Session State Management
  // ============================================================================

  /// Check if we have a session with a specific user
  Future<bool> hasSession(String remoteUserId) async {
    final session = await _secureStorage.read(key: '$_sessionsKeyPrefix$remoteUserId');
    return session != null;
  }

  /// Save session state for a conversation
  Future<void> saveSession(String remoteUserId, Uint8List serializedState) async {
    await _secureStorage.write(
      key: '$_sessionsKeyPrefix$remoteUserId',
      value: base64Encode(serializedState),
    );
  }

  /// Load session state for a conversation
  Future<Uint8List?> loadSession(String remoteUserId) async {
    final stored = await _secureStorage.read(key: '$_sessionsKeyPrefix$remoteUserId');
    if (stored == null) return null;
    return base64Decode(stored);
  }

  /// Delete session state
  Future<void> deleteSession(String remoteUserId) async {
    await _secureStorage.delete(key: '$_sessionsKeyPrefix$remoteUserId');
  }

  /// Get all session user IDs
  Future<List<String>> getAllSessionUserIds() async {
    final all = await _secureStorage.readAll();
    return all.keys
        .where((key) => key.startsWith(_sessionsKeyPrefix))
        .map((key) => key.substring(_sessionsKeyPrefix.length))
        .toList();
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
          key.startsWith(_sessionsKeyPrefix)) {
        await _secureStorage.delete(key: key);
      }
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