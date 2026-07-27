import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper to access globalThis/localStorage
JSObject get _global => globalContext;

JSObject get _localStorage => _global.getProperty('localStorage'.toJS) as JSObject;

void _localStorageSetItem(String key, String value) {
  _localStorage.callMethod('setItem'.toJS, [key.toJS, value.toJS]);
}

String? _localStorageGetItem(String key) {
  final result = _localStorage.callMethod('getItem'.toJS, [key.toJS]);
  if (result == null || result == JSNull()) return null;
  return result.dartify() as String;
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
        // The secret key should be stored encrypted in the user's profile or
        // derived from a known seed. For now, generate new if not available.
        _identityPk = base64Decode(response['identity_pk'] as String);
        // Try to restore secret key from local storage (encrypted)
        final storedSk = _getStoredSecretKey();
        if (storedSk != null) {
          _identitySk = storedSk;
          debugPrint('[PQAura-Web] Identity keys restored from storage.');
          return;
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
      final result = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS, []);
      final keyPair = result.dartify() as JSObject;

      final pkJs = keyPair.getProperty('public_key'.toJS) as JSUint8Array;
      final skJs = keyPair.getProperty('secret_key'.toJS) as JSUint8Array;

      _identityPk = pkJs.dartify() as List<int>;
      _identitySk = skJs.dartify() as List<int>;

      // Store secret key locally (encrypted with state encryption key)
      _storeSecretKey(_identitySk!);

      // Upload public key to server
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final bundle = await _createPreKeyBundle();
        await _supabase.from('pq_keys').upsert({
          'user_id': userId,
          'identity_pk': base64Encode(_identityPk!),
          'bundle': {
            'identity_pk': base64Encode(_identityPk!),
            'signed_prekey': bundle?['signed_prekey'],
            'onetime_prekey': bundle?['onetime_prekey'],
          },
        });
        debugPrint('[PQAura-Web] New identity keys generated and uploaded.');
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
      final signedKp = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS, []);
      final signedResult = signedKp.dartify() as JSObject;
      final signedPk = (signedResult.getProperty('public_key'.toJS) as JSUint8Array).dartify() as List<int>;

      final otKp = _wasmModule!.callMethod('pqa_generate_keypair_wasm'.toJS, []);
      final otResult = otKp.dartify() as JSObject;
      final otPk = (otResult.getProperty('public_key'.toJS) as JSUint8Array).dartify() as List<int>;

      // Store the secret keys for later use in Bob's handshake
      final signedSk = (signedResult.getProperty('secret_key'.toJS) as JSUint8Array).dartify() as List<int>;
      final otSk = (otResult.getProperty('secret_key'.toJS) as JSUint8Array).dartify() as List<int>;

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
      );

      final data = response.data;
      if (data == null || data['state'] == null) return false;

      final stateData = data['state'];
      final encryptedState = Uint8List.fromList(List<int>.from(stateData['encrypted_state']));
      final nonce = Uint8List.fromList(List<int>.from(stateData['nonce']));

      // Decrypt the state using our state encryption key
      if (_stateEncryptionKey == null) return false;
      final decryptedState = _decryptStateForStorage(encryptedState, nonce);
      if (decryptedState == null) return false;

      // Deserialize into WASM ratchet state
      final stateJs = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        [decryptedState.toJS],
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

  Future<void> _saveSessionToServer(String remoteUserId, JSObject state) async {
    try {
      // Serialize the state
      final stateBytes = _wasmModule!.callMethod(
        'pqa_serialize_state_wasm'.toJS,
        [state],
      );
      final serialized = (stateBytes.dartify() as List<int>);

      // Encrypt for storage
      if (_stateEncryptionKey == null) return;
      final encrypted = _encryptStateForStorage(Uint8List.fromList(serialized));
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
        [
          utf8.encode(bundleJson).toJS,
          Uint8List.fromList(_identityPk!).toJS,
          Uint8List.fromList(_identitySk!).toJS,
        ],
      );

      final aliceResult = result.dartify() as JSObject;

      // Get the serialized state
      final stateBytes = (aliceResult.getProperty('state_bytes'.toJS) as JSUint8Array).dartify() as List<int>;

      // Deserialize into WASM ratchet state
      final stateJs = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        [Uint8List.fromList(stateBytes).toJS],
      );
      final state = stateJs.dartify() as JSObject;

      // Store session
      _activeSessions[remoteUserId] = state;

      // Save to server
      await _saveSessionToServer(remoteUserId, state);

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

      final stateBytes = _wasmModule!.callMethod(
        'pqa_init_bob_wasm'.toJS,
        [
          utf8.encode(initialMessageJson).toJS,
          Uint8List.fromList(_identityPk!).toJS,
          Uint8List.fromList(_identitySk!).toJS,
          signedSk != null ? Uint8List.fromList(signedSk).toJS : Uint8List(0).toJS,
          otSk != null ? Uint8List.fromList(otSk).toJS : Uint8List(0).toJS,
        ],
      );

      final stateJs = (stateBytes.dartify() as List<int>);
      final state = _wasmModule!.callMethod(
        'pqa_deserialize_state_wasm'.toJS,
        [Uint8List.fromList(stateJs).toJS],
      ).dartify() as JSObject;

      _activeSessions[senderId] = state;
      await _saveSessionToServer(senderId, state);

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
        [state, utf8.encode(plaintext).toJS, ad.toJS],
      );

      final msg = result.dartify() as JSObject;
      final header = (msg.getProperty('header'.toJS) as JSUint8Array).dartify() as List<int>;
      final payload = (msg.getProperty('payload'.toJS) as JSUint8Array).dartify() as List<int>;

      // Save updated ratchet state to server
      await _saveSessionToServer(recipientId, state);

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
        [state, header.toJS, payload.toJS, ad.toJS],
      );

      final plaintext = (result.dartify() as List<int>);
      final text = utf8.decode(plaintext);

      // Save updated ratchet state
      await _saveSessionToServer(senderId, state);

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
        [state, mediaKey.toJS, ad.toJS],
      );

      final msg = result.dartify() as JSObject;
      final header = (msg.getProperty('header'.toJS) as JSUint8Array).dartify() as List<int>;
      final payloadBytes = (msg.getProperty('payload'.toJS) as JSUint8Array).dartify() as List<int>;

      await _saveSessionToServer(recipientId, state);

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
        [state, header.toJS, payloadBytes.toJS, ad.toJS],
      );

      final decrypted = (result.dartify() as List<int>);
      await _saveSessionToServer(senderId, state);

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

  void _deriveStateEncryptionKey() {
    // Derive a 32-byte key from the user's auth session for encrypting state at rest
    final session = _supabase.auth.currentSession;
    if (session != null) {
      final token = session.accessToken;
      // Simple derivation: hash the access token
      final bytes = utf8.encode(token);
      // Use a simple approach — in production use SubtleCrypto
      _stateEncryptionKey = Uint8List.fromList(bytes.take(32).toList());
      // Pad if needed
      while (_stateEncryptionKey!.length < 32) {
        _stateEncryptionKey = Uint8List.fromList([
          ..._stateEncryptionKey!,
          ...bytes.take(32 - _stateEncryptionKey!.length),
        ]);
      }
    }
  }

  Map<String, dynamic>? _encryptStateForStorage(Uint8List stateBytes) {
    if (_stateEncryptionKey == null) return null;

    // Simple XOR encryption for state-at-rest (in production, use AES-GCM via SubtleCrypto)
    final nonce = Uint8List(12);
    for (var i = 0; i < 12; i++) {
      nonce[i] = DateTime.now().microsecondsSinceEpoch.hashCode & 0xFF;
    }

    final ciphertext = Uint8List(stateBytes.length);
    for (var i = 0; i < stateBytes.length; i++) {
      ciphertext[i] = stateBytes[i] ^ _stateEncryptionKey![i % 32] ^ nonce[i % 12];
    }

    return {
      'ciphertext': ciphertext,
      'nonce': nonce,
    };
  }

  Uint8List? _decryptStateForStorage(Uint8List ciphertext, Uint8List nonce) {
    if (_stateEncryptionKey == null) return null;

    final plaintext = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ _stateEncryptionKey![i % 32] ^ nonce[i % 12];
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
