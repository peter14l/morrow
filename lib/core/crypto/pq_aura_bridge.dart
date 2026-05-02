import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// FFI bindings to the PQ-Aura Rust library.
/// Provides post-quantum resistant encryption using hybrid X25519 + ML-KEM-1024.

typedef PqaGenerateKeypairNative = Pointer<Pointer<FfiKeyPair>> Function();
typedef PqaGenerateKeypairDart = Pointer<Pointer<FfiKeyPair>> Function();

typedef PqaFreeKeypairNative = Void Function(Pointer<FfiKeyPair>);
typedef PqaFreeKeypairDart = void Function(Pointer<FfiKeyPair>);

typedef PqaCreateBundleNative = Pointer<FfiPreKeyBundle> Function(Pointer<Uint8>, IntPtr);
typedef PqaCreateBundleDart = Pointer<FfiPreKeyBundle> Function(Pointer<Uint8>, int);

typedef PqaFreeBundleNative = Void Function(Pointer<FfiPreKeyBundle>);
typedef PqaFreeBundleDart = void Function(Pointer<FfiPreKeyBundle>);

typedef PqaInitAliceNative = Pointer<FfiInitialMessage> Function(
    Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr);
typedef PqaInitAliceDart = Pointer<FfiInitialMessage> Function(
    Pointer<Uint8>, int, Pointer<Uint8>, int, Pointer<Uint8>, int);

typedef PqaInitBobNative = Pointer<RatchetState> Function(
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Bool);
typedef PqaInitBobDart = Pointer<RatchetState> Function(
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    bool);

typedef PqaEncryptNative = Pointer<FfiMessage> Function(
    Pointer<RatchetState>, Pointer<Uint8>, IntPtr, Pointer<Uint8>, IntPtr);
typedef PqaEncryptDart = Pointer<FfiMessage> Function(
    Pointer<RatchetState>, Pointer<Uint8>, int, Pointer<Uint8>, int);

typedef PqaDecryptNative = Pointer<Uint8> Function(
    Pointer<RatchetState>,
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Pointer<Uint8>, IntPtr,
    Pointer<IntPtr>);
typedef PqaDecryptDart = Pointer<Uint8> Function(
    Pointer<RatchetState>,
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    Pointer<Uint8>, int,
    Pointer<IntPtr>);

typedef PqaSerializeStateNative = Pointer<Uint8> Function(Pointer<RatchetState>);
typedef PqaSerializeStateDart = Pointer<Uint8> Function(Pointer<RatchetState>);

typedef PqaSerializeStateLenNative = IntPtr Function(Pointer<RatchetState>);
typedef PqaSerializeStateLenDart = int Function(Pointer<RatchetState>);

typedef PqaDeserializeStateNative = Pointer<RatchetState> Function(Pointer<Uint8>, IntPtr);
typedef PqaDeserializeStateDart = Pointer<RatchetState> Function(Pointer<Uint8>, int);

typedef PqaFreeStateNative = Void Function(Pointer<RatchetState>);
typedef PqaFreeStateDart = void Function(Pointer<RatchetState>);

typedef PqaFreeMessageNative = Void Function(Pointer<FfiMessage>);
typedef PqaFreeMessageDart = void Function(Pointer<FfiMessage>);

typedef PqaFreeBufferNative = Void Function(Pointer<Uint8>, IntPtr);
typedef PqaFreeBufferDart = void Function(Pointer<Uint8>, int);

typedef PqaFreeInitialMessageNative = Void Function(Pointer<FfiInitialMessage>);
typedef PqaFreeInitialMessageDart = void Function(Pointer<FfiInitialMessage>);

/// FFI Structures matching Rust FFI types
final class FfiKeyPair extends Struct {
  external Pointer<Uint8> publicKey;
  @IntPtr()
  external int publicKeyLen;
  external Pointer<Uint8> secretKey;
  @IntPtr()
  external int secretKeyLen;
}

final class FfiPreKeyBundle extends Struct {
  external Pointer<Uint8> identityPk;
  @IntPtr()
  external int identityPkLen;
  external Pointer<Uint8> signedPreKey;
  @IntPtr()
  external int signedPreKeyLen;
  external Pointer<Uint8> oneTimePreKey;
  @IntPtr()
  external int oneTimePreKeyLen;
  @Bool()
  external bool hasOneTime;
}

