import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'signal_store.dart';

class SignalService {
  static final SignalService _instance = SignalService._internal();
  factory SignalService() => _instance;
  SignalService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  late PersistentSignalStore _store;
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the Signal Service.
  /// Generates keys and uploads to Supabase if not done yet.
  Future<bool> init() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    if (_isInitialized) {
      // Check for user affinity (account switch protection)
      final hasCorrectKeys = await PersistentSignalStore.hasKeys();
      if (!hasCorrectKeys) {
        debugPrint('[Signal] User mismatch or keys missing. Resetting...');
        await clearData();
      } else {
        return true;
      }
    }

    if (_isInitializing) {
      // Wait for the active initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _isInitializing = false;
        return false;
      }

      // 1. Initialize persistent store
      // If local keys are missing, try to restore from Supabase backup
      final hasLocalKeys = await PersistentSignalStore.hasKeys();

      if (!hasLocalKeys) {
        debugPrint('[Signal] Local keys missing, attempting restoration...');
        final backup = await EncryptionService().restoreSignalIdentity();
        if (backup != null) {
          debugPrint('[Signal] Restoration data found, saving locally...');
          final identityKeyPair = IdentityKeyPair.fromSerialized(
            base64Decode(backup['identityKeyPair'] as String),
          );
          final registrationId = backup['registrationId'] as int;

          _store = await PersistentSignalStore.saveAndInit(
            identityKeyPair,
            registrationId,
          );
          debugPrint('[Signal] Restoration complete.');
        } else {
          debugPrint(
            '[Signal] No backup found on server, will generate new keys.',
          );
          _store = await PersistentSignalStore.init();
        }
      } else {
        _store = await PersistentSignalStore.init();
      }

      // 2. Verify identity alignment with server
      final identityKeyPair = await _store.getIdentityKeyPair();
      final localIdentityKeyBase64 = base64Encode(
        identityKeyPair.getPublicKey().serialize(),
      );

      final response =
          await _supabase
              .from('signal_keys')
              .select('user_id, identity_key')
              .eq('user_id', userId)
              .maybeSingle();

      final serverIdentityKey = response?['identity_key'] as String?;
      final isIdentityMismatch =
          serverIdentityKey != null &&
          serverIdentityKey != localIdentityKeyBase64;

      // Check if we have local pre-keys
      final hasLocalPreKeys = await _store.hasPreKeys();
      final hasLocalSignedPreKey = await _store.hasSignedPreKeys();

      // Check if private backup exists in profile
      final profile =
          await _supabase
              .from('profiles')
              .select('encrypted_signal_identity')
              .eq('id', userId)
              .maybeSingle();

      if (response == null ||
          !hasLocalPreKeys ||
          !hasLocalSignedPreKey ||
          isIdentityMismatch) {
        // No bundle on server OR missing local keys OR identity changed — refresh bundle
        debugPrint(
          '[Signal] Bundle refresh required (New user, missing keys, or identity change). Generating...',
        );
        await _generateAndUploadBundle(userId);
      } else if (profile == null ||
          profile['encrypted_signal_identity'] == null) {
        // Public bundle exists but private backup is missing — perform backup
        debugPrint(
          '[Signal] Public bundle exists but private backup missing. Triggering backup...',
        );
        final identityKeyPair = await _store.getIdentityKeyPair();
        final registrationId = await _store.getLocalRegistrationId();
        await EncryptionService().backupSignalIdentity(
          base64Encode(identityKeyPair.serialize()),
          registrationId,
        );
      }

