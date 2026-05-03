import 'dart:convert';
import 'package:oasis/core/storage/secure_storage.dart';

/// A persistent implementation of SignalProtocolStore using SecureStorage
/// for identity keys, and SharedPreferences for session/prekey state.
class PersistentSignalStore implements SignalProtocolStore {
  final InMemorySignalProtocolStore _inMemoryStore;
  final SecureStorage _secureStorage = SecureStorage();
  late final SharedPreferences _prefs;


  // Keys for SharedPreferences / Secure Storage
  static String _identityKeyPairKey(String uid) =>
      'signal_identity_key_pair_$uid';
  static String _localRegistrationIdKey(String uid) =>
      'signal_registration_id_$uid';
  static String _sessionsKeyPrefix(String uid) => 'signal_session_${uid}_';
  static String _preKeysKeyPrefix(String uid) => 'signal_prekey_${uid}_';
  static String _signedPreKeyKeyPrefix(String uid) =>
      'signal_signed_prekey_${uid}_';

  PersistentSignalStore(IdentityKeyPair identityKeyPair, int registrationId)
    : _inMemoryStore = InMemorySignalProtocolStore(
        identityKeyPair,
        registrationId,
      );

  /// Check if local keys exist and belong to the current user
  static Future<bool> hasKeys() async {
    debugPrint('[SignalStore] hasKeys check starting...');
    final secureStorage = SecureStorage();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[SignalStore] hasKeys: No user logged in');
      return false;
    }

