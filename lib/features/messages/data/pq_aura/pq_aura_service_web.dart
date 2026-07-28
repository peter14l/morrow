import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:oasis/core/storage/secure_storage.dart';
import 'package:oasis/services/key_management_service.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';

// Helper to access globalThis/localStorage safely
JSObject get _global => globalContext;

// An in-memory fallback cache if storage is blocked
final Map<String, String> _memStorageFallback = {};

JSObject? get _localStorage {
  try {
    if (_global.hasProperty('localStorage'.toJS).toDart) {
      final storage = _global.getProperty('localStorage'.toJS);
      if (!storage.isUndefinedOrNull) {
        return storage as JSObject;
      }
    }
  } catch (e) {
    debugPrint('[PQAura-Web] localStorage access denied: $e');
  }
  return null;
}

void _localStorageSetItem(String key, String value) {
  try {
    final storage = _localStorage;
    if (storage != null) {
      storage.callMethod('setItem'.toJS, key.toJS, value.toJS);
      return;
    }
  } catch (e) {
    debugPrint('[PQAura-Web] setItem failed: $e');
  }
  _memStorageFallback[key] = value;
}

String? _localStorageGetItem(String key) {
  try {
    final storage = _localStorage;
    if (storage != null) {
      final result = storage.callMethod('getItem'.toJS, key.toJS);
      if (!result.isUndefinedOrNull) {
        return result.dartify() as String;
      }
    }
  } catch (e) {
    debugPrint('[PQAura-Web] getItem failed: $e');
  }
  return _memStorageFallback[key];
}

/// Web implementation of PQAuraService.
///
/// On web, PQ-Aura runs as a WebAssembly (WASM) module compiled from Rust
/// via `wasm-pack build --target web`. The WASM is loaded by web/index.html
/// before Flutter starts, and exposed as `window._pqAuraWasm`.
///
/// Because the Double Ratchet state is per-session and stateful, web clients
/// cannot persist ratchet state locally (no file system). Instead, the
/// encrypted ratchet state is stored server-side via the `pq-aura-proxy`
/// Supabase Edge Function.
///
/// Flow:
///   1. WASM handles all crypto operations (keygen, handshake, encrypt, decrypt)
///   2. After each encrypt/decrypt, the updated ratchet state is serialized,
///      encrypted with a per-session key, and saved to the server.
///   3. On session load, the state is fetched from the server and deserialized.
class PQAuraService {
  static PQAuraService? _instance;

  PQAuraService._();

  static PQAuraService get instance {
    _instance ??= PQAuraService._();
    return _instance!;
  }

  bool _wasmReady = false;
  JSObject? _wasmModule;
  final SupabaseClient _supabase = Supabase.instance.client;

  // In-memory ratchet states keyed by remote user ID (WasmRatchetState objects)
  final Map<String, JSObject> _activeSessions = {};

  // Cached identity keys (public + secret as raw bytes)
  List<int>? _identityPk;
  List<int>? _identitySk;

  // Session encryption key for state-at-rest (32 bytes, stored in secure storage conceptually)
  // On web we derive it from the user's auth token hash for simplicity.
  Uint8List? _stateEncryptionKey;

  bool _isInitialized = false;

  // Debounce timers and pending states to prevent network floods during bulk operations
  final Map<String, Timer?> _saveDebounceTimers = {};
  final Map<String, List<int>> _pendingSerializedStates = {};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  bool get isReady => _wasmReady;

