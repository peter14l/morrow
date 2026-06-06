import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Web implementation of PQAuraService.
///
/// On web, PQ-Aura runs as a WebAssembly (WASM) module compiled from Rust
/// via `wasm-pack build --target web`. The WASM is loaded by web/index.html
/// before Flutter starts, and exposed as `window._pqAuraWasm`.
///
/// If the WASM module is absent (e.g. dev builds without a WASM artifact),
/// all methods return null/false and the app falls back to RSA/Signal.
///
/// To build the WASM:
///   cd PQ-DR
///   wasm-pack build --target web --out-dir ../web/pkg --release
class PQAuraService {
  static PQAuraService? _instance;

  PQAuraService._();

  static PQAuraService get instance {
    _instance ??= PQAuraService._();
    return _instance!;
  }

  bool _wasmReady = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  bool get isReady => _wasmReady;

  Future<bool> init() async {
    try {
      // Check if the WASM loader in index.html has finished
      final ready = globalContext.getProperty<JSBoolean?>(
        '_pqAuraWasmReady'.toJS,
      );
      _wasmReady = ready?.toDart ?? false;
      if (_wasmReady) {
        debugPrint('[PQAura-Web] WASM module is ready.');
      } else {
        debugPrint(
          '[PQAura-Web] WASM not available — using fallback encryption.',
        );
      }
      return _wasmReady;
    } catch (e) {
      debugPrint('[PQAura-Web] init error: $e');
      return false;
    }
  }

  bool hasSession(String remoteUserId) => false; // Sessions live server-side

  Future<void> clearAllData() async {
    _wasmReady = false;
    _instance = null;
  }

  // ---------------------------------------------------------------------------
  // Session management (no-op on web — handshake is server-mediated)
  // ---------------------------------------------------------------------------

  Future<bool> getOrCreateSession(String remoteUserId) async => false;

  Future<bool> loadSession(String remoteUserId) async => false;

  void closeSession(String remoteUserId) {}

  Future<void> deleteSession(String remoteUserId) async {}

  // ---------------------------------------------------------------------------
  // Encryption / Decryption
  //
  // When the WASM is present, these call JS functions exposed by wasm-bindgen:
  //   pqa_encrypt_wasm(state, plaintext, ad) -> WasmMessage
  //   pqa_decrypt_wasm(state, header, payload, ad) -> Uint8Array | Error
  //
  // Because the Double Ratchet state is per-session and stateful, web clients
  // need a server-side proxy for stateful ratchet operations. Until that proxy
  // is implemented, we return null so the app falls back to RSA/Signal.
  // ---------------------------------------------------------------------------

  Future<PQAuraEncryptedMessage?> encryptMessage(
    String recipientId,
    String plaintext,
  ) async {
    if (!_wasmReady) return null;
    // TODO: Call server-side PQ-Aura proxy to perform stateful encryption.
    // The WASM module exposes stateless helpers; the ratchet state must live
    // server-side for web clients.
    debugPrint('[PQAura-Web] Stateful WASM encryption not yet wired up.');
    return null;
  }

  Future<Map<String, String>?> encryptMediaKey(
    String recipientId,
    Uint8List mediaKey,
  ) async {
    if (!_wasmReady) return null;
    return null;
  }

  Future<Map<String, String>?> encryptGroupMediaKey(
    List<String> recipientIds,
    Uint8List mediaKey,
  ) async {
    if (!_wasmReady) return null;
    return null;
  }

  Future<Uint8List?> decryptMediaKey(
    String senderId,
    Map<String, dynamic> encryptionData,
  ) async {
    if (!_wasmReady) return null;
    return null;
  }

  Future<Map<String, String>?> encryptGroupMessage(
    List<String> participantIds,
    String plaintext,
  ) async {
    if (!_wasmReady) return null;
    return null;
  }

  Future<String?> decryptMessage(
    String senderId,
    Uint8List header,
    Uint8List payload,
  ) async {
    if (!_wasmReady) return null;
    return null;
  }
}

class PQAuraEncryptedMessage {
  final Uint8List header;
  final Uint8List payload;

  PQAuraEncryptedMessage({required this.header, required this.payload});

  Map<String, dynamic> toJson() => {'header': '', 'payload': ''};

  factory PQAuraEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return PQAuraEncryptedMessage(
      header: Uint8List(0),
      payload: Uint8List(0),
    );
  }
}
