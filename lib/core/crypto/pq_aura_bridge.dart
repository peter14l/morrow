import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';

/// FFI bindings to the PQ-Aura Rust library.
/// Provides post-quantum resistant encryption using hybrid X25519 + ML-KEM-1024.

typedef PqaGenerateKeypairNative = Pointer<FfiKeyPair> Function();
typedef PqaGenerateKeypairDart = Pointer<FfiKeyPair> Function();

typedef PqaFreeKeypairNative = Void Function(Pointer<FfiKeyPair>);
typedef PqaFreeKeypairDart = void Function(Pointer<FfiKeyPair>);

typedef PqaCreateBundleNative =
    Pointer<FfiPreKeyBundle> Function(Pointer<Uint8>, IntPtr);
typedef PqaCreateBundleDart =
    Pointer<FfiPreKeyBundle> Function(Pointer<Uint8>, int);

typedef PqaFreeBundleNative = Void Function(Pointer<FfiPreKeyBundle>);
typedef PqaFreeBundleDart = void Function(Pointer<FfiPreKeyBundle>);

typedef PqaInitAliceNative =
    Pointer<FfiInitialMessage> Function(
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
    );
typedef PqaInitAliceDart =
    Pointer<FfiInitialMessage> Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
    );

typedef PqaInitBobNative =
    Pointer<RatchetState> Function(
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Bool,
    );
typedef PqaInitBobDart =
    Pointer<RatchetState> Function(
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      bool,
    );

typedef PqaEncryptNative =
    Pointer<FfiMessage> Function(
      Pointer<RatchetState>,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
    );
typedef PqaEncryptDart =
    Pointer<FfiMessage> Function(
      Pointer<RatchetState>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
    );

typedef PqaDecryptNative =
    Pointer<Uint8> Function(
      Pointer<RatchetState>,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<Uint8>,
      IntPtr,
      Pointer<IntPtr>,
    );
typedef PqaDecryptDart =
    Pointer<Uint8> Function(
      Pointer<RatchetState>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<IntPtr>,
    );

typedef PqaSerializeStateNative =
    Pointer<Uint8> Function(Pointer<RatchetState>);
typedef PqaSerializeStateDart = Pointer<Uint8> Function(Pointer<RatchetState>);

typedef PqaSerializeStateLenNative = IntPtr Function(Pointer<RatchetState>);
typedef PqaSerializeStateLenDart = int Function(Pointer<RatchetState>);

typedef PqaDeserializeStateNative =
    Pointer<RatchetState> Function(Pointer<Uint8>, IntPtr);
typedef PqaDeserializeStateDart =
    Pointer<RatchetState> Function(Pointer<Uint8>, int);

typedef PqaFreeStateNative = Void Function(Pointer<RatchetState>);
typedef PqaFreeStateDart = void Function(Pointer<RatchetState>);

typedef PqaFreeMessageNative = Void Function(Pointer<FfiMessage>);
typedef PqaFreeMessageDart = void Function(Pointer<FfiMessage>);

typedef PqaFreeBufferNative = Void Function(Pointer<Uint8>, IntPtr);
typedef PqaFreeBufferDart = void Function(Pointer<Uint8>, int);

typedef PqaFreeInitialMessageNative = Void Function(Pointer<FfiInitialMessage>);
typedef PqaFreeInitialMessageDart = void Function(Pointer<FfiInitialMessage>);

typedef PqaSaveAtomicNative =
    Bool Function(Pointer<RatchetState>, Pointer<Utf8>, Pointer<Uint8>);
typedef PqaSaveAtomicDart =
    bool Function(Pointer<RatchetState>, Pointer<Utf8>, Pointer<Uint8>);

typedef PqaLoadAtomicNative =
    Pointer<RatchetState> Function(Pointer<Utf8>, Pointer<Uint8>);
typedef PqaLoadAtomicDart =
    Pointer<RatchetState> Function(Pointer<Utf8>, Pointer<Uint8>);

/// FFI Structures matching Rust FFI types

final class FfiKeyPair extends Struct {
  external Pointer<Uint8> public_key;
  @IntPtr()
  external int public_key_len;
  external Pointer<Uint8> secret_key;
  @IntPtr()
  external int secret_key_len;
}

