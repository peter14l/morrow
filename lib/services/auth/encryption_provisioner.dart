import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';

class EncryptionProvisioner {
  /// Silently provision or restore E2E encryption keys in the background.
  /// Called immediately after every sign-in / sign-up so keys are ready
  /// before the user ever opens a chat (identical to WhatsApp's approach).
  Future<void> provisionEncryptionKeys() async {
    try {
      final encryptionService = EncryptionService();
      // Reset the service state first to ensure we check the new user's keys
      encryptionService.reset();
      
      final status = await encryptionService.init();
      debugPrint('[EncryptionProvisioner] Initialized status for current user: $status');

      // We DO NOT call setupEncryption() here anymore.
      // Automatic v1 setup is disabled to ensure users are prompted for a PIN (v2)
      // during their first chat session.
    } catch (e) {
      debugPrint('[EncryptionProvisioner] Error: $e');
    }
  }
}
