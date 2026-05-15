import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

/// PQ-Aura initialization helper.
/// Call this during app startup to initialize post-quantum encryption.
class PQAuraInitializer {
  static bool _isInitialized = false;

  /// Initialize PQ-Aura service.
  /// Returns true if initialization succeeded (or already initialized).
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final success = await PQAuraService.instance.init();
      if (success) {
        _isInitialized = true;
        debugPrint('[PQAura] Initialization complete');
      } else {
        debugPrint('[PQAura] Initialization failed - will use Signal fallback');
      }
      return success;
    } catch (e) {
      debugPrint('[PQAura] Initialization error: $e');
      return false;
    }
  }

  /// Check if PQ-Aura is available
  static bool get isInitialized => _isInitialized;

  /// Check if a PQ session exists for a user
  static bool hasSession(String userId) {
    return PQAuraService.instance.hasSession(userId);
  }

  /// Clear all PQ-Aura data (on logout)
  static Future<void> clearAllData() async {
    await PQAuraService.instance.clearAllData();
    _isInitialized = false;
  }
}

/// Usage example:
///
/// In your app initialization (e.g., after authentication):
/// ```dart
/// // Initialize PQ-Aura alongside Signal
/// await PQAuraInitializer.initialize();
/// ```
///
/// For message encryption (with Signal fallback):
/// ```dart
/// final pqaService = PQAuraService.instance;
///
/// // Try PQ-Aura first
/// var encrypted = await pqaService.encryptMessage(recipientId, plaintext);
///
/// if (encrypted == null) {
///   // Fall back to Signal
///   encrypted = await SignalService().encryptMessage(recipientId, plaintext);
/// }
/// ```
///
/// For media key encryption:
/// ```dart
/// final pqaService = PQAuraService.instance;
///
/// // Generate random 32-byte AES key for media
/// final mediaKey = generateRandomBytes(32);
///
/// // Encrypt the media key with PQ session
/// var encryptedKey = await pqaService.encryptMediaKey(recipientId, Uint8List.fromList(mediaKey));
///
/// if (encryptedKey == null) {
///   // Fall back to RSA encryption (legacy)
///   encryptedKey = await EncryptionService().encryptWithRSA(mediaKey, recipientId);
/// }
/// ```
///
/// Note: Full integration into chat_provider.dart requires:
/// 1. Update Message model to include PQAuraEncryptedMessage fields
/// 2. Update messaging_service to handle PQ message types
/// 3. Add fallback logic to try PQ first, then Signal
/// 4. For media: use PQAuraService.encryptMediaKey instead of RSA