final class FfiInitialMessage extends Struct {
  external Pointer<RatchetState> statePtr;
  external Pointer<Uint8> aliceIdentityPk;
  @IntPtr()
  external int aliceIdentityPkLen;
  external Pointer<Uint8> ephemeralPk;
  @IntPtr()
  external int ephemeralPkLen;
  external Pointer<Uint8> kemCiphertextIdentity;
  @IntPtr()
  external int kemCiphertextIdentityLen;
  external Pointer<Uint8> kemCiphertextSigned;
  @IntPtr()
  external int kemCiphertextSignedLen;
  external Pointer<Uint8> kemCiphertextOneTime;
  @IntPtr()
  external int kemCiphertextOneTimeLen;
  @Bool()
  external bool hasOneTime;
  external Pointer<Uint8> ratchetMessageHeader;
  @IntPtr()
  external int ratchetMessageHeaderLen;
  external Pointer<Uint8> ratchetMessagePayload;
  @IntPtr()
  external int ratchetMessagePayloadLen;
}

final class RatchetState extends Struct {
  @Uint8()
  external int dummy; // Dart FFI doesn't allow empty structs
}

final class FfiMessage extends Struct {
  external Pointer<Uint8> header;
  @IntPtr()
  external int header_len;
  external Pointer<Uint8> ratchet_message_payload;
  @IntPtr()
  external int ratchet_message_payload_len;
}

final class FfiKeyPair extends Struct {
  external Pointer<Uint8> public_key;
  @IntPtr()
  external int public_key_len;
  external Pointer<Uint8> secret_key;
  @IntPtr()
  external int secret_key_len;
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
        _lib = DynamicLibrary.open('libpq_aura.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('pq_aura.dll');
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.process();
      } else {
        return false;
      }

      _bindFunctions();
      _isLoaded = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  void _bindFunctions() {
    _pqaGenerateKeypair = _lib
        .lookup<NativeFunction<PqaGenerateKeypairNative>>('pqa_generate_keypair')
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
        .lookup<NativeFunction<PqaSerializeStateLenNative>>('pqa_serialize_state_len')
        .asFunction();

    _pqaDeserializeState = _lib
        .lookup<NativeFunction<PqaDeserializeStateNative>>('pqa_deserialize_state')
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
        .lookup<NativeFunction<PqaFreeInitialMessageNative>>('pqa_free_initial_message')
        .asFunction();
  }

  /// Generate a new hybrid keypair
  PQAuraKeyPair? generateKeypair() {
    if (!_isLoaded) return null;

    final result = _pqaGenerateKeypair();
    if (result == nullptr) return null;

    // result is Pointer<Pointer<FfiKeyPair>>
    final kp = result.value; 
    final publicKey = kp.ref.public_key.asTypedList(kp.ref.public_key_len).toList();
    final secretKey = kp.ref.secret_key.asTypedList(kp.ref.secret_key_len).toList();

    return PQAuraKeyPair(
      publicKey: publicKey,
      secretKey: secretKey,
      nativePtr: kp,
    );
  }