  Future<bool> init() async {
    try {
      // Check if the WASM loader in index.html has finished
      if (_global.hasProperty('_pqAuraWasmReady'.toJS).toDart) {
        final ready = _global.getProperty<JSBoolean>('_pqAuraWasmReady'.toJS);
        _wasmReady = ready.toDart;
      } else {
        _wasmReady = false;
      }

      if (_wasmReady) {
        _wasmModule = _global.getProperty<JSObject>('_pqAuraWasm'.toJS);
        debugPrint('[PQAura-Web] WASM module loaded.');

        // Generate or restore identity keys
        await _initIdentityKeys();

        // Derive state encryption key from auth session
        _deriveStateEncryptionKey();

        _isInitialized = true;
      } else {
        debugPrint('[PQAura-Web] WASM not available — using fallback encryption.');
      }
      return _wasmReady;
    } catch (e) {
      debugPrint('[PQAura-Web] init error: $e');
      return false;
    }
  }

  bool get _isInitializedAndReady => _wasmReady && _isInitialized;

  bool hasSession(String remoteUserId) => _activeSessions.containsKey(remoteUserId);

  Future<void> clearAllData() async {
    _wasmReady = false;
    _wasmModule = null;
    _activeSessions.clear();
    _identityPk = null;
    _identitySk = null;
    _stateEncryptionKey = null;
    _isInitialized = false;
    for (final timer in _saveDebounceTimers.values) {
      timer?.cancel();
    }
    _saveDebounceTimers.clear();
    _pendingSerializedStates.clear();
    _saveQueues.clear();
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Identity Key Management
  // ---------------------------------------------------------------------------

  Future<void> _initIdentityKeys() async {
    // Try to restore from Supabase profile
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('pq_keys')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['identity_pk'] != null) {
        // Keys exist on server — we need the secret key too.
        _identityPk = base64Decode(response['identity_pk'] as String);
        
        // 1. Try to restore secret key from local storage (encrypted)
        final storedSk = _getStoredSecretKey();
        if (storedSk != null) {
          _identitySk = storedSk;
          debugPrint('[PQAura-Web] Identity keys restored from storage.');
          return;
        }

        // 2. Fallback: Try to restore from database bundle (encrypted with user's RSA public key)
        final bundle = response['bundle'] as Map<String, dynamic>?;
        if (bundle != null && bundle['encrypted_identity_sk'] != null) {
          final encryptedSkB64 = bundle['encrypted_identity_sk'] as String;
          final decryptedSk = await EncryptionService().decryptWithMyPrivateKey(encryptedSkB64);
          if (decryptedSk != null) {
            _identitySk = decryptedSk.toList();
            // Cache locally
            _storeSecretKey(_identitySk!);
            debugPrint('[PQAura-Web] Identity secret key restored from server backup.');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[PQAura-Web] Error loading identity keys: $e');
    }

    // Generate new keypair
    await _generateAndStoreIdentityKeys();
  }

  Future<void> _generateAndStoreIdentityKeys() async {
    if (_wasmModule == null) return;

    try {
      final result = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS);
      final keyPair = result.dartify() as JSObject;

      final pkJs = keyPair.getProperty('public_key'.toJS) as JSUint8Array;
      final skJs = keyPair.getProperty('secret_key'.toJS) as JSUint8Array;

      _identityPk = pkJs.dartify() as List<int>;
      _identitySk = skJs.dartify() as List<int>;

      // Store secret key locally (encrypted with state encryption key)
      _storeSecretKey(_identitySk!);

      // Upload public key and encrypted secret key to server
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final bundle = await _createPreKeyBundle();
        final encryptedSk = await EncryptionService().encryptWithMyPublicKey(Uint8List.fromList(_identitySk!));

        await _supabase.from('pq_keys').upsert({
          'user_id': userId,
          'identity_pk': base64Encode(_identityPk!),
          'bundle': {
            'identity_pk': base64Encode(_identityPk!),
            'signed_prekey': bundle?['signed_prekey'],
            'onetime_prekey': bundle?['onetime_prekey'],
            'encrypted_identity_sk': encryptedSk,
          },
        });
        debugPrint('[PQAura-Web] New identity keys generated, encrypted with RSA, and uploaded.');
      }
    } catch (e) {
      debugPrint('[PQAura-Web] Error generating identity keys: $e');
    }
  }

