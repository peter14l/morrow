import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:oasis/core/crypto/pq_aura_bridge.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_store.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// High-level PQ-Aura encryption service.
/// Provides post-quantum resistant encryption for messages and media.
class PQAuraService {
  static PQAuraService? _instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PQAuraStore _store = PQAuraStore.instance;
  final PQAuraBridge _bridge = PQAuraBridge.instance;

  // In-memory session state pointers (keyed by remote user ID)
  final Map<String, Pointer<RatchetState>> _activeSessions = {};

  // Pending handshake data for Alice's first message
  final Map<String, PQAuraInitialMessage> _pendingHandshakes = {};

  bool _isInitialized = false;

  // Failure cache to prevent repeated heavy crypto on broken sessions
  final Set<String> _corruptSessions = {};

  PQAuraService._();

  static PQAuraService get instance {
    _instance ??= PQAuraService._();
    return _instance!;
  }

  /// Initialize the PQ-Aura service
  Future<bool> init() async {
    if (_isInitialized) return true;

    // Load the native library
    if (!_bridge.load()) {
      debugPrint('[PQAura] CRITICAL: Native library failed to load.');
      return false;
    }

    final hasKeys = await _store.hasIdentityKeys();
    if (!hasKeys) {
      try {
        await _store.generateAndStoreIdentityKeys();
      } catch (e) {
        debugPrint('[PQAura] Key generation error: $e');
        return false;
      }
    }

    await _store.createPreKeyBundle();

    final localKeys = await _store.getIdentityKeys();
    if (localKeys != null) {
      await _uploadBundleToServer(localKeys);
    }

    _isInitialized = true;
    return true;
  }

  bool get isReady => _isInitialized;

  /// Check if we have a session with a specific user
  bool hasSession(String remoteUserId) {
    return _activeSessions.containsKey(remoteUserId);
  }

  /// Get or create a session with a remote user
  Future<bool?> getOrCreateSession(String remoteUserId) async {
    if (!_isInitialized) await init();
    if (hasSession(remoteUserId)) return true;
    
    final loaded = await loadSession(remoteUserId);
    if (loaded) return true;
    
    return await initSessionAlice(remoteUserId);
  }

  /// Initialize a session with a remote user (initiator - Alice)
  Future<bool> initSessionAlice(String remoteUserId) async {
    try {
      final response = await _supabase
          .from('pq_keys')
          .select()
          .eq('user_id', remoteUserId)
          .maybeSingle();

      if (response == null) return false;

      final localKeys = await _store.getIdentityKeys();
      if (localKeys == null) return false;

      final bundle = response['bundle'] as Map<String, dynamic>;
      final remoteIdentityPk = base64Decode(bundle['identity_pk'] as String);
      final remoteSignedPk = base64Decode(bundle['signed_prekey'] as String);
      final remoteOtPk = bundle['onetime_prekey'] != null
          ? base64Decode(bundle['onetime_prekey'] as String)
          : null;

      Map<String, dynamic> toHybridPkMap(Uint8List flatPk) {
        return {
          'classic': flatPk.sublist(0, 32),
          'quantum': flatPk.sublist(32),
        };
      }

      final bundleMap = {
        'identity_pk': toHybridPkMap(remoteIdentityPk),
        'signed_pre_key': toHybridPkMap(remoteSignedPk),
        'one_time_pre_key': remoteOtPk != null ? toHybridPkMap(remoteOtPk) : null,
      };
      final bundleBytes = utf8.encode(jsonEncode(bundleMap));

      final initialMsg = _bridge.initAlice(
        remoteBundle: bundleBytes,
        localIdentityPk: localKeys.publicKey.toList(),
        localIdentitySk: localKeys.secretKey.toList(),
      );

      if (initialMsg == null) return false;

      // Prevent memory leak: free existing pending handshake if it exists
      final oldHandshake = _pendingHandshakes.remove(remoteUserId);
      if (oldHandshake != null) {
        _bridge.freeInitialMessage(oldHandshake.nativePtr);
      }

      await _store.saveSessionAtomic(remoteUserId, initialMsg.statePtr);

      _activeSessions[remoteUserId] = initialMsg.statePtr;
      _corruptSessions.remove(remoteUserId);
      _pendingHandshakes[remoteUserId] = initialMsg;

      debugPrint('[PQAura] Session initiated with: $remoteUserId');
      return true;
    } catch (e) {
      debugPrint('[PQAura] Alice init error ($remoteUserId): $e');
      return false;
    }
  }

