import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'signal_store.dart';

class SignalService {
  static final SignalService _instance = SignalService._internal();
  factory SignalService() => _instance;
  SignalService._internal();

  SupabaseClient get _supabase => SupabaseService().client;
  final Map<String, PersistentSignalStore> _stores = {};
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;

  /// Get the store for a specific user ID, or the current user if not provided.
  PersistentSignalStore? _getStore(String? userId) {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    return _stores[uid];
  }

  /// Initialize the Signal Service for a specific user.
  /// Generates keys and uploads to Supabase if not done yet.
  Future<bool> init({String? userId}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return false;

    if (_stores.containsKey(uid)) {
      // Check for keys presence
      final hasCorrectKeys = await PersistentSignalStore.hasKeys(userId: uid);
      if (!hasCorrectKeys) {
        debugPrint('[Signal] Keys missing for $uid. Resetting...');
        _stores.remove(uid);
      } else {
        if (userId == null) _isInitialized = true;
        return true;
      }
    }

    if (_isInitializing) {
      // Wait for the active initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _stores.containsKey(uid);
    }

    _isInitializing = true;
    try {
      // 1. Initialize persistent store
      final hasLocalKeys = await PersistentSignalStore.hasKeys(userId: uid);

      PersistentSignalStore store;
      if (!hasLocalKeys) {
        debugPrint(
          '[Signal] Local keys missing for $uid, attempting restoration...',
        );
        final backup = await EncryptionService().restoreSignalIdentity();
        if (backup != null) {
          debugPrint(
            '[Signal] Restoration data found for $uid, saving locally...',
          );
          final identityKeyPair = IdentityKeyPair.fromSerialized(
            base64Decode(backup['identityKeyPair'] as String),
          );
          final registrationId = backup['registrationId'] as int;

          store = await PersistentSignalStore.saveAndInit(
            identityKeyPair,
            registrationId,
            userId: uid,
          );
          debugPrint('[Signal] Restoration complete for $uid.');
        } else {
          debugPrint(
            '[Signal] No backup found for $uid, will generate new keys.',
          );
          store = await _initStoreForUser(uid);
        }
      } else {
        store = await _initStoreForUser(uid);
      }

      _stores[uid] = store;

      // 2. Verify identity alignment with server (Only for active user to avoid unnecessary network calls)
      if (uid == _supabase.auth.currentUser?.id) {
        await _verifyIdentityWithServer(uid, store);
        _isInitialized = true;
      }

      _isInitializing = false;
      return true;
    } catch (e) {
      debugPrint('[Signal] Initialization error for $uid: $e');
      _isInitializing = false;
      return false;
    }
  }