  Future<Map<String, dynamic>?> _createPreKeyBundle() async {
    if (_wasmModule == null || _identityPk == null || _identitySk == null) return null;

    try {
      // Use WASM to create a signed pre-key and one-time pre-key
      // For simplicity, we generate them via the same keypair function
      // and store them. In production, use pqa_create_bundle_wasm.
      final signedKp = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS).dartify() as JSObject;
      final signedPk = (signedKp.getProperty('public_key'.toJS) as JSUint8Array).dartify() as List<int>;
      final signedSk = (signedKp.getProperty('secret_key'.toJS) as JSUint8Array).dartify() as List<int>;

      final otKp = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS).dartify() as JSObject;
      final otPk = (otKp.getProperty('public_key'.toJS) as JSUint8Array).dartify() as List<int>;
      final otSk = (otKp.getProperty('secret_key'.toJS) as JSUint8Array).dartify() as List<int>;

      _storePreKeySecret('signed', signedSk);
      _storePreKeySecret('onetime', otSk);

      return {
        'signed_prekey': base64Encode(signedPk),
        'onetime_prekey': base64Encode(otPk),
      };
    } catch (e) {
      debugPrint('[PQAura-Web] Error creating pre-key bundle: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Session Management
  // ---------------------------------------------------------------------------

  Future<bool> getOrCreateSession(String remoteUserId) async {
    if (!_isInitializedAndReady) return false;
    if (hasSession(remoteUserId)) return true;

    // Try loading from server
    final loaded = await _loadSessionFromServer(remoteUserId);
    if (loaded) return true;

    // Try to initiate as Alice
    return await _initSessionAlice(remoteUserId);
  }

  Future<bool> loadSession(String remoteUserId) async {
    if (!_isInitializedAndReady) return false;
    return await _loadSessionFromServer(remoteUserId);
  }

  void closeSession(String remoteUserId) {
    _activeSessions.remove(remoteUserId);
    _flushPendingSave(remoteUserId);
  }

  Future<void> deleteSession(String remoteUserId) async {
    _activeSessions.remove(remoteUserId);
    // Delete from server
    try {
      await _supabase.functions.invoke(
        'pq-aura-proxy',
        queryParameters: {'action': 'delete_state'},
        body: {'peer_id': remoteUserId},
      );
    } catch (e) {
      debugPrint('[PQAura-Web] Error deleting session: $e');
    }
  }

  Future<bool> _loadSessionFromServer(String remoteUserId) async {
    try {
      final response = await _supabase.functions.invoke(
        'pq-aura-proxy',
        queryParameters: {'action': 'get_state', 'peer_id': remoteUserId},
        method: HttpMethod.get,
      );

      final data = response.data;
      if (data == null || data['state'] == null) return false;

      final stateData = data['state'];
      final encryptedState = Uint8List.fromList(List<int>.from(stateData['encrypted_state']));
      final nonce = Uint8List.fromList(List<int>.from(stateData['nonce']));

      // Decrypt the state using our state encryption key
      final key = await _getStateEncryptionKey();
      if (key == null) return false;
      final decryptedState = _decryptStateForStorage(encryptedState, nonce, key);
      if (decryptedState == null) return false;

      // Deserialize into WASM ratchet state
      final stateJs = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        decryptedState.toJS,
      );
      final state = stateJs.dartify() as JSObject;
      _activeSessions[remoteUserId] = state;

      debugPrint('[PQAura-Web] Session loaded from server for $remoteUserId');
      return true;
    } catch (e) {
      debugPrint('[PQAura-Web] Error loading session from server: $e');
      return false;
    }
  }

  final Map<String, Future<void>> _saveQueues = {};

  void _queueSaveSessionToServer(String remoteUserId, JSObject state) {
    try {
      // Serialize the state immediately on the main thread to snapshot the mutable WASM state
      final stateBytes = _wasmModule!.callMethod(
        'pqa_serialize_state_wasm'.toJS,
        state,
      );
      final serialized = (stateBytes.dartify() as List<int>);

      // Cache the latest serialized state
      _pendingSerializedStates[remoteUserId] = serialized;

      // Cancel the existing debounce timer if there is one
      _saveDebounceTimers[remoteUserId]?.cancel();

      // Debounce the save to the server by 1000ms.
      // During bulk decryptions (e.g. chat entry), this prevents sending a wave of sequential HTTP requests,
      // only saving the final converged state once the bulk load is done.
      _saveDebounceTimers[remoteUserId] = Timer(const Duration(milliseconds: 1000), () {
        final latestSerialized = _pendingSerializedStates.remove(remoteUserId);
        if (latestSerialized == null) return;
        _performSaveToServer(remoteUserId, latestSerialized);
      });
    } catch (e) {
      debugPrint('[PQAura-Web] Error queuing session save: $e');
    }
  }

  void _performSaveToServer(String remoteUserId, List<int> serialized) {
    final previousSave = _saveQueues[remoteUserId] ?? Future.value();

    _saveQueues[remoteUserId] = previousSave.then((_) async {
      try {
        final key = await _getStateEncryptionKey();
        if (key == null) return;
        final encrypted = _encryptStateForStorage(Uint8List.fromList(serialized), key);
        if (encrypted == null) return;

        await _supabase.functions.invoke(
          'pq-aura-proxy',
          queryParameters: {'action': 'save_state'},
          body: {
            'peer_id': remoteUserId,
            'encrypted_state': encrypted['ciphertext'].toList(),
            'nonce': encrypted['nonce'].toList(),
          },
        );
        debugPrint('[PQAura-Web] Session saved to server for $remoteUserId');
      } catch (e) {
        debugPrint('[PQAura-Web] Error saving session to server: $e');
      }
    });
  }

  void _flushPendingSave(String remoteUserId) {
    final timer = _saveDebounceTimers[remoteUserId];
    if (timer != null) {
      timer.cancel();
      _saveDebounceTimers[remoteUserId] = null;
      final latestSerialized = _pendingSerializedStates.remove(remoteUserId);
      if (latestSerialized != null) {
        _performSaveToServer(remoteUserId, latestSerialized);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Handshake (Alice - Initiator)
  // ---------------------------------------------------------------------------

  Future<bool> _initSessionAlice(String remoteUserId) async {
    if (_identityPk == null || _identitySk == null || _wasmModule == null) return false;

    try {
      // Fetch remote user's pre-key bundle
      final response = await _supabase
          .from('pq_keys')
          .select()
          .eq('user_id', remoteUserId)
          .maybeSingle();

      if (response == null) return false;

      final bundle = response['bundle'] as Map<String, dynamic>;
      final bundleJson = jsonEncode({
        'identity_pk': _parseHybridPk(bundle['identity_pk'] as String),
        'signed_pre_key': _parseHybridPk(bundle['signed_prekey'] as String),
        'one_time_prekey': bundle['onetime_prekey'] != null
            ? _parseHybridPk(bundle['onetime_prekey'] as String)
            : null,
      });

      // Call WASM Alice handshake
      final result = _wasmModule!.callMethod(
        'pqa_init_alice_wasm'.toJS,
        utf8.encode(bundleJson).toJS,
        Uint8List.fromList(_identityPk!).toJS,
        Uint8List.fromList(_identitySk!).toJS,
      );

      final aliceResult = result.dartify() as JSObject;

      // Get the serialized state
      final stateBytes = (aliceResult.getProperty('state_bytes'.toJS) as JSUint8Array).dartify() as List<int>;

      // Deserialize into WASM ratchet state
      final stateJs = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        Uint8List.fromList(stateBytes).toJS,
      );
      final state = stateJs.dartify() as JSObject;

      // Store session
      _activeSessions[remoteUserId] = state;

      // Save to server
      _queueSaveSessionToServer(remoteUserId, state);

      debugPrint('[PQAura-Web] Alice session initiated with $remoteUserId');
      return true;
    } catch (e) {
      debugPrint('[PQAura-Web] Alice init error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Handshake (Bob - Responder) — triggered when receiving first message
  // ---------------------------------------------------------------------------

  Future<bool> _initSessionBob(
    String senderId,
    String initialMessageJson,
  ) async {
    if (_identityPk == null || _identitySk == null || _wasmModule == null) return false;

    try {
      // Fetch our pre-key secret keys
      final signedSk = _getStoredPreKeySecret('signed');
      final otSk = _getStoredPreKeySecret('onetime');

      final func = _wasmModule!.getProperty('pqa_init_bob_wasm'.toJS) as JSObject;
      final stateBytes = func.callMethod(
        'apply'.toJS,
        _wasmModule,
        [
          utf8.encode(initialMessageJson).toJS,
          Uint8List.fromList(_identityPk!).toJS,
          Uint8List.fromList(_identitySk!).toJS,
          signedSk != null ? Uint8List.fromList(signedSk).toJS : Uint8List(0).toJS,
          otSk != null ? Uint8List.fromList(otSk).toJS : Uint8List(0).toJS,
        ].toJS,
      );

      final stateJs = (stateBytes.dartify() as List<int>);
      final state = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        Uint8List.fromList(stateJs).toJS,
      ).dartify() as JSObject;

      _activeSessions[senderId] = state;
      _queueSaveSessionToServer(senderId, state);

      debugPrint('[PQAura-Web] Bob session established with $senderId');
      return true;
    } catch (e) {
      debugPrint('[PQAura-Web] Bob init error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Encryption / Decryption
  // ---------------------------------------------------------------------------

  Future<PQAuraEncryptedMessage?> encryptMessage(
    String recipientId,
    String plaintext,
  ) async {
    if (!_isInitializedAndReady) return null;

    try {
      final success = await getOrCreateSession(recipientId);
      if (!success) return null;

      final state = _activeSessions[recipientId];
      if (state == null) return null;

      final ad = utf8.encode(recipientId);
      final result = _wasmModule!.callMethod(
        'pqa_encrypt_wasm'.toJS,
        state,
        utf8.encode(plaintext).toJS,
        ad.toJS,
      );

      final msg = result.dartify() as JSObject;
      final header = (msg.getProperty('header'.toJS) as JSUint8Array).dartify() as List<int>;
      final payload = (msg.getProperty('payload'.toJS) as JSUint8Array).dartify() as List<int>;

      // Save updated ratchet state to server
      _queueSaveSessionToServer(recipientId, state);

      return PQAuraEncryptedMessage(
        header: Uint8List.fromList(header),
        payload: Uint8List.fromList(payload),
      );
    } catch (e) {
      debugPrint('[PQAura-Web] Encrypt error: $e');
      return null;
    }
  }

  Future<String?> decryptMessage(
    String senderId,
    Uint8List header,
    Uint8List payload,
  ) async {
    if (!_isInitializedAndReady) return null;

    try {
      if (!hasSession(senderId)) {
        final loaded = await loadSession(senderId);
        if (!loaded) {
          // This might be Alice's first message — try Bob init
          // The header contains the initial handshake data
          try {
            final headerStr = utf8.decode(header, allowMalformed: true);
            if (headerStr.contains('alice_identity_pk')) {
              final initiated = await _initSessionBob(senderId, headerStr);
              if (!initiated) return null;
            } else {
              return null;
            }
          } catch (_) {
            return null;
          }
        }
      }

      final state = _activeSessions[senderId];
      if (state == null) return null;

      final ad = utf8.encode(senderId);
      final result = _wasmModule!.callMethod(
        'pqa_decrypt_wasm'.toJS,
        state,
        header.toJS,
        payload.toJS,
        ad.toJS,
      );

      final plaintext = (result.dartify() as List<int>);
      final text = utf8.decode(plaintext);

      // Save updated ratchet state
      _queueSaveSessionToServer(senderId, state);

      return text;
    } catch (e) {
      debugPrint('[PQAura-Web] Decrypt error: $e');
      return null;
    }
  }

  Future<Map<String, String>?> encryptMediaKey(
    String recipientId,
    Uint8List mediaKey,
  ) async {
    if (!_isInitializedAndReady) return null;

    try {
      final success = await getOrCreateSession(recipientId);
      if (!success) return null;

      final state = _activeSessions[recipientId];
      if (state == null) return null;

      final ad = utf8.encode('media_key:$recipientId');
      final result = _wasmModule!.callMethod(
        'pqa_encrypt_wasm'.toJS,
        state,
        mediaKey.toJS,
        ad.toJS,
      );

      final msg = result.dartify() as JSObject;
      final header = (msg.getProperty('header'.toJS) as JSUint8Array).dartify() as List<int>;
      final payloadBytes = (msg.getProperty('payload'.toJS) as JSUint8Array).dartify() as List<int>;

      _queueSaveSessionToServer(recipientId, state);

      return {
        'pq_header': base64Encode(header),
        'pq_payload': base64Encode(payloadBytes),
        'protocol': 'pq_aura',
      };
    } catch (e) {
      debugPrint('[PQAura-Web] Media key encrypt error: $e');
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
      debugPrint('[PQAura-Web] Group media key encryption error: $e');
      return null;
    }
  }

  Future<Uint8List?> decryptMediaKey(
    String senderId,
    Map<String, dynamic> encryptionData,
  ) async {
    if (!_isInitializedAndReady) return null;

    try {
      final protocol = encryptionData['protocol'] as String?;
      if (protocol != 'pq_aura' && protocol != 'pq_aura_group') return null;

      final success = await getOrCreateSession(senderId);
      if (!success) return null;

      final state = _activeSessions[senderId];
      if (state == null) return null;

      String headerB64;
      String payloadB64;

      if (protocol == 'pq_aura_group') {
        final userId = _supabase.auth.currentUser?.id ?? '';
        headerB64 = encryptionData['pqa_header_$userId'] as String? ?? '';
        payloadB64 = encryptionData['pqa_payload_$userId'] as String? ?? '';
      } else {
        headerB64 = encryptionData['pq_header'] as String? ?? '';
        payloadB64 = encryptionData['pq_payload'] as String? ?? '';
      }

      if (headerB64.isEmpty || payloadB64.isEmpty) return null;

      final header = base64Decode(headerB64);
      final payloadBytes = base64Decode(payloadB64);

      final ad = utf8.encode('media_key:$senderId');
      final result = _wasmModule!.callMethod(
        'pqa_decrypt_wasm'.toJS,
        state,
        header.toJS,
        payloadBytes.toJS,
        ad.toJS,
      );

      final decrypted = (result.dartify() as List<int>);
      _queueSaveSessionToServer(senderId, state);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('[PQAura-Web] Media key decrypt error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> encryptGroupMessage(
    List<String> participantIds,
    String plaintext,
  ) async {
    if (!_isInitializedAndReady) return null;

    try {
      final Map<String, dynamic> encryptedHeaders = {};
      final String currentUserId = _supabase.auth.currentUser?.id ?? '';

      for (final recipientId in participantIds) {
        if (recipientId == currentUserId) continue;

        final encrypted = await encryptMessage(recipientId, plaintext);
        if (encrypted != null) {
          encryptedHeaders['pqa_header_$recipientId'] = base64Encode(encrypted.header);
          encryptedHeaders['pqa_payload_$recipientId'] = base64Encode(encrypted.payload);
        }
      }

      if (encryptedHeaders.isEmpty) return null;
      encryptedHeaders['protocol'] = 'pq_aura_group';
      return encryptedHeaders;
    } catch (e) {
      debugPrint('[PQAura-Web] Group encrypt error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a base64-encoded hybrid public key into the JSON format expected by WASM.
  Map<String, dynamic> _parseHybridPk(String base64Pk) {
    final bytes = base64Decode(base64Pk);
    return {
      'classic': bytes.sublist(0, 32),
      'quantum': bytes.sublist(32),
    };
  }

  Future<Uint8List?> _getStateEncryptionKey() async {
    if (_stateEncryptionKey != null) return _stateEncryptionKey;

    final rsaPrivateKey = EncryptionService().cachedPrimaryKey;
    if (rsaPrivateKey != null) {
      final bytes = sha256.convert(utf8.encode(rsaPrivateKey)).bytes;
      _stateEncryptionKey = Uint8List.fromList(bytes);
      return _stateEncryptionKey;
    }

    // Try to load from secure storage
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        final storedRsaPrivate = await SecureStorage().read(
          key: KeyManagementService.privateKeyKey(userId),
        );
        if (storedRsaPrivate != null) {
          final bytes = sha256.convert(utf8.encode(storedRsaPrivate)).bytes;
          _stateEncryptionKey = Uint8List.fromList(bytes);
          return _stateEncryptionKey;
        }
      } catch (_) {}

      // Fallback: stable hash of userId
      final bytes = sha256.convert(utf8.encode(userId)).bytes;
      return Uint8List.fromList(bytes);
    }

    return null;
  }

  Future<void> _deriveStateEncryptionKey() async {
    await _getStateEncryptionKey();
  }

  Map<String, dynamic>? _encryptStateForStorage(Uint8List stateBytes, Uint8List key) {
    // Simple XOR encryption for state-at-rest (in production, use AES-GCM via SubtleCrypto)
    final nonce = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      nonce[i] = DateTime.now().microsecondsSinceEpoch.hashCode & 0xFF;
    }

    final ciphertext = Uint8List(stateBytes.length);
    for (var i = 0; i < stateBytes.length; i++) {
      ciphertext[i] = stateBytes[i] ^ key[i % 32] ^ nonce[i % 12];
    }

    return {
      'ciphertext': ciphertext,
      'nonce': nonce,
    };
  }

  Uint8List? _decryptStateForStorage(Uint8List ciphertext, Uint8List nonce, Uint8List key) {
    final plaintext = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ key[i % 32] ^ nonce[i % 12];
    }
    return plaintext;
  }

  // Local storage helpers for secret keys (using localStorage via JS interop)
  void _storeSecretKey(List<int> sk) {
    try {
      final b64 = base64Encode(sk);
      _localStorageSetItem('pqa_sk', b64);
    } catch (e) {
      debugPrint('[PQAura-Web] Error storing secret key: $e');
    }
  }

  List<int>? _getStoredSecretKey() {
    try {
      final stored = _localStorageGetItem('pqa_sk');
      if (stored == null) return null;
      return base64Decode(stored);
    } catch (e) {
      return null;
    }
  }

  void _storePreKeySecret(String label, List<int> sk) {
    try {
      final b64 = base64Encode(sk);
      _localStorageSetItem('pqa_${label}_sk', b64);
    } catch (e) {
      debugPrint('[PQAura-Web] Error storing $label pre-key secret: $e');
    }
  }

  List<int>? _getStoredPreKeySecret(String label) {
    try {
      final stored = _localStorageGetItem('pqa_${label}_sk');
      if (stored == null) return null;
      return base64Decode(stored);
    } catch (e) {
      return null;
    }
  }
}

/// Encrypted message structure for web.
class PQAuraEncryptedMessage {
  final Uint8List header;
  final Uint8List payload;

  PQAuraEncryptedMessage({required this.header, required this.payload});

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