  /// Initialize a session as Bob (responder) using an initial message
  Future<bool> initSessionBob(String senderId, Uint8List header, Uint8List payload) async {
    try {
      final localKeys = await _store.getIdentityKeys();
      if (localKeys == null) return false;

      final statePtr = _bridge.initBob(
        initialMessage: header.toList(),
        localIdentityPk: localKeys.publicKey.toList(),
        localIdentitySk: localKeys.secretKey.toList(),
        localSignedSk: localKeys.secretKey.toList(),
        localOtSk: null,
      );

      if (statePtr == null || statePtr == nullptr) return false;

      _activeSessions[senderId] = statePtr;
      _corruptSessions.remove(senderId);
      await _store.saveSessionAtomic(senderId, statePtr);

      debugPrint('[PQAura] Session established with: $senderId');
      return true;
    } catch (e) {
      debugPrint('[PQAura] Bob init error ($senderId): $e');
      return false;
    }
  }

  /// Load an existing session from storage
  Future<bool> loadSession(String remoteUserId) async {
    try {
      var statePtr = await _store.loadSessionAtomic(remoteUserId);
      
      if (statePtr != null && statePtr != nullptr) {
        _activeSessions[remoteUserId] = statePtr;
        _corruptSessions.remove(remoteUserId);
        return true;
      }

      final serializedState = await _store.loadSession(remoteUserId);
      if (serializedState != null) {
        statePtr = _bridge.deserializeState(serializedState.toList());
        
        if (statePtr != null && statePtr != nullptr) {
          _activeSessions[remoteUserId] = statePtr;
          _corruptSessions.remove(remoteUserId);
          await _store.saveSessionAtomic(remoteUserId, statePtr);
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[PQAura] Load session error: $e');
      return false;
    }
  }

  /// Encrypt a message for a specific user
  Future<PQAuraEncryptedMessage?> encryptMessage(
    String recipientId,
    String plaintext,
  ) async {
    try {
      // Ensure we have a session
      final success = await getOrCreateSession(recipientId);
      if (success != true) return null;

      final state = _activeSessions[recipientId];
      if (state == null) {
        return null;
      }

      // Prepare plaintext and additional data
      final plaintextBytes = utf8.encode(plaintext);
      final ad = utf8.encode(recipientId);

      // Encrypt
      final encrypted = _bridge.encrypt(state, plaintextBytes, ad);

      if (encrypted == null) {
        return null;
      }

      // Save the session state atomically after each message
      await _store.saveSessionAtomic(recipientId, state);

      Uint8List header;
      Uint8List payload;

      // Special case: Alice's FIRST message must carry the handshake
      if (_pendingHandshakes.containsKey(recipientId)) {
        final initialMsg = _pendingHandshakes.remove(recipientId);
        if (initialMsg == null) {
          header = Uint8List.fromList(encrypted.header);
          payload = Uint8List.fromList(encrypted.payload);
        } else {
          // Bob expects a JSON-serialized InitialMessage for pqa_init_bob
          final aliceHandshake = {
            'alice_identity_pk': {
              'classic': initialMsg.aliceIdentityPk.sublist(0, 32),
              'quantum': initialMsg.aliceIdentityPk.sublist(32),
            },
            'ephemeral_pk': {
              'classic': initialMsg.ephemeralPk.sublist(0, 32),
              'quantum': initialMsg.ephemeralPk.sublist(32),
            },
            'kem_ciphertext_identity': initialMsg.kemCiphertextIdentity,
            'kem_ciphertext_signed': initialMsg.kemCiphertextSigned,
            'kem_ciphertext_one_time': initialMsg.kemCiphertextOneTime,
            'ratchet_message': {
              'header_ciphertext': encrypted.header,
              'payload_ciphertext': encrypted.payload,
            }
          };

          header = Uint8List.fromList(utf8.encode(jsonEncode(aliceHandshake)));
          payload = Uint8List.fromList(encrypted.payload);

          // Free the native initial message
          _bridge.freeInitialMessage(initialMsg.nativePtr);
        }
      } else {
        header = Uint8List.fromList(encrypted.header);
        payload = Uint8List.fromList(encrypted.payload);
      }

      final result = PQAuraEncryptedMessage(
        header: header,
        payload: payload,
      );

      _bridge.freeMessage(encrypted.nativePtr);
      return result;
    } catch (e) {
      debugPrint('[PQAura] Encryption error: $e');
      return null;
    }
  }

  /// Encrypt a message for multiple recipients (group chat)
  Future<Map<String, dynamic>?> encryptGroupMessage(
    List<String> recipientIds,
    String plaintext,
  ) async {
    try {
      final Map<String, dynamic> encryptedHeaders = {};
      final String currentUserId = _supabase.auth.currentUser?.id ?? '';

      for (final recipientId in recipientIds) {
        // Skip self
        if (recipientId == currentUserId) continue;

        final encrypted = await encryptMessage(recipientId, plaintext);
        if (encrypted != null) {
          encryptedHeaders['pqa_header_$recipientId'] = base64Encode(encrypted.header);
          // Payload is same for all if we use same AES key? 
          // Wait, PQAura encrypts the plaintext directly in the native bridge.
          // So each recipient gets a different header AND payload.
          // In pairwise PQ-DR, the message on the server would need to store 
          // all headers and all payloads? No, usually we encrypt a random AES key 
          // with PQ-Aura and then encrypt the plaintext with AES.
          // BUT the current PQAuraService encrypts the plaintext directly.
          
          // Let's check how decryptMessage works. It takes header and payload.
          // If I want to avoid storing N payloads, I should refactor to encrypt a key.
          
          // However, to keep it simple and following "Pairwise PQ-DR" strictly as implemented in the bridge:
          // We will store pqa_header_[id] and pqa_payload_[id].
          encryptedHeaders['pqa_payload_$recipientId'] = base64Encode(encrypted.payload);
        }
      }
      
      if (encryptedHeaders.isEmpty) return null;
      
      encryptedHeaders['protocol'] = 'pq_aura_group';
      return encryptedHeaders;
    } catch (e) {
      debugPrint('[PQAura] Group encryption error: $e');
      return null;
    }
  }

  /// Decrypt a message from a specific user
  Future<String?> decryptMessage(
    String senderId,
    Uint8List header,
    Uint8List payload,
  ) async {
    try {
      if (!_isInitialized) {
        final ready = await init();
        if (!ready) return null;
      }

      // If we know this session is broken, don't keep trying heavy crypto
      if (_corruptSessions.contains(senderId)) return null;

      // If no session, Bob must respond to the handshake
      if (!hasSession(senderId)) {
        final loaded = await loadSession(senderId);
        if (!loaded) {
          final initiated = await initSessionBob(senderId, header, payload);
          if (!initiated) return null;
        }
      }

      final state = _activeSessions[senderId];
      if (state == null) return null;

      final ad = utf8.encode(senderId);
      final plaintext = _bridge.decrypt(state, header.toList(), payload.toList(), ad);

      if (plaintext == null) {
        if (kDebugMode) {
           debugPrint('[PQAura] Decryption failed for user: $senderId. Marking session as corrupt.');
        }
        _corruptSessions.add(senderId);
        return null;
      }

      // Save state atomically after ratchet turn
      await _store.saveSessionAtomic(senderId, state);

      return utf8.decode(plaintext);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PQAura] Decryption error: $e');
      }
      return null;
    }
  }

