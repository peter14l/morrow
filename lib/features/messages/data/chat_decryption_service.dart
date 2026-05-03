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
      String? decryptedContent;

      // 1. Try PQ-Aura (Post-Quantum)
      if (pqAuraHeader != null && pqAuraPayload != null && !isSender) {
        final pqaService = PQAuraService.instance;
        decryptedContent = await pqaService.decryptMessage(
          senderId,
          base64Decode(pqAuraHeader),
          base64Decode(pqAuraPayload),
        );
        // Handle Protocol Sync
        if (decryptedContent == 'PROTOCOL_SYNC') {
          return '🔒 Connection optimized';
        }
      }

      // 2. Try Signal (Classical E2EE)
      if (decryptedContent == null && !isSender && signalMessageType != null) {
        await _signalService.init();
        decryptedContent = await _signalService.decryptMessage(
          senderId,
          content,
          signalMessageType,
          isHistorical: isHistorical,
        );

        // Handle Protocol Sync or placeholder
        if (decryptedContent == 'PROTOCOL_SYNC') {
          return '🔒 Connection optimized';
        }
        if (decryptedContent.contains('🔒') || decryptedContent.contains('Optimizing')) {
          decryptedContent = null;
        }
      }

      // 3. Try RSA Fallback (Dual-layer for both sender and recipient)
      if (decryptedContent == null) {
        final rsaCiphertext = isSender 
            ? signalSenderContent 
            : (signalSenderContent ?? content);
        
        if (rsaCiphertext != null && encryptedKeys != null && iv != null) {
          decryptedContent = await _encryptionService.decryptMessage(
            rsaCiphertext,
            Map<String, String>.from(encryptedKeys),
            iv,
          );
        }
      }

      if (decryptedContent != null) return decryptedContent;

      // Safety fallback: if content looks like a raw encrypted blob
      if (!content.contains(' ') &&
          (content.length > 30 || _isBase64(content))) {
        return '🔒 Message encrypted';
      }

      return content;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatDecryption] Error decrypting: $e');
      }
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