    try {
      final identityKeyString = await secureStorage.read(
        key: _identityKeyPairKey(userId),
      );
      final registrationIdString = await secureStorage.read(
        key: _localRegistrationIdKey(userId),
      );

      debugPrint('[SignalStore] hasKeys result: identity=${identityKeyString != null}, registration=${registrationIdString != null}');
      return identityKeyString != null && registrationIdString != null;
    } catch (e) {
      debugPrint('[SignalStore] hasKeys error: $e');
      return false;
    }
  }

  /// Check if we have any pre-keys stored locally
  Future<bool> hasPreKeys() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final keys = _prefs.getKeys();
    final prefix = _preKeysKeyPrefix(userId);
    return keys.any((k) => k.startsWith(prefix));
  }

  /// Check if we have any signed pre-keys stored locally
  Future<bool> hasSignedPreKeys() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final keys = _prefs.getKeys();
    final prefix = _signedPreKeyKeyPrefix(userId);
    return keys.any((k) => k.startsWith(prefix));
  }

  /// Manually save keys and initialize (used for restoration)
  static Future<PersistentSignalStore> saveAndInit(
    IdentityKeyPair identityKeyPair,
    int registrationId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final secureStorage = SecureStorage();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Cannot save keys: No user');

    await secureStorage.write(
      key: _identityKeyPairKey(userId),
      value: base64Encode(identityKeyPair.serialize()),
    );
    await secureStorage.write(
      key: _localRegistrationIdKey(userId),
      value: registrationId.toString(),
    );

    final store = PersistentSignalStore(identityKeyPair, registrationId);
    store._prefs = prefs;
    await store._loadState(userId);

    return store;
  }

  static Future<PersistentSignalStore> init() async {
    final prefs = await SharedPreferences.getInstance();
    final secureStorage = SecureStorage();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Cannot init SignalStore: No user');

    // Load Identity Key Pair and check ownership
    final identityKeyString = await secureStorage.read(
      key: _identityKeyPairKey(userId),
    );
    final registrationIdString = await secureStorage.read(
      key: _localRegistrationIdKey(userId),
    );

    IdentityKeyPair identityKeyPair;
    int registrationId;

    if (identityKeyString != null && registrationIdString != null) {
      debugPrint('[SignalStore] Loading existing keys for user $userId');
      identityKeyPair = IdentityKeyPair.fromSerialized(
        base64Decode(identityKeyString),
      );
      registrationId = int.parse(registrationIdString);
    } else {
      debugPrint('[SignalStore] Generating new Signal identity for $userId');
      identityKeyPair = generateIdentityKeyPair();
      registrationId = generateRegistrationId(false);

      await secureStorage.write(
        key: _identityKeyPairKey(userId),
        value: base64Encode(identityKeyPair.serialize()),
      );
      await secureStorage.write(
        key: _localRegistrationIdKey(userId),
        value: registrationId.toString(),
      );
    }

    final store = PersistentSignalStore(identityKeyPair, registrationId);
    store._prefs = prefs;

    // Load remaining state (sessions, etc) into memory
    await store._loadState(userId);


    return store;
  }

  Future<void> _loadState(String userId) async {
    final existingKeys = _prefs.getKeys();
    final sessionPrefix = _sessionsKeyPrefix(userId);
    final preKeyPrefix = _preKeysKeyPrefix(userId);
    final signedPreKeyPrefix = _signedPreKeyKeyPrefix(userId);
    final identityPrefix = 'signal_identity_${userId}_';

    for (final key in existingKeys) {
      if (key.startsWith(sessionPrefix)) {
        final addressName = key.replaceFirst(sessionPrefix, '');
        // format is name_deviceId
        final parts = addressName.split('_');
        if (parts.length == 2) {
          final address = SignalProtocolAddress(parts[0], int.parse(parts[1]));
          final sessionData = _prefs.getString(key);
          if (sessionData != null) {
            final record = SessionRecord.fromSerialized(
              base64Decode(sessionData),
            );
            _inMemoryStore.storeSession(address, record);
          }
        }
      } else if (key.startsWith(identityPrefix)) {
        final addressName = key.replaceFirst(identityPrefix, '');
        final address = SignalProtocolAddress(
          addressName,
          1,
        ); // Default deviceId 1
        final identityData = _prefs.getString(key);
        if (identityData != null) {
          final identityKey = IdentityKey.fromBytes(
            base64Decode(identityData),
            0,
          );
          _inMemoryStore.saveIdentity(address, identityKey);
        }
      } else if (key.startsWith(preKeyPrefix)) {
        final preKeyId = int.tryParse(key.replaceFirst(preKeyPrefix, ''));
        if (preKeyId != null) {
          final preKeyData = _prefs.getString(key);
          if (preKeyData != null) {
            final record = PreKeyRecord.fromBuffer(base64Decode(preKeyData));
            _inMemoryStore.storePreKey(preKeyId, record);
          }
        }
      } else if (key.startsWith(signedPreKeyPrefix)) {
        final signedPreKeyId = int.tryParse(
          key.replaceFirst(signedPreKeyPrefix, ''),
        );
        if (signedPreKeyId != null) {
          final stringData = _prefs.getString(key);
          if (stringData != null) {
            final record = SignedPreKeyRecord.fromSerialized(
              base64Decode(stringData),
            );
            _inMemoryStore.storeSignedPreKey(signedPreKeyId, record);
          }
        }
      }
    }
  }

  // --- IdentityKeyStore ---

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    return _inMemoryStore.getIdentityKeyPair();
  }

  @override
  Future<int> getLocalRegistrationId() async {
    return _inMemoryStore.getLocalRegistrationId();
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final result = await _inMemoryStore.saveIdentity(address, identityKey);
    if (identityKey != null) {
      final key = 'signal_identity_${userId}_${address.getName()}';
      await _prefs.setString(key, base64Encode(identityKey.serialize()));
    }
    return result;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    return _inMemoryStore.isTrustedIdentity(address, identityKey, direction);
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    return _inMemoryStore.getIdentity(address);
  }

  // --- SessionStore ---

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    return _inMemoryStore.loadSession(address);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    return _inMemoryStore.getSubDeviceSessions(name);
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.storeSession(address, record);
    // Persist to SharedPreferences
    final key =
        '${_sessionsKeyPrefix(userId)}${address.getName()}_${address.getDeviceId()}';
    await _prefs.setString(key, base64Encode(record.serialize()));
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    return _inMemoryStore.containsSession(address);
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.deleteSession(address);
    final key =
        '${_sessionsKeyPrefix(userId)}${address.getName()}_${address.getDeviceId()}';
    await _prefs.remove(key);
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.deleteAllSessions(name);
    final existingKeys = _prefs.getKeys();
    final prefix = '${_sessionsKeyPrefix(userId)}${name}_';
    for (final key in existingKeys) {
      if (key.startsWith(prefix)) {
        await _prefs.remove(key);
      }
    }
  }

  // --- PreKeyStore ---

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    try {
      return await _inMemoryStore.loadPreKey(preKeyId);
    } catch (e) {
      // If not in memory, try to load from storage
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final key = '${_preKeysKeyPrefix(userId)}$preKeyId';
        final data = _prefs.getString(key);
        if (data != null) {
          final record = PreKeyRecord.fromBuffer(base64Decode(data));
          await _inMemoryStore.storePreKey(preKeyId, record);
          return record;
        }
      }
      
      // Workaround for libsignal_protocol_dart dropping the exception and causing
      // an Unhandled Exception in the logs. We return a dummy prekey instead.
      // This will cause decryption to cleanly fail with a catchable InvalidMessageException.
      debugPrint('[SignalStore] PreKey $preKeyId missing. Supplying dummy to avoid unhandled exception.');
      final dummyKeyPair = Curve.generateKeyPair();
      return PreKeyRecord(preKeyId, dummyKeyPair);
    }
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.storePreKey(preKeyId, record);
    await _prefs.setString(
      '${_preKeysKeyPrefix(userId)}$preKeyId',
      base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final inMemory = await _inMemoryStore.containsPreKey(preKeyId);
    if (inMemory) return true;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    return _prefs.containsKey('${_preKeysKeyPrefix(userId)}$preKeyId');
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.removePreKey(preKeyId);
    await _prefs.remove('${_preKeysKeyPrefix(userId)}$preKeyId');
  }

  // --- SignedPreKeyStore ---

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    try {
      return await _inMemoryStore.loadSignedPreKey(signedPreKeyId);
    } catch (e) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final key = '${_signedPreKeyKeyPrefix(userId)}$signedPreKeyId';
        final data = _prefs.getString(key);
        if (data != null) {
          final record = SignedPreKeyRecord.fromSerialized(base64Decode(data));
          await _inMemoryStore.storeSignedPreKey(signedPreKeyId, record);
          return record;
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    return _inMemoryStore.loadSignedPreKeys();
  }

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.storeSignedPreKey(signedPreKeyId, record);
    await _prefs.setString(
      '${_signedPreKeyKeyPrefix(userId)}$signedPreKeyId',
      base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final inMemory = await _inMemoryStore.containsSignedPreKey(signedPreKeyId);
    if (inMemory) return true;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    return _prefs.containsKey(
      '${_signedPreKeyKeyPrefix(userId)}$signedPreKeyId',
    );
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _inMemoryStore.removeSignedPreKey(signedPreKeyId);
    await _prefs.remove('${_signedPreKeyKeyPrefix(userId)}$signedPreKeyId');
  }

  /// Wipe everything for the CURRENT user
  Future<void> clearAll() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await _secureStorage.delete(key: _identityKeyPairKey(userId));
    await _secureStorage.delete(key: _localRegistrationIdKey(userId));

    final keys = _prefs.getKeys();
    final sessionP = _sessionsKeyPrefix(userId);
    final preP = _preKeysKeyPrefix(userId);
    final signedP = _signedPreKeyKeyPrefix(userId);

    for (final key in keys) {
      if (key.startsWith(sessionP) ||
          key.startsWith(preP) ||
          key.startsWith(signedP)) {
        await _prefs.remove(key);
      }
    }

  }
}