      _isInitialized = true;
      _isInitializing = false;
      debugPrint('[Signal] Initialization complete.');
      return true;
    } catch (e) {
      _isInitializing = false;
      debugPrint('[Signal] Initialization error: $e');
      return false;
    }
  }

  /// Wipe all local Signal state
  Future<void> clearData() async {
    try {
      await _store.clearAll();
      _isInitialized = false;
    } catch (e) {
      debugPrint('[Signal] Error clearing data: $e');
    }
  }

  /// Generate SignedPreKey and OneTimePreKeys and upload bundle
  Future<void> _generateAndUploadBundle(String userId) async {
    final identityKeyPair = await _store.getIdentityKeyPair();
    final registrationId = await _store.getLocalRegistrationId();

    // Generate Signed PreKey (id: 1)
    final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
    await _store.storeSignedPreKey(1, signedPreKey);

    // Generate One-Time PreKeys (id: 1 to 100)
    final preKeys = generatePreKeys(1, 100);
    final preKeysMap = <String, String>{};
    for (final pk in preKeys) {
      await _store.storePreKey(pk.id, pk);
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
  /// If not, fetch their bundle and build a session.
  Future<void> _ensureSession(String remoteUserId, {int deviceId = 1}) async {
    final address = SignalProtocolAddress(remoteUserId, deviceId);

    if (await _store.containsSession(address)) {
      return; // Session already exists
    }

    // Fetch bundle from Supabase
    final response =
        await _supabase
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

    // Force trust the fetched identity key to prevent UntrustedIdentityException 
    // if the remote user has re-installed or changed their keys.
    // First, remove the old key (if any) because libsignal ignores updates to existing keys.
    await _store.saveIdentity(address, null);
    await _store.saveIdentity(address, identityKey);

    // Build Session
    final sessionBuilder = SessionBuilder(
      _store,
      _store,
      _store,
      _store,
      address,
    );
    await sessionBuilder.processPreKeyBundle(preKeyBundle);

    // Remove the used one-time prekey from Supabase so others don't use it
    onetimePrekeys.remove(firstKeyIdString);
    await _supabase
        .from('signal_keys')
        .update({'onetime_prekeys': onetimePrekeys})
        .eq('user_id', remoteUserId);
  }

  /// Force a refresh of a remote user's bundle and rebuild the session.
  /// Used when a session is corrupted (e.g. Bad MAC).
  Future<void> forceRefreshBundle(String remoteUserId) async {
    debugPrint('[Signal] Force-refreshing bundle for $remoteUserId...');
    final address = SignalProtocolAddress(remoteUserId, 1);
    await _store.deleteSession(address);
    await _ensureSession(remoteUserId);
  }

  /// Encrypt a string message for a specific user
  Future<CiphertextMessage> encryptMessage(
    String recipientId,
    String plaintext, {
    int deviceId = 1,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) {
        throw Exception('SignalService not initialized and init failed');
      }
    }

    await _ensureSession(recipientId, deviceId: deviceId);

    final address = SignalProtocolAddress(recipientId, deviceId);
    final sessionCipher = SessionCipher(
      _store,
      _store,
      _store,
      _store,
      address,
    );

    try {
      final ciphertextMessage = await sessionCipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
      return ciphertextMessage;
    } catch (e) {
      debugPrint('[Signal] Session encryption failed: $e. Rebuilding session...');
      // If encryption fails (e.g. InvalidKeyException), the session is corrupted.
      // Delete the session and retry once.
      await _store.deleteSession(address);
      await _ensureSession(recipientId, deviceId: deviceId);
      
      final retryCipher = SessionCipher(
        _store,
        _store,
        _store,
        _store,
        address,
      );
      return await retryCipher.encrypt(
        Uint8List.fromList(utf8.encode(plaintext)),
      );
    }
  }

  // Track recent recovery attempts to prevent spamming
  final Map<String, DateTime> _lastRecoveryAttempt = {};

  /// Decrypt an incoming message.
  Future<String> decryptMessage(
    String senderId,
    String base64Ciphertext,
    int type, {
    int deviceId = 1,
    bool isHistorical = false,
  }) async {
    if (!_isInitialized) {
      final success = await init();
      if (!success) return '🔒 Message encrypted (Initialization error)';
    }

    final address = SignalProtocolAddress(senderId, deviceId);
    final sessionCipher = SessionCipher(
      _store,
      _store,
      _store,
      _store,
      address,
    );
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
        if (isHistorical) {
          return '🔒 Message encrypted (Historical)';
        }

        final now = DateTime.now();
        final lastAttempt = _lastRecoveryAttempt[senderId];

        // Only attempt recovery once every 5 minutes per user to prevent loops and spam
        if (lastAttempt == null || now.difference(lastAttempt).inMinutes > 5) {
          _lastRecoveryAttempt[senderId] = now;
          debugPrint(
            '[Signal] Message authentication failed (Bad MAC) with $senderId. Resetting session to recover...',
          );

          // Proactive: Trigger a refresh and send a SYNC message to fix the other side
          forceRefreshBundle(senderId)
              .then((_) async {
                try {
                  // Send a hidden empty message to force the remote side to rebuild their session
                  await encryptMessage(senderId, 'PROTOCOL_SYNC');
                } catch (syncError) {
                  debugPrint('[Signal] Sync send failed: $syncError');
                }
              })
              .catchError((e) {
                debugPrint('[Signal] Recovery failed: $e');
              });
        }

        return '🔒 Optimizing secure connection...';
      } else if (errorStr.contains('No valid sessions') ||
          errorStr.contains('InvalidMessageException')) {
        debugPrint(
          '[Signal] No valid session or invalid message from $senderId. Clearing session.',
        );
        await _store.deleteSession(address);
        return '🔒 Session expired (Resetting...)';
      } else if (errorStr.contains('DuplicateMessageException')) {
        return '🔒 Message encrypted (Duplicate)';
      } else if (errorStr.contains('InvalidKeyIdException')) {
        debugPrint(
          '[Signal] Pre-key mismatch with $senderId: $e. Likely local pre-keys were lost.',
        );
        return '🔒 Key mismatch (Establishing new...)';
      } else if (errorStr.contains('UntrustedIdentityException')) {
        debugPrint('[Signal] Untrusted identity for $senderId. Key changed?');
        return '🔒 Identity changed (Verifying...)';
      }

      return '🔒 Message encrypted';
    }
  }
}