final class FfiPreKeyBundle extends Struct {
  external Pointer<Uint8> identity_pk;
  @IntPtr()
  external int identity_pk_len;
  external Pointer<Uint8> signed_pre_key;
  @IntPtr()
  external int signed_pre_key_len;
  external Pointer<Uint8> one_time_pre_key;
  @IntPtr()
  external int one_time_pre_key_len;
  @Bool()
  external bool has_one_time;
}

final class FfiInitialMessage extends Struct {
  external Pointer<RatchetState> state_ptr;
  external Pointer<Uint8> alice_identity_pk;
  @IntPtr()
  external int alice_identity_pk_len;
  external Pointer<Uint8> ephemeral_pk;
  @IntPtr()
  external int ephemeral_pk_len;
  external Pointer<Uint8> kem_ciphertext_identity;
  @IntPtr()
  external int kem_ciphertext_identity_len;
  external Pointer<Uint8> kem_ciphertext_signed;
  @IntPtr()
  external int kem_ciphertext_signed_len;
  external Pointer<Uint8> kem_ciphertext_one_time;
  @IntPtr()
  external int kem_ciphertext_one_time_len;
  @Bool()
  external bool has_one_time;
  external Pointer<Uint8> ratchet_message_header;
  @IntPtr()
  external int ratchet_message_header_len;
  external Pointer<Uint8> ratchet_message_payload;
  @IntPtr()
  external int ratchet_message_payload_len;
}

final class RatchetState extends Struct {
  @Uint8()
  external int dummy; // Dart FFI doesn't allow empty structs
}

final class FfiMessage extends Struct {
  external Pointer<Uint8> header;
  @IntPtr()
  external int header_len;
  external Pointer<Uint8> payload;
  @IntPtr()
  external int payload_len;
}

/// PQ-Aura FFI Bridge
class PQAuraBridge {
  static PQAuraBridge? _instance;
  late final DynamicLibrary _lib;
  bool _isLoaded = false;

  // Function pointers
  late final PqaGenerateKeypairDart _pqaGenerateKeypair;
  late final PqaFreeKeypairDart _pqaFreeKeypair;
  late final PqaCreateBundleDart _pqaCreateBundle;
  late final PqaFreeBundleDart _pqaFreeBundle;
  late final PqaInitAliceDart _pqaInitAlice;
  late final PqaInitBobDart _pqaInitBob;
  late final PqaEncryptDart _pqaEncrypt;
  late final PqaDecryptDart _pqaDecrypt;
  late final PqaSerializeStateDart _pqaSerializeState;
  late final PqaSerializeStateLenDart _pqaSerializeStateLen;
  late final PqaDeserializeStateDart _pqaDeserializeState;
  late final PqaFreeStateDart _pqaFreeState;
  late final PqaFreeMessageDart _pqaFreeMessage;
  late final PqaFreeBufferDart _pqaFreeBuffer;
  late final PqaFreeInitialMessageDart _pqaFreeInitialMessage;
  late final PqaSaveAtomicDart _pqaSaveAtomic;
  late final PqaLoadAtomicDart _pqaLoadAtomic;

  PQAuraBridge._();

  static PQAuraBridge get instance {
    _instance ??= PQAuraBridge._();
    return _instance!;
  }