  /// Encrypt a media key using the PQ session
  Future<Map<String, String>?> encryptMediaKey(
    String recipientId,
    Uint8List mediaKey,
  ) async {
    try {
      final success = await getOrCreateSession(recipientId);
      if (success != true) return null;

      final state = _activeSessions[recipientId];
      if (state == null) return null;

      final ad = utf8.encode('media_key:$recipientId');
      final encrypted = _bridge.encrypt(state, mediaKey.toList(), ad);

      if (encrypted == null) return null;

      // Save state atomically
      await _store.saveSessionAtomic(recipientId, state);

      final result = {
        'pq_header': base64Encode(Uint8List.fromList(encrypted.header)),
        'pq_payload': base64Encode(Uint8List.fromList(encrypted.payload)),
        'protocol': 'pq_aura',
      };

      _bridge.freeMessage(encrypted.nativePtr);
      return result;
    } catch (e) {
      debugPrint('[PQAura] Media key encryption error: $e');
      return null;
    }
  }

  /// Encrypt a media key for multiple recipients (group media)
  Future<Map<String, String>?> encryptGroupMediaKey(
    List<String> recipientIds,
    Uint8List mediaKey,
  ) async {
    try {
      final Map<String, String> encryptedKeys = {};
      final String currentUserId = _supabase.auth.currentUser?.id ?? '';

      for (final recipientId in recipientIds) {
        if (recipientId == currentUserId) continue;

        final result = await encryptMediaKey(recipientId, mediaKey);
        if (result != null) {
          encryptedKeys['pqa_header_$recipientId'] = result['pq_header']!;
          encryptedKeys['pqa_payload_$recipientId'] = result['pq_payload']!;
        }
      }

      if (encryptedKeys.isEmpty) return null;
      
      encryptedKeys['protocol'] = 'pq_aura_group';
      return encryptedKeys;
    } catch (e) {
      debugPrint('[PQAura] Group media key encryption error: $e');
      return null;
    }
  }

