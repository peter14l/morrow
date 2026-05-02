import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';

/// Centralized service for decrypting chat messages.
/// 
/// This service handles the complex logic of determining which encryption 
/// protocol (RSA or Signal) was used for a message and performing the 
/// decryption with appropriate fallbacks.
class ChatDecryptionService {
  final EncryptionService _encryptionService;
  final SignalService _signalService;

  ChatDecryptionService({
    EncryptionService? encryptionService,
    SignalService? signalService,
  }) : _encryptionService = encryptionService ?? EncryptionService(),
       _signalService = signalService ?? SignalService();

  /// Decrypts a single message's content based on its encryption metadata.
  /// 
  /// [senderId] is the UUID of the user who sent the message.
  /// [currentUserId] is the UUID of the authenticated user.
  /// [content] is the encrypted ciphertext or a placeholder.
  /// [encryptedKeys] contains the RSA-encrypted AES keys for various recipients.
  /// [iv] is the initialization vector used for AES encryption.
  /// [signalMessageType] if present, indicates the message was sent via Signal Protocol.
  /// [signalSenderContent] contains an RSA-encrypted copy for the sender's own recovery.
  /// 
  /// Returns the plain-text content or a placeholder if decryption fails.
  Future<String> decryptMessageContent({
    required String senderId,
    required String currentUserId,
    required String content,
    Map<String, String>? encryptedKeys,
    String? iv,
    int? signalMessageType,
    String? signalSenderContent,
    String? pqAuraHeader,
    String? pqAuraPayload,
    bool isHistorical = false,
  }) async {
    try {
      final isSender = senderId == currentUserId;
      String decryptedContent = content;

      // 1. Try PQ-Aura (Post-Quantum) first if metadata is present
      if (pqAuraHeader != null && pqAuraPayload != null) {
        final pqaService = PQAuraService.instance;
        final pqaDecrypted = await pqaService.decryptMessage(
          senderId,
          base64Decode(pqAuraHeader),
          base64Decode(pqAuraPayload),
        );
        if (pqaDecrypted != null) {
          decryptedContent = pqaDecrypted;
          // Handle Protocol Sync
          if (decryptedContent == 'PROTOCOL_SYNC') {
            return '🔒 Connection optimized';
          }
          return decryptedContent;
        }
      }

      // 2. Try Signal (Classical E2EE)
      if (!isSender && signalMessageType != null) {
        await _signalService.init();
        decryptedContent = await _signalService.decryptMessage(
          senderId,
          content,
          signalMessageType,
          isHistorical: isHistorical,
        );

        // Handle Protocol Sync
        if (decryptedContent == 'PROTOCOL_SYNC') {
          return '🔒 Connection optimized';
        }

        // Fallback to RSA if Signal decryption fails or is a placeholder
        if (decryptedContent.contains('🔒') &&
            encryptedKeys != null &&
            iv != null &&
            signalSenderContent != null) {
          final rsaDecrypted = await _encryptionService.decryptMessage(
            signalSenderContent,
            Map<String, String>.from(encryptedKeys),
            iv,
          );
          if (rsaDecrypted != null) decryptedContent = rsaDecrypted;
        }
      } else if (isSender &&
          signalSenderContent != null &&
          encryptedKeys != null &&
          iv != null) {
        // Decrypt sent message using our own RSA key (dual-layer fallback)
        final decrypted = await _encryptionService.decryptMessage(
          signalSenderContent,
          Map<String, String>.from(encryptedKeys),
          iv,
        );
        decryptedContent = decrypted ?? '🔒 Message encrypted';
      } else if (encryptedKeys != null && iv != null) {
        // Legacy RSA-only encryption
        final decrypted = await _encryptionService.decryptMessage(
          content,
          Map<String, String>.from(encryptedKeys),
          iv,
        );
        decryptedContent = decrypted ?? '🔒 Message encrypted';
      }

      // Safety fallback: if content looks like a raw encrypted blob (no spaces, likely base64/hex)
      if (decryptedContent == content &&
          !content.contains(' ') &&
          (content.length > 30 || _isBase64(content))) {
        return '🔒 Message encrypted';
      }

      return decryptedContent;
    } catch (e) {
      debugPrint('[ChatDecryption] Error decrypting: $e');
      return '🔒 Message encrypted';
    }
  }

  bool _isBase64(String str) {
    try {
      base64.decode(str);
      return str.length > 10;
    } catch (_) {
      return false;
    }
  }

  /// Extracts message type based on available media URL columns.
  String determineMessageType(Map<String, dynamic> data) {
    if ((data['msg_voice_url'] ?? data['voice_url']) != null &&
        (data['msg_voice_url'] ?? data['voice_url']).toString().isNotEmpty) {
      return 'voice';
    } else if ((data['msg_image_url'] ?? data['image_url']) != null &&
        (data['msg_image_url'] ?? data['image_url']).toString().isNotEmpty) {
      return 'image';
    } else if ((data['msg_video_url'] ?? data['video_url']) != null &&
        (data['msg_video_url'] ?? data['video_url']).toString().isNotEmpty) {
      return 'video';
    } else if ((data['msg_file_url'] ?? data['file_url']) != null &&
        (data['msg_file_url'] ?? data['file_url']).toString().isNotEmpty) {
      return 'document';
    }
    return 'text';
  }
}