  /// Initialize the FFI bridge by loading the native library
  bool load() {
    if (_isLoaded) return true;

    try {
      if (Platform.isAndroid) {
        debugPrint('[PQAuraBridge] Loading libpq_aura.so for Android...');
        _lib = DynamicLibrary.open('libpq_aura.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        debugPrint('[PQAuraBridge] Initializing Windows library search...');
        final possiblePaths = [
          'windows/libs/pq_aura.dll',
          'pq_aura.dll',
          'PQ-DR/target/release/pq_aura.dll',
          'PQ-DR/target/debug/pq_aura.dll',
        ];

        bool loaded = false;
        for (final path in possiblePaths) {
          try {
            if (path == 'pq_aura.dll' || File(path).existsSync()) {
              debugPrint('[PQAuraBridge] Attempting to load: $path');
              _lib = DynamicLibrary.open(path);
              loaded = true;
              debugPrint('[PQAuraBridge] SUCCESS: Loaded library from $path');
              break;
            }
          } catch (e) {
            debugPrint('[PQAuraBridge] Failed to load from $path: $e');
          }
        }
        if (!loaded) return false;
      } else if (Platform.isMacOS) {
        debugPrint('[PQAuraBridge] Initializing macOS library search...');
        final possiblePaths = [
          'libpq_aura.dylib',
          'macos/libs/libpq_aura.dylib',
          'PQ-DR/target/release/libpq_aura.dylib',
          'PQ-DR/target/debug/libpq_aura.dylib',
          // Standard macOS app bundle structure
          '../Frameworks/libpq_aura.dylib',
        ];

        bool loaded = false;
        for (final path in possiblePaths) {
          try {
            if (path == 'libpq_aura.dylib' || File(path).existsSync()) {
              debugPrint('[PQAuraBridge] Attempting to load: $path');
              _lib = DynamicLibrary.open(path);
              loaded = true;
              debugPrint('[PQAuraBridge] SUCCESS: Loaded library from $path');
              break;
            }
          } catch (e) {
            debugPrint('[PQAuraBridge] Failed to load from $path: $e');
          }
        }
        if (!loaded) return false;
      } else {
        debugPrint(
          '[PQAuraBridge] Unsupported platform: ${Platform.operatingSystem}',
        );
        return false;
      }

      _bindFunctions();
      _isLoaded = true;
      debugPrint('[PQAuraBridge] Native library loaded successfully');
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PQAuraBridge] Note: Native library not loaded: $e');
        debugPrint(
          '[PQAuraBridge] Post-quantum features will be disabled. This is normal if you haven\'t built the Rust library locally.',
        );
      }
      return false;
    }
  }

  void _bindFunctions() {
    _pqaGenerateKeypair = _lib
        .lookup<NativeFunction<PqaGenerateKeypairNative>>(
          'pqa_generate_keypair',
        )
        .asFunction();

    _pqaFreeKeypair = _lib
        .lookup<NativeFunction<PqaFreeKeypairNative>>('pqa_free_keypair')
        .asFunction();

    _pqaCreateBundle = _lib
        .lookup<NativeFunction<PqaCreateBundleNative>>('pqa_create_bundle')
        .asFunction();

    _pqaFreeBundle = _lib
        .lookup<NativeFunction<PqaFreeBundleNative>>('pqa_free_bundle')
        .asFunction();

    _pqaInitAlice = _lib
        .lookup<NativeFunction<PqaInitAliceNative>>('pqa_init_alice')
        .asFunction();

    _pqaInitBob = _lib
        .lookup<NativeFunction<PqaInitBobNative>>('pqa_init_bob')
        .asFunction();

    _pqaEncrypt = _lib
        .lookup<NativeFunction<PqaEncryptNative>>('pqa_encrypt')
        .asFunction();

    _pqaDecrypt = _lib
        .lookup<NativeFunction<PqaDecryptNative>>('pqa_decrypt')
        .asFunction();

    _pqaSerializeState = _lib
        .lookup<NativeFunction<PqaSerializeStateNative>>('pqa_serialize_state')
        .asFunction();

    _pqaSerializeStateLen = _lib
        .lookup<NativeFunction<PqaSerializeStateLenNative>>(
          'pqa_serialize_state_len',
        )
        .asFunction();

    _pqaDeserializeState = _lib
        .lookup<NativeFunction<PqaDeserializeStateNative>>(
          'pqa_deserialize_state',
        )
        .asFunction();

    _pqaFreeState = _lib
        .lookup<NativeFunction<PqaFreeStateNative>>('pqa_free_state')
        .asFunction();

    _pqaFreeMessage = _lib
        .lookup<NativeFunction<PqaFreeMessageNative>>('pqa_free_message')
        .asFunction();

    _pqaFreeBuffer = _lib
        .lookup<NativeFunction<PqaFreeBufferNative>>('pqa_free_buffer')
        .asFunction();

    _pqaFreeInitialMessage = _lib
        .lookup<NativeFunction<PqaFreeInitialMessageNative>>(
          'pqa_free_initial_message',
        )
        .asFunction();

    _pqaSaveAtomic = _lib
        .lookup<NativeFunction<PqaSaveAtomicNative>>('pqa_save_atomic')
        .asFunction();

    _pqaLoadAtomic = _lib
        .lookup<NativeFunction<PqaLoadAtomicNative>>('pqa_load_atomic')
        .asFunction();
  }

  Pointer<Uint8> _mallocBytes(List<int> bytes) {
    final ptr = calloc<Uint8>(bytes.length);
    final list = ptr.asTypedList(bytes.length);
    list.setAll(0, bytes);
    return ptr;
  }

  /// Generate a new hybrid keypair
  PQAuraKeyPair? generateKeypair() {
    if (!_isLoaded) return null;

    final result = _pqaGenerateKeypair();
    if (result == nullptr) return null;

    // result is Pointer<FfiKeyPair>
    final kp = result;
    final pkLen = kp.ref.public_key_len;
    final skLen = kp.ref.secret_key_len;

    debugPrint(
      '[PQAuraBridge] Keypair generated. PK len: $pkLen, SK len: $skLen',
    );

    final publicKey = kp.ref.public_key.asTypedList(pkLen).toList();
    final secretKey = kp.ref.secret_key.asTypedList(skLen).toList();

    return PQAuraKeyPair(
      publicKey: publicKey,
      secretKey: secretKey,
      nativePtr: result,
    );
  }

  /// Create a PreKeyBundle from an identity public key
  PQAuraPreKeyBundle? createBundle(List<int> identityPk) {
    if (!_isLoaded) return null;

    final pkPtr = _mallocBytes(identityPk);
    final result = _pqaCreateBundle(pkPtr, identityPk.length);
    calloc.free(pkPtr);

    if (result == nullptr) return null;

    final bundle = result.ref;
    final identityPkBytes = bundle.identity_pk
        .asTypedList(bundle.identity_pk_len)
        .toList();
    final signedPreKey = bundle.signed_pre_key
        .asTypedList(bundle.signed_pre_key_len)
        .toList();
    final oneTimePreKey = bundle.has_one_time
        ? bundle.one_time_pre_key
              .asTypedList(bundle.one_time_pre_key_len)
              .toList()
        : null;

    return PQAuraPreKeyBundle(
      identityPk: identityPkBytes,
      signedPreKey: signedPreKey,
      oneTimePreKey: oneTimePreKey,
      nativePtr: result,
    );
  }

  /// Initiate a session as Alice (initiator)
  PQAuraInitialMessage? initAlice({
    required List<int> remoteBundle,
    required List<int> localIdentityPk,
    required List<int> localIdentitySk,
  }) {
    if (!_isLoaded) return null;

    final bundlePtr = _mallocBytes(remoteBundle);
    final localPkPtr = _mallocBytes(localIdentityPk);
    final localSkPtr = _mallocBytes(localIdentitySk);

    final result = _pqaInitAlice(
      bundlePtr,
      remoteBundle.length,
      localPkPtr,
      localIdentityPk.length,
      localSkPtr,
      localIdentitySk.length,
    );

    calloc.free(bundlePtr);
    calloc.free(localPkPtr);
    calloc.free(localSkPtr);

    if (result == nullptr) return null;

    final msg = result.ref;
    final statePtr = msg.state_ptr;
    final aliceIdentityPk = msg.alice_identity_pk
        .asTypedList(msg.alice_identity_pk_len)
        .toList();
    final ephemeralPk = msg.ephemeral_pk
        .asTypedList(msg.ephemeral_pk_len)
        .toList();
    final kemIdentity = msg.kem_ciphertext_identity
        .asTypedList(msg.kem_ciphertext_identity_len)
        .toList();
    final kemSigned = msg.kem_ciphertext_signed
        .asTypedList(msg.kem_ciphertext_signed_len)
        .toList();
    final kemOneTime = msg.has_one_time
        ? msg.kem_ciphertext_one_time
              .asTypedList(msg.kem_ciphertext_one_time_len)
              .toList()
        : null;
    final ratchetHeader = msg.ratchet_message_header
        .asTypedList(msg.ratchet_message_header_len)
        .toList();
    final ratchetPayload = msg.ratchet_message_payload
        .asTypedList(msg.ratchet_message_payload_len)
        .toList();

    return PQAuraInitialMessage(
      statePtr: statePtr,
      aliceIdentityPk: aliceIdentityPk,
      ephemeralPk: ephemeralPk,
      kemCiphertextIdentity: kemIdentity,
      kemCiphertextSigned: kemSigned,
      kemCiphertextOneTime: kemOneTime,
      ratchetMessageHeader: ratchetHeader,
      ratchetMessagePayload: ratchetPayload,
      nativePtr: result,
    );
  }

  /// Respond as Bob (receiver) to an initial message
  Pointer<RatchetState>? initBob({
    required List<int> initialMessage,
    required List<int> localIdentityPk,
    required List<int> localIdentitySk,
    required List<int> localSignedSk,
    List<int>? localOtSk,
  }) {
    if (!_isLoaded) return null;

    final msgPtr = _mallocBytes(initialMessage);
    final localPkPtr = _mallocBytes(localIdentityPk);
    final localSkPtr = _mallocBytes(localIdentitySk);
    final signedSkPtr = _mallocBytes(localSignedSk);
    Pointer<Uint8>? otSkPtr;
    if (localOtSk != null) {
      otSkPtr = _mallocBytes(localOtSk);
    }

    final result = _pqaInitBob(
      msgPtr,
      initialMessage.length,
      localPkPtr,
      localIdentityPk.length,
      localSkPtr,
      localIdentitySk.length,
      signedSkPtr,
      localSignedSk.length,
      otSkPtr ?? nullptr,
      localOtSk?.length ?? 0,
      localOtSk != null,
    );

    calloc.free(msgPtr);
    calloc.free(localPkPtr);
    calloc.free(localSkPtr);
    calloc.free(signedSkPtr);
    if (otSkPtr != null) calloc.free(otSkPtr);

    if (result == nullptr) return null;
    return result;
  }

  /// Encrypt a message
  PQAuraMessage? encrypt(
    Pointer<RatchetState> state,
    List<int> plaintext,
    List<int> ad,
  ) {
    if (!_isLoaded) return null;

    final plaintextPtr = _mallocBytes(plaintext);
    final adPtr = _mallocBytes(ad);

    final result = _pqaEncrypt(
      state,
      plaintextPtr,
      plaintext.length,
      adPtr,
      ad.length,
    );

    calloc.free(plaintextPtr);
    calloc.free(adPtr);

    if (result == nullptr) return null;

    final msg = result.ref;
    final header = msg.header.asTypedList(msg.header_len).toList();
    final payload = msg.payload.asTypedList(msg.payload_len).toList();

    return PQAuraMessage(header: header, payload: payload, nativePtr: result);
  }

  /// Decrypt a message
  List<int>? decrypt(
    Pointer<RatchetState> state,
    List<int> header,
    List<int> payload,
    List<int> ad,
  ) {
    if (!_isLoaded) return null;

    final headerPtr = _mallocBytes(header);
    final payloadPtr = _mallocBytes(payload);
    final adPtr = _mallocBytes(ad);
    final outLenPtr = calloc<IntPtr>();

    final result = _pqaDecrypt(
      state,
      headerPtr,
      header.length,
      payloadPtr,
      payload.length,
      adPtr,
      ad.length,
      outLenPtr,
    );

    calloc.free(headerPtr);
    calloc.free(payloadPtr);
    calloc.free(adPtr);

    if (result == nullptr) {
      calloc.free(outLenPtr);
      return null;
    }

    final plaintext = result.asTypedList(outLenPtr.value).toList();
    _pqaFreeBuffer(result, outLenPtr.value);
    calloc.free(outLenPtr);

    return plaintext;
  }

  /// Serialize the ratchet state for persistence
  List<int>? serializeState(Pointer<RatchetState> state) {
    if (!_isLoaded) return null;

    final serialized = _pqaSerializeState(state);
    if (serialized == nullptr) return null;

    // Get the length first
    final len = _pqaSerializeStateLen(state);
    final data = serialized.asTypedList(len).toList();
    _pqaFreeBuffer(serialized, len);
    return data;
  }

  /// Deserialize the ratchet state
  Pointer<RatchetState>? deserializeState(List<int> data) {
    if (!_isLoaded) return null;

    final dataPtr = _mallocBytes(data);
    final result = _pqaDeserializeState(dataPtr, data.length);
    calloc.free(dataPtr);

    return result;
  }

  /// Free the ratchet state
  void freeState(Pointer<RatchetState> state) {
    if (!_isLoaded || state == nullptr) return;
    _pqaFreeState(state);
  }

  /// Free a message
  void freeMessage(Pointer<FfiMessage> msg) {
    if (!_isLoaded || msg == nullptr) return;
    _pqaFreeMessage(msg);
  }

  /// Free a buffer
  void freeBuffer(Pointer<Uint8> buffer, int length) {
    if (!_isLoaded || buffer == nullptr) return;
    _pqaFreeBuffer(buffer, length);
  }

  /// Free an initial message
  void freeInitialMessage(Pointer<FfiInitialMessage> msg) {
    if (!_isLoaded || msg == nullptr) return;
    _pqaFreeInitialMessage(msg);
  }

  /// Free a keypair
  void freeKeypair(Pointer<FfiKeyPair> kp) {
    if (!_isLoaded || kp == nullptr) return;
    _pqaFreeKeypair(kp);
  }

  /// Free a bundle
  void freeBundle(Pointer<FfiPreKeyBundle> bundle) {
    if (!_isLoaded || bundle == nullptr) return;
    _pqaFreeBundle(bundle);
  }

  /// Atomically save the ratchet state to a file
  bool saveStateAtomic(
    Pointer<RatchetState> state,
    String path,
    List<int> encryptionKey,
  ) {
    if (!_isLoaded) return false;

    final pathPtr = path.toNativeUtf8();
    final keyPtr = _mallocBytes(encryptionKey);

    final result = _pqaSaveAtomic(state, pathPtr, keyPtr);

    calloc.free(pathPtr);
    calloc.free(keyPtr);

    return result;
  }

  /// Load the ratchet state from an atomically saved file
  Pointer<RatchetState>? loadStateAtomic(String path, List<int> encryptionKey) {
    if (!_isLoaded) return null;

    final pathPtr = path.toNativeUtf8();
    final keyPtr = _mallocBytes(encryptionKey);

    final result = _pqaLoadAtomic(pathPtr, keyPtr);

    calloc.free(pathPtr);
    calloc.free(keyPtr);

    if (result == nullptr) return null;
    return result;
  }
}

