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

  PQAuraService._();

  static PQAuraService get instance {
    _instance ??= PQAuraService._();
    return _instance!;
  }

  /// Initialize the PQ-Aura service
  Future<bool> init() async {
    if (_isInitialized) {
      debugPrint('[PQAura] Service already initialized');
      return true;
    }

    debugPrint('[PQAura] Starting service initialization...');

    // Load the native library
    if (!_bridge.load()) {
      debugPrint('[PQAura] CRITICAL FAILED: Native library could not be loaded. Handshakes will fail.');
      return false;
    }
    debugPrint('[PQAura] Native library loaded successfully.');

    // Check if we have identity keys, if not generate them
    final hasKeys = await _store.hasIdentityKeys();
    if (!hasKeys) {
      debugPrint('[PQAura] No local keys found. Generating new hybrid identity keys...');
      try {
        await _store.generateAndStoreIdentityKeys();
        debugPrint('[PQAura] Local identity keys generated successfully');
      } catch (e) {
        debugPrint('[PQAura] FAILED: Key generation error: $e');
        return false;
      }
    } else {
      debugPrint('[PQAura] Local identity keys found in store');
    }

    // Create pre-key bundle if not exists
    debugPrint('[PQAura] Preparing pre-key bundle...');
    await _store.createPreKeyBundle();

    // NEW: Upload bundle to server during init so other users can find us
    final localKeys = await _store.getIdentityKeys();
    if (localKeys != null) {
      debugPrint('[PQAura] Local keys retrieved. Uploading bundle to Supabase...');
      await _uploadBundleToServer(localKeys);
    } else {
      debugPrint('[PQAura] WARNING: Local keys retrieved as null after generation');
    }

    _isInitialized = true;
    debugPrint('[PQAura] Initialization COMPLETE. User is now Post-Quantum Ready.');
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
    
    if (hasSession(remoteUserId)) {
      debugPrint('[PQAura] Session already active in memory for: $remoteUserId');
      return true;
    }
    
    // Try to load from store
    debugPrint('[PQAura] Checking local store for session with: $remoteUserId');
    final loaded = await loadSession(remoteUserId);
    if (loaded) {
      debugPrint('[PQAura] Session loaded from local store for: $remoteUserId');
      return true;
    }
    
    // If not in store, initiate as Alice
    debugPrint('[PQAura] No local session found. Attempting to initiate as Alice for: $remoteUserId');
    final initiated = await initSessionAlice(remoteUserId);
    return initiated;
  }

  /// Initialize a session with a remote user (initiator - Alice)
  Future<bool> initSessionAlice(String remoteUserId) async {
    try {
      debugPrint('[PQAura] Handshaking as Alice with user: $remoteUserId');

      // Get remote user's pre-key bundle from server
      final response = await _supabase
          .from('pq_keys')
          .select()
          .eq('user_id', remoteUserId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[PQAura] No PQ keys found in Supabase for user: $remoteUserId. Handshake aborted.');
        return false;
      }
      debugPrint('[PQAura] Found remote PQ bundle for $remoteUserId');

      // Get our local identity keys
      final localKeys = await _store.getIdentityKeys();
      if (localKeys == null) {
        debugPrint('[PQAura] FAILED: No local identity keys found. Run init() first.');
        return false;
      }

      // Parse the remote bundle from JSON
      final bundle = response['bundle'] as Map<String, dynamic>;
      final remoteIdentityPk = base64Decode(bundle['identity_pk'] as String);
      final remoteSignedPk = base64Decode(bundle['signed_prekey'] as String);
      final remoteOtPk = bundle['onetime_prekey'] != null
          ? base64Decode(bundle['onetime_prekey'] as String)
          : null;

      debugPrint('[PQAura] Decoded remote bundle parts. PK sizes: IPK=${remoteIdentityPk.length}, SPK=${remoteSignedPk.length}');

      // Helper to convert flat hybrid PK (1600 bytes) to Rust-expected JSON structure
      Map<String, dynamic> toHybridPkMap(Uint8List flatPk) {
        return {
          'classic': flatPk.sublist(0, 32),
          'quantum': flatPk.sublist(32),
        };
      }

      // Build the PreKeyBundle bytes for FFI
      final bundleMap = {
        'identity_pk': toHybridPkMap(remoteIdentityPk),
        'signed_pre_key': toHybridPkMap(remoteSignedPk),
        'one_time_pre_key': remoteOtPk != null ? toHybridPkMap(remoteOtPk) : null,
      };
      final bundleBytes = utf8.encode(jsonEncode(bundleMap));

      // Initiate the handshake
      debugPrint('[PQAura] Calling Rust init_alice...');
      final initialMsg = _bridge.initAlice(
        remoteBundle: bundleBytes,
        localIdentityPk: localKeys.publicKey.toList(),
        localIdentitySk: localKeys.secretKey.toList(),
      );

      if (initialMsg == null) {
        debugPrint('[PQAura] CRITICAL FAILED: Alice handshake failed in Rust core library');
        return false;
      }

      debugPrint('[PQAura] Handshake message generated. Saving session state...');

      // Store the session state
      final serializedState = _bridge.serializeState(initialMsg.statePtr);
      if (serializedState != null) {
        await _store.saveSession(
            remoteUserId, Uint8List.fromList(serializedState));
        debugPrint('[PQAura] Session state persisted for $remoteUserId');
      }

      // Cache the state pointer
      _activeSessions[remoteUserId] = initialMsg.statePtr;
      
      // Store the initial message to send as the first PQ message header
      _pendingHandshakes[remoteUserId] = initialMsg;

      debugPrint('[PQAura] Alice handshake SUCCESS. Session is now LIVE with: $remoteUserId');
      return true;
    } catch (e) {
      debugPrint('[PQAura] Error in initSessionAlice for $remoteUserId: $e');
      return false;
    }
  }

  /// Initialize a session as Bob (responder) using an initial message
  Future<bool> initSessionBob(String senderId, Uint8List header, Uint8List payload) async {
    try {
      debugPrint('[PQAura] Initializing Bob session (responding to handshake) for: $senderId');
      
      final localKeys = await _store.getIdentityKeys();
      if (localKeys == null) {
        debugPrint('[PQAura] FAILED: Local keys missing for Bob init');
        return false;
      }

      // The header already contains the JSON-serialized InitialMessage (from Alice)
      final initialMsgBytes = header;

      final statePtr = _bridge.initBob(
        initialMessage: initialMsgBytes.toList(),
        localIdentityPk: localKeys.publicKey.toList(),
        localIdentitySk: localKeys.secretKey.toList(),
        localSignedSk: localKeys.secretKey.toList(),
        localOtSk: null,
      );

      if (statePtr == null || statePtr == nullptr) {
        debugPrint('[PQAura] CRITICAL FAILED: Bob handshake failed in Rust core');
        return false;
      }

      // Cache and persist the new state
      _activeSessions[senderId] = statePtr;
      final serializedState = _bridge.serializeState(statePtr);
      if (serializedState != null) {
        await _store.saveSession(senderId, Uint8List.fromList(serializedState));
      }

      debugPrint('[PQAura] Bob handshake SUCCESS. Session is now LIVE with: $senderId');
      return true;
    } catch (e) {
      debugPrint('[PQAura] Error in initSessionBob for $senderId: $e');
      return false;
    }
  }

  /// Load an existing session from storage (responder - Bob)
  Future<bool> loadSession(String remoteUserId) async {
    try {
      final serializedState = await _store.loadSession(remoteUserId);
      if (serializedState == null) {
        return false;
      }

      final statePtr = _bridge.deserializeState(serializedState.toList());
      if (statePtr == null || statePtr == nullptr) {
        debugPrint('[PQAura] Failed to deserialize stored state for: $remoteUserId');
        return false;
      }

      _activeSessions[remoteUserId] = statePtr;
      return true;
    } catch (e) {
      debugPrint('[PQAura] Error loading session: $e');
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
        debugPrint('[PQAura] No active session found for: $recipientId');
        return null;
      }

      // Prepare plaintext and additional data
      final plaintextBytes = utf8.encode(plaintext);
      final ad = utf8.encode(recipientId);

      // Encrypt
      final encrypted = _bridge.encrypt(state, plaintextBytes, ad);

      if (encrypted == null) {
        debugPrint('[PQAura] Encryption failed in Rust core');
        return null;
      }

      // Serialize the session state after each message
      final serializedState = _bridge.serializeState(state);
      if (serializedState != null) {
        await _store.saveSession(
            recipientId, Uint8List.fromList(serializedState));
      }

      Uint8List header;
      Uint8List payload;

      // Special case: Alice's FIRST message must carry the handshake
      if (_pendingHandshakes.containsKey(recipientId)) {
        final initialMsg = _pendingHandshakes.remove(recipientId);
        debugPrint('[PQAura] Packing PQ-X3DH handshake into first message header');

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
        debugPrint('[PQAura] Decryption failed for user: $senderId');
        return null;
      }

      // Save state after ratchet turn
      final serializedState = _bridge.serializeState(state);
      if (serializedState != null) {
        await _store.saveSession(senderId, Uint8List.fromList(serializedState));
      }

      return utf8.decode(plaintext);
    } catch (e) {
      debugPrint('[PQAura] Decryption error: $e');
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

  /// Decrypt a media key
  Future<Uint8List?> decryptMediaKey(
    String senderId,
    Map<String, dynamic> encryptionData,
  ) async {
    try {
      if (encryptionData['protocol'] != 'pq_aura') return null;
      
      final success = await getOrCreateSession(senderId);
      if (success != true) return null;

      final state = _activeSessions[senderId];
      if (state == null) return null;

      final header = base64Decode(encryptionData['pq_header'] as String);
      final payload = base64Decode(encryptionData['pq_payload'] as String);

      final ad = utf8.encode('media_key:$senderId');
      final decrypted = _bridge.decrypt(state, header.toList(), payload.toList(), ad);

      if (decrypted == null) return null;
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