  Future<PersistentSignalStore> _initStoreForUser(String userId) async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);

    return await PersistentSignalStore.saveAndInit(
      identityKeyPair,
      registrationId,
      userId: userId,
    );
  }

  Future<void> _verifyIdentityWithServer(
    String userId,
    PersistentSignalStore store,
  ) async {
    final identityKeyPair = await store.getIdentityKeyPair();
    final localIdentityKeyBase64 = base64Encode(
      identityKeyPair.getPublicKey().serialize(),
    );

    final response = await _supabase
        .from('signal_keys')
        .select('user_id, identity_key')
        .eq('user_id', userId)
        .maybeSingle();

    final serverIdentityKey = response?['identity_key'] as String?;
    final isIdentityMismatch =
        serverIdentityKey != null &&
        serverIdentityKey != localIdentityKeyBase64;

    if (isIdentityMismatch) {
      debugPrint('[Signal] Server identity mismatch for $userId. Updating...');
      await _generateAndUploadBundle(userId);
    }
  }

  /// Wipe all local Signal state for a specific user
  Future<void> clearData({String? userId}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final store = _stores[uid];
      if (store != null) {
        await store.clearAll();
        _stores.remove(uid);
      }
      if (uid == _supabase.auth.currentUser?.id) {
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('[Signal] Error clearing data for $uid: $e');
    }
  }

  /// Generate SignedPreKey and OneTimePreKeys and upload bundle
  Future<void> _generateAndUploadBundle(String userId) async {
    final store = _getStore(userId);
    if (store == null) return;

    final identityKeyPair = await store.getIdentityKeyPair();
    final registrationId = await store.getLocalRegistrationId();

    // Generate Signed PreKey (id: 1)
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
    await store.storeSignedPreKey(1, signedPreKey);

    // Generate One-Time PreKeys (id: 1 to 100)
    final preKeys = generatePreKeys(1, 100);
    final preKeysMap = <String, String>{};
    for (final pk in preKeys) {
      await store.storePreKey(pk.id, pk);
      preKeysMap[pk.id.toString()] = base64Encode(
        pk.getKeyPair().publicKey.serialize(),
      );
    }

    final signedPreKeyMap = {
      'keyId': signedPreKey.id,
      'publicKey': base64Encode(
        signedPreKey.getKeyPair().publicKey.serialize(),
      ),
      'signature': base64Encode(signedPreKey.signature),
    };

    // 1. Upload the public bundle to Supabase
    await _supabase.from('signal_keys').upsert({
      'user_id': userId,
      'identity_key': base64Encode(identityKeyPair.getPublicKey().serialize()),
      'registration_id': registrationId,
      'signed_prekey': signedPreKeyMap,
      'onetime_prekeys': preKeysMap,
    });

    // 2. Backup the private identity key pair securely
    debugPrint('[Signal] Backing up identity keys to server...');
    await EncryptionService().backupSignalIdentity(
      base64Encode(identityKeyPair.serialize()),
      registrationId,
    );
  }

  /// Ensure we have an active session with [remoteUserId].
  Future<void> _ensureSession(
    String remoteUserId, {
    String? localUserId,
    int deviceId = 1,
  }) async {
    final store = _getStore(localUserId);
    if (store == null) {
      throw Exception('No store found for local user $localUserId');
    }

    final address = SignalProtocolAddress(remoteUserId, deviceId);

    if (await store.containsSession(address)) {
      return; // Session already exists
    }

    // Fetch bundle from Supabase
    final response = await _supabase
        .from('signal_keys')
        .select()
        .eq('user_id', remoteUserId)
        .maybeSingle();

    if (response == null) {
      throw Exception('Remote user has not registered Signal keys yet.');
    }

    final identityKeyString = response['identity_key'] as String;
    final registrationId = response['registration_id'] as int;
    final signedPreKeyJson = response['signed_prekey'] as Map<String, dynamic>;
    final onetimePrekeys = response['onetime_prekeys'] as Map<String, dynamic>;

    if (onetimePrekeys.isEmpty) {
      throw Exception('Remote user has no one-time prekeys left.');
    }

    // Pick the first available onetime prekey
    final firstKeyIdString = onetimePrekeys.keys.first;
    final preKeyId = int.parse(firstKeyIdString);
    final preKeyString = onetimePrekeys[firstKeyIdString] as String;

    // Parse the keys
    final identityKey = IdentityKey.fromBytes(
      base64Decode(identityKeyString),
      0,
    );
    final signedPreKeyPubBytes = base64Decode(signedPreKeyJson['publicKey']!);
    final signedPreKeySignatureBytes = base64Decode(
      signedPreKeyJson['signature']!,
    );
    final preKeyPubBytes = base64Decode(preKeyString);

    final preKeyBundle = PreKeyBundle(
      registrationId,
      deviceId,
      preKeyId,
      Curve.decodePoint(preKeyPubBytes, 0),
      signedPreKeyJson['keyId'] as int,
      Curve.decodePoint(signedPreKeyPubBytes, 0),
      signedPreKeySignatureBytes,
      identityKey,
    );

    await store.saveIdentity(address, null);
    await store.saveIdentity(address, identityKey);

    // Build Session
    final sessionBuilder = SessionBuilder(store, store, store, store, address);
    await sessionBuilder.processPreKeyBundle(preKeyBundle);

    // Remove the used one-time prekey
    onetimePrekeys.remove(firstKeyIdString);
    await _supabase
        .from('signal_keys')
        .update({'onetime_prekeys': onetimePrekeys})
        .eq('user_id', remoteUserId);
  }

  /// Force a refresh of a remote user's bundle and rebuild the session.
  Future<void> forceRefreshBundle(
    String remoteUserId, {
    String? localUserId,
  }) async {
    debugPrint('[Signal] Force-refreshing bundle for $remoteUserId...');
    final store = _getStore(localUserId);
    if (store == null) return;
    final address = SignalProtocolAddress(remoteUserId, 1);
    await store.deleteSession(address);
    await _ensureSession(remoteUserId, localUserId: localUserId);
  }

  /// Encrypt a string message for a specific user
  Future<CiphertextMessage> encryptMessage(
    String recipientId,
    String plaintext, {
    String? localUserId,
    int deviceId = 1,
  }) async {
    final uid = localUserId ?? _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('No user ID for encryption');

    if (!_stores.containsKey(uid)) {
      final success = await init(userId: uid);
      if (!success) throw Exception('SignalService init failed for $uid');
    }

    final store = _stores[uid]!;
    await _ensureSession(recipientId, localUserId: uid, deviceId: deviceId);

    final address = SignalProtocolAddress(recipientId, deviceId);
    final sessionCipher = SessionCipher(store, store, store, store, address);

    try {
      return await sessionCipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
    } catch (e) {
      await store.deleteSession(address);
      await _ensureSession(recipientId, localUserId: uid, deviceId: deviceId);

      final retryCipher = SessionCipher(store, store, store, store, address);
      return await retryCipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
    }
  }

  // Track recent recovery attempts
  final Map<String, DateTime> _lastRecoveryAttempt = {};

  /// Decrypt an incoming message.
  Future<String> decryptMessage(
    String senderId,
    String base64Ciphertext,
    int type, {
    String? localUserId,
    int deviceId = 1,
    bool isHistorical = false,
  }) async {
    final uid = localUserId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return '🔒 Message encrypted (No user session)';

    if (!_stores.containsKey(uid)) {
      final success = await init(userId: uid);
      if (!success) return '🔒 Message encrypted (Initialization error)';
    }

    final store = _stores[uid]!;
    final address = SignalProtocolAddress(senderId, deviceId);
    final sessionCipher = SessionCipher(store, store, store, store, address);
    final ciphertextBytes = base64Decode(base64Ciphertext);

    try {
      Uint8List plaintextBytes;
      if (type == CiphertextMessage.prekeyType) {
        final preKeyMessage = PreKeySignalMessage(ciphertextBytes);
        plaintextBytes = await sessionCipher.decrypt(preKeyMessage);
      } else if (type == CiphertextMessage.whisperType) {
        final message = SignalMessage.fromSerialized(ciphertextBytes);
        plaintextBytes = await sessionCipher.decryptFromSignal(message);
      } else {
        return '🔒 Message encrypted';
      }
      return utf8.decode(plaintextBytes);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Bad Mac')) {
        if (isHistorical) return '🔒 Message encrypted (Historical)';

        final now = DateTime.now();
        final lastAttempt = _lastRecoveryAttempt[senderId];
        if (lastAttempt == null || now.difference(lastAttempt).inMinutes > 5) {
          _lastRecoveryAttempt[senderId] = now;
          forceRefreshBundle(senderId, localUserId: uid)
              .then((_) async {
                try {
                  await encryptMessage(
                    senderId,
                    'PROTOCOL_SYNC',
                    localUserId: uid,
                  );
                } catch (_) {}
              })
              .catchError((_) {});
        }
        return '🔒 Optimizing secure connection...';
      } else if (errorStr.contains('No valid sessions') ||
          errorStr.contains('InvalidMessageException')) {
        await store.deleteSession(address);
        return '🔒 Session expired';
      }
      return '🔒 Message encrypted';
    }
  }
}