  /// Decrypt a media key
  Future<Uint8List?> decryptMediaKey(
    String senderId,
    Map<String, dynamic> encryptionData,
  ) async {
    try {
      final protocol = encryptionData['protocol'] as String?;
      if (protocol != 'pq_aura' && protocol != 'pq_aura_group') return null;
      
      final success = await getOrCreateSession(senderId);
      if (success != true) return null;

      final state = _activeSessions[senderId];
      if (state == null) return null;

      String headerB64;
      String payloadB64;

      if (protocol == 'pq_aura_group') {
        headerB64 = encryptionData['pqa_header_$senderId'] as String? ?? '';
        payloadB64 = encryptionData['pqa_payload_$senderId'] as String? ?? '';
      } else {
        headerB64 = encryptionData['pq_header'] as String? ?? '';
        payloadB64 = encryptionData['pq_payload'] as String? ?? '';
      }

      if (headerB64.isEmpty || payloadB64.isEmpty) return null;

      final header = base64Decode(headerB64);
      final payload = base64Decode(payloadB64);

      final ad = utf8.encode('media_key:$senderId');
      final decrypted = _bridge.decrypt(state, header.toList(), payload.toList(), ad);

      if (decrypted == null) return null;

      // Save state atomically
      await _store.saveSessionAtomic(senderId, state);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('[PQAura] Media key decryption error: $e');
      return null;
    }
  }

  /// Upload our pre-key bundle to the server
  Future<void> _uploadBundleToServer(PQAuraKeyPairData keys) async {
    try {
      final bundle = await _store.getPreKeyBundle();
      if (bundle == null) {
        debugPrint('[PQAura] Skip upload: Local bundle not ready');
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[PQAura] Skip upload: No authenticated user');
        return;
      }

      debugPrint('[PQAura] Sending bundle to Supabase for user: $userId');
      
      final data = {
        'user_id': userId,
        'identity_pk': base64Encode(keys.publicKey),
        'bundle': {
          'identity_pk': base64Encode(bundle.identityPk),
          'signed_prekey': base64Encode(bundle.signedPreKey),
          'onetime_prekey': bundle.oneTimePreKey != null
              ? base64Encode(bundle.oneTimePreKey!)
              : null,
        },
      };

      await _supabase.from('pq_keys').upsert(data);
      debugPrint('[PQAura] SUCCESS: PQ bundle is now live on server');
    } catch (e) {
      debugPrint('[PQAura] FAILED to upload bundle: $e');
    }
  }

  /// Close and clean up a session
  Future<void> closeSession(String remoteUserId) async {
    final state = _activeSessions.remove(remoteUserId);
    if (state != null) {
      _bridge.freeState(state);
      await _store.deleteSession(remoteUserId);
    }
  }

  /// Clear all data (logout)
  Future<void> clearAllData() async {
    for (final state in _activeSessions.values) {
      _bridge.freeState(state);
    }
    _activeSessions.clear();

    for (final initialMsg in _pendingHandshakes.values) {
      _bridge.freeInitialMessage(initialMsg.nativePtr);
    }
    _pendingHandshakes.clear();

    await _store.clearAll();
    _isInitialized = false;
  }
}

/// Encrypted message structure
class PQAuraEncryptedMessage {
  final Uint8List header;
  final Uint8List payload;

  PQAuraEncryptedMessage({
    required this.header,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'header': base64Encode(header),
        'payload': base64Encode(payload),
      };

  factory PQAuraEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return PQAuraEncryptedMessage(
      header: base64Decode(json['header'] as String),
      payload: base64Decode(json['payload'] as String),
    );
  }
}