/// Helper class for key pair data
class PQAuraKeyPair {
  final List<int> publicKey;
  final List<int> secretKey;
  final Pointer<FfiKeyPair> nativePtr;

  PQAuraKeyPair({
    required this.publicKey,
    required this.secretKey,
    required this.nativePtr,
  });
}

/// Helper class for pre-key bundle data
class PQAuraPreKeyBundle {
  final List<int> identityPk;
  final List<int> signedPreKey;
  final List<int>? oneTimePreKey;
  final Pointer<FfiPreKeyBundle> nativePtr;

  PQAuraPreKeyBundle({
    required this.identityPk,
    required this.signedPreKey,
    this.oneTimePreKey,
    required this.nativePtr,
  });
}

/// Helper class for initial message data
class PQAuraInitialMessage {
  final Pointer<RatchetState> statePtr;
  final List<int> aliceIdentityPk;
  final List<int> ephemeralPk;
  final List<int> kemCiphertextIdentity;
  final List<int> kemCiphertextSigned;
  final List<int>? kemCiphertextOneTime;
  final List<int> ratchetMessageHeader;
  final List<int> ratchetMessagePayload;
  final Pointer<FfiInitialMessage> nativePtr;

  PQAuraInitialMessage({
    required this.statePtr,
    required this.aliceIdentityPk,
    required this.ephemeralPk,
    required this.kemCiphertextIdentity,
    required this.kemCiphertextSigned,
    this.kemCiphertextOneTime,
    required this.ratchetMessageHeader,
    required this.ratchetMessagePayload,
    required this.nativePtr,
  });
}

/// Helper class for encrypted message
class PQAuraMessage {
  final List<int> header;
  final List<int> payload;
  final Pointer<FfiMessage> nativePtr;

  PQAuraMessage({
    required this.header,
    required this.payload,
    required this.nativePtr,
  });
}
