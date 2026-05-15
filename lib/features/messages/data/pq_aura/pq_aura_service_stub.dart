import 'dart:typed_data';

/// High-level PQ-Aura encryption service stub for web platform.
/// PQ-Aura is not supported on web because it relies on dart:ffi.
class PQAuraService {
  static PQAuraService? _instance;

  PQAuraService._();

  static PQAuraService get instance {
    _instance ??= PQAuraService._();
    return _instance!;
  }

  bool get isReady => false;

  Future<void> init() async {}

  bool hasSession(String remoteUserId) => false;

  /// Get or create a PQ-Aura session
  Future<bool> getOrCreateSession(String remoteUserId) async {
    return false;
  }

  /// Load a session from storage
  Future<bool> loadSession(String remoteUserId) async {
    return false;
  }

  /// Encrypt a message for a specific user
  Future<PQAuraEncryptedMessage?> encryptMessage(
    String recipientId,
    String plaintext,
  ) async {
    return null;
  }

  /// Encrypt a media key using the PQ session
  Future<Map<String, String>?> encryptMediaKey(
    String recipientId,
    Uint8List mediaKey,
  ) async {
    return null;
  }

  /// Encrypt a media key for multiple recipients (group media)
  Future<Map<String, String>?> encryptGroupMediaKey(
    List<String> recipientIds,
    Uint8List mediaKey,
  ) async {
    return null;
  }

  /// Decrypt a media key
  Future<Uint8List?> decryptMediaKey(
    String senderId,
    Map<String, dynamic> encryptionData,
  ) async {
    return null;
  }

  /// Encrypt a message for multiple recipients (group chat)
  Future<Map<String, String>?> encryptGroupMessage(
    List<String> participantIds,
    String plaintext,
  ) async {
    return null;
  }

  /// Decrypt a message from a specific user
  Future<String?> decryptMessage(
    String senderId,
    Uint8List header,
    Uint8List payload,
  ) async {
    return null;
  }

  /// Close and clean up a session
  void closeSession(String remoteUserId) {}

  /// Delete a session and its keys
  Future<void> deleteSession(String remoteUserId) async {}
}

class PQAuraEncryptedMessage {
  final Uint8List header;
  final Uint8List payload;

  PQAuraEncryptedMessage({required this.header, required this.payload});

  Map<String, dynamic> toJson() => {'header': '', 'payload': ''};

  factory PQAuraEncryptedMessage.fromJson(Map<String, dynamic> json) {
    return PQAuraEncryptedMessage(header: Uint8List(0), payload: Uint8List(0));
  }
}