  /// Create a PreKeyBundle from an identity public key
  PQAuraPreKeyBundle? createBundle(List<int> identityPk) {
    if (!_isLoaded) return null;

    final pkPtr = calloc<Uint8>(identityPk.length);
    for (var i = 0; i < identityPk.length; i++) {
      pkPtr[i] = identityPk[i];
    }

    final result = _pqaCreateBundle(pkPtr, identityPk.length);
    calloc.free(pkPtr);

    if (result == nullptr) return null;

    final bundle = result.ref;
    final identityPkBytes = bundle.identity_pk.asTypedList(bundle.identity_pk_len).toList();
    final signedPreKey = bundle.signed_pre_key.asTypedList(bundle.signed_pre_key_len).toList();
    final oneTimePreKey = bundle.has_one_time
        ? bundle.one_time_pre_key.asTypedList(bundle.one_time_pre_key_len).toList()
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

    final bundlePtr = calloc<Uint8>(remoteBundle.length);
    final localPkPtr = calloc<Uint8>(localIdentityPk.length);
    final localSkPtr = calloc<Uint8>(localIdentitySk.length);

    for (var i = 0; i < remoteBundle.length; i++) bundlePtr[i] = remoteBundle[i];
    for (var i = 0; i < localIdentityPk.length; i++) localPkPtr[i] = localIdentityPk[i];
    for (var i = 0; i < localIdentitySk.length; i++) localSkPtr[i] = localIdentitySk[i];

    final result = _pqaInitAlice(
        bundlePtr, remoteBundle.length,
        localPkPtr, localIdentityPk.length,
        localSkPtr, localIdentitySk.length);

    calloc.free(bundlePtr);
    calloc.free(localPkPtr);
    calloc.free(localSkPtr);

    if (result == nullptr) return null;

    final msg = result.ref;
    final statePtr = msg.state_ptr;
    final aliceIdentityPk = msg.alice_identity_pk.asTypedList(msg.alice_identity_pk_len).toList();
    final ephemeralPk = msg.ephemeral_pk.asTypedList(msg.ephemeral_pk_len).toList();
    final kemIdentity = msg.kem_ciphertext_identity.asTypedList(msg.kem_ciphertext_identity_len).toList();
    final kemSigned = msg.kem_ciphertext_signed.asTypedList(msg.kem_ciphertext_signed_len).toList();
    final kemOneTime = msg.has_one_time
        ? msg.kem_ciphertext_one_time.asTypedList(msg.kem_ciphertext_one_time_len).toList()
        : null;
    final ratchetHeader = msg.ratchet_message_header.asTypedList(msg.ratchet_message_header_len).toList();
    final ratchetPayload = msg.ratchet_message_payload.asTypedList(msg.ratchet_message_payload_len).toList();

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

    final msgPtr = calloc<Uint8>(initialMessage.length);
    final localPkPtr = calloc<Uint8>(localIdentityPk.length);
    final localSkPtr = calloc<Uint8>(localIdentitySk.length);
    final signedSkPtr = calloc<Uint8>(localSignedSk.length);
    Pointer<Uint8>? otSkPtr;
    if (localOtSk != null) {
      otSkPtr = calloc<Uint8>(localOtSk.length);
      for (var i = 0; i < localOtSk.length; i++) otSkPtr![i] = localOtSk[i];
    }

    for (var i = 0; i < initialMessage.length; i++) msgPtr[i] = initialMessage[i];
    for (var i = 0; i < localIdentityPk.length; i++) localPkPtr[i] = localIdentityPk[i];
    for (var i = 0; i < localIdentitySk.length; i++) localSkPtr[i] = localIdentitySk[i];
    for (var i = 0; i < localSignedSk.length; i++) signedSkPtr[i] = localSignedSk[i];

    final result = _pqaInitBob(
        msgPtr, initialMessage.length,
        localPkPtr, localIdentityPk.length,
        localSkPtr, localIdentitySk.length,
        signedSkPtr, localSignedSk.length,
        otSkPtr ?? nullptr, localOtSk?.length ?? 0,
        localOtSk != null);

    calloc.free(msgPtr);
    calloc.free(localPkPtr);
    calloc.free(localSkPtr);
    calloc.free(signedSkPtr);
    if (otSkPtr != null) calloc.free(otSkPtr);

    if (result == nullptr) return null;
    return result;
  }

  /// Encrypt a message
  PQAuraMessage? encrypt(Pointer<RatchetState> state, List<int> plaintext, List<int> ad) {
    if (!_isLoaded) return null;

    final plaintextPtr = calloc<Uint8>(plaintext.length);
    final adPtr = calloc<Uint8>(ad.length);

    for (var i = 0; i < plaintext.length; i++) plaintextPtr[i] = plaintext[i];
    for (var i = 0; i < ad.length; i++) adPtr[i] = ad[i];

    final result = _pqaEncrypt(state, plaintextPtr, plaintext.length, adPtr, ad.length);

    calloc.free(plaintextPtr);
    calloc.free(adPtr);

    if (result == nullptr) return null;

    final msg = result.ref;
    final header = msg.header.asTypedList(msg.header_len).toList();
    final payload = msg.ratchet_message_payload.asTypedList(msg.ratchet_message_payload_len).toList();

    return PQAuraMessage(header: header, payload: payload, nativePtr: result);
  }

  /// Decrypt a message
  List<int>? decrypt(Pointer<RatchetState> state, List<int> header, List<int> payload, List<int> ad) {
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
    return serialized.asTypedList(len).toList();
  }

  /// Deserialize the ratchet state
  Pointer<RatchetState>? deserializeState(List<int> data) {
    if (!_isLoaded) return null;

    final dataPtr = calloc<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) dataPtr[i] = data[i];

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
  void freeKeypair(Pointer<Pointer<FfiKeyPair>> kp) {
    if (!_isLoaded || kp == nullptr) return;
    _pqaFreeKeypair(kp.ref);
    calloc.free(kp);
  }

  /// Free a bundle
  void freeBundle(Pointer<FfiPreKeyBundle> bundle) {
    if (!_isLoaded || bundle == nullptr) return;
    _pqaFreeBundle(bundle);
  }
}

/// Helper class for key pair data
class PQAuraKeyPair {
  final List<int> publicKey;
  final List<int> secretKey;
  final Pointer<Pointer<FfiKeyPair>> nativePtr;

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