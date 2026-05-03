import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';
import 'package:oasis/features/messages/presentation/screens/encryption_setup_screen.dart';

/// Provider handling all encryption-related chat logic.
/// Extracted from _ChatScreenState encryption methods in chat_screen.dart.
class ChatEncryptionProvider with ChangeNotifier {
  final EncryptionService _encryptionService = EncryptionService();
  final PQAuraService _pqauraService = PQAuraService.instance;
  bool _encryptionReady = false;
  bool get encryptionReady => _encryptionReady;
  bool get pqAuraReady => _pqauraService.isReady;

  /// Initialize encryption, prompting setup/restore if needed.
  /// Original: _initializeEncryption() in chat_screen.dart
  Future<bool> initializeEncryption(BuildContext context) async {
    // Initialize Signal Service (for backward compatibility)
    if (!SignalService().isInitialized) {
      final success = await SignalService().init();
      if (!success) {
        debugPrint('[Encryption] Failed to initialize SignalService');
      }
    }

    // Initialize PQ-Aura Service (new post-quantum protocol)
    try {
      if (!_pqauraService.isReady) {
        await _pqauraService.init();
      }
      if (_pqauraService.isReady) {
        debugPrint('[Encryption] PQ-Aura initialized successfully');
      }
    } catch (e) {
      debugPrint('[Encryption] PQ-Aura initialization failed: $e');
    }

    // Initialize RSA encryption service
    final status = await _encryptionService.init();

    if (status == EncryptionStatus.needsSetup) {
      if (context.mounted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const EncryptionSetupScreen(isRestore: false),
          ),
        );
        final ready = result == true;
        _encryptionReady = ready;
        notifyListeners();
        return ready;
      }
    } else if (status == EncryptionStatus.needsRestore) {
      if (context.mounted) {
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => const EncryptionSetupScreen(isRestore: true),
          ),
        );
        final ready = result == true;
        _encryptionReady = ready;
        notifyListeners();
        return ready;
      }
    } else if (status == EncryptionStatus.ready) {
      _encryptionReady = true;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Decrypt a single message (content + reply context).
  /// Original: _decryptSingleMessage() in chat_screen.dart
  /// Priority: PQ-Aura (post-quantum) > Signal > RSA
  Future<Message> decryptSingleMessage(
    Message message,
    String? currentUserId,
  ) async {
    Message decryptedMessage = message;
    String? decryptedContent;
    final isSender = currentUserId != null &&
        message.senderId.toLowerCase() == currentUserId.toLowerCase();

    // 1. Try PQ-Aura (Post-Quantum)
    if (message.pqAuraHeader != null && message.pqAuraPayload != null) {
      if (!isSender && _pqauraService.isReady) {
        try {
          final headerBytes = base64Decode(message.pqAuraHeader!);
          final payloadBytes = base64Decode(message.pqAuraPayload!);
          decryptedContent = await _pqauraService.decryptMessage(
            message.senderId,
            Uint8List.fromList(headerBytes),
            Uint8List.fromList(payloadBytes),
          );
        } catch (_) {}
      }
    }

    // 2. Try Signal (Classical E2EE)
    if (decryptedContent == null && !isSender && message.signalMessageType != null) {
      try {
        decryptedContent = await SignalService().decryptMessage(
          message.senderId,
          message.content,
          message.signalMessageType!,
        );
        // Ignore "Optimizing..." or "🔒" markers from Signal as success
        if (decryptedContent.contains('🔒') || decryptedContent.contains('Optimizing')) {
          decryptedContent = null;
        } else {
          debugPrint('[Encryption] Decrypted with Signal');
        }
      } catch (e) {
        debugPrint('[Encryption] Signal decryption failed: $e');
      }
    }

    // 3. Try RSA Fallback (Dual-layer for both sender and recipient)
    if (decryptedContent == null) {
      final rsaCiphertext = isSender 
          ? (message.pqAuraSenderPayload ?? message.signalSenderContent) 
          : (message.signalSenderContent ?? message.content);
      
      if (rsaCiphertext != null && message.encryptedKeys != null && message.iv != null) {
        try {
          decryptedContent = await _encryptionService.decryptMessage(
            rsaCiphertext,
            message.encryptedKeys!,
            message.iv!,
          );
          if (decryptedContent != null) {
            debugPrint('[Encryption] Decrypted with RSA fallback');
          }
        } catch (e) {
          debugPrint('[Encryption] RSA fallback failed: $e');
        }
      }
    }

    // 4. Update message content if decrypted
    if (decryptedContent != null) {
      decryptedMessage = decryptedMessage.copyWith(content: decryptedContent);
    } else if (message.pqAuraHeader != null || message.signalMessageType != null || (message.encryptedKeys != null && message.iv != null)) {
      // If we failed to decrypt a known encrypted message, set placeholder
      decryptedMessage = decryptedMessage.copyWith(content: '🔒 Message encrypted');
    }

    // 5. Decrypt reply content if available (recursive-like logic)
    if (decryptedMessage.replyToId != null &&
        decryptedMessage.replyToData != null) {
      final replyData = decryptedMessage.replyToData!;
      final replySenderId = replyData['sender_id'] as String?;
      final replyEncryptedKeys =
          replyData['encrypted_keys'] != null ? Map<String, dynamic>.from(replyData['encrypted_keys'] as Map) : null;
      final replyIv = replyData['iv'] as String?;
      final replySignalType = replyData['signal_message_type'] as int?;
      final replyContent = replyData['content'] as String?;
      final replySenderContent = replyData['signal_sender_content'] as String?;
      final replyPqaHeader = replyData['pq_aura_header'] as String?;
      final replyPqaPayload = replyData['pq_aura_payload'] as String?;

      if (replySenderId != null) {
        String? decryptedReply;
        final isReplyMe = currentUserId != null &&
            replySenderId.toLowerCase() == currentUserId.toLowerCase();

        // Try PQ-Aura for reply
        if (replyPqaHeader != null && replyPqaPayload != null && !isReplyMe && _pqauraService.isReady) {
          try {
            decryptedReply = await _pqauraService.decryptMessage(
              replySenderId,
              base64Decode(replyPqaHeader),
              base64Decode(replyPqaPayload),
            );
          } catch (_) {}
        }

        // Try Signal for reply
        if (decryptedReply == null && replySignalType != null && !isReplyMe) {
          try {
            decryptedReply = await SignalService().decryptMessage(
              replySenderId,
              replyContent ?? '',
              replySignalType,
            );
            if (decryptedReply.contains('🔒')) decryptedReply = null;
          } catch (_) {}
        }

        // Try RSA for reply
        if (decryptedReply == null) {
          final replyRsaCiphertext = isReplyMe
              ? replySenderContent
              : (replySenderContent ?? replyContent);
          
          if (replyRsaCiphertext != null && replyEncryptedKeys != null && replyIv != null) {
            try {
              decryptedReply = await _encryptionService.decryptMessage(
                replyRsaCiphertext,
                replyEncryptedKeys,
                replyIv,
              );
            } catch (_) {}
          }
        }

        if (decryptedReply != null && !decryptedReply.contains('🔒')) {
          decryptedMessage = decryptedMessage.copyWith(
            replyToContent: decryptedReply,
          );
        }
      }
    }

    return decryptedMessage;
  }

  /// Enable screenshot/recording prevention.
  /// Original: _enableScreenProtection() in chat_screen.dart
  Future<void> enableScreenProtection() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint('Error enabling screen protection: $e');
    }
  }

  /// Disable screenshot/recording prevention.
  /// Original: _disableScreenProtection() in chat_screen.dart
  Future<void> disableScreenProtection() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (e) {
      debugPrint('Error disabling screen protection: $e');
    }
  }

  /// Extract dominant colors from a background image for bubble theming.
  /// Original: _extractColorsFromBackground() in chat_screen.dart
  Future<void> extractColorsFromBackground(
    String? backgroundUrl,
    void Function(Color?, Color?, Color?, Color?) onColorsExtracted,
  ) async {
    if (backgroundUrl == null) return;

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final imageProvider = CachedNetworkImageProvider(backgroundUrl);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      final sentColor = paletteGenerator.dominantColor?.color ?? Colors.blue;
      final receivedColor =
          paletteGenerator.lightVibrantColor?.color ?? Colors.grey;

      final bubbleColorSent = sentColor.withValues(alpha: 0.9);
      final bubbleColorReceived = receivedColor.withValues(alpha: 0.85);

      final textColorSent =
          sentColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
      final textColorReceived =
          receivedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

      onColorsExtracted(
        bubbleColorSent,
        bubbleColorReceived,
        textColorSent,
        textColorReceived,
      );
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  /// Helper method to decrypt using Signal protocol (fallback)
  Future<Message> _decryptWithSignal(Message message, String? currentUserId) async {
    final isSender = currentUserId != null &&
        message.senderId.toLowerCase() == currentUserId.toLowerCase();

    if (isSender &&
        message.signalSenderContent != null &&
        message.encryptedKeys != null &&
        message.iv != null) {
      final decrypted = await _encryptionService.decryptMessage(
        message.signalSenderContent!,
        message.encryptedKeys!,
        message.iv!,
      );
      return message.copyWith(content: decrypted ?? '🔒 Message encrypted');
    } else if (!isSender && message.signalMessageType != null) {
      String decrypted = await SignalService().decryptMessage(
        message.senderId,
        message.content,
        message.signalMessageType!,
      );

      // Fall back to RSA if Signal decryption returns encrypted marker
      if ((decrypted.contains('🔒') || decrypted.contains('Optimizing')) &&
          message.signalSenderContent != null &&
          message.encryptedKeys != null &&
          message.iv != null) {
        final rsaDecrypted = await _encryptionService.decryptMessage(
          message.signalSenderContent!,
          message.encryptedKeys!,
          message.iv!,
        );
        if (rsaDecrypted != null) decrypted = rsaDecrypted;
      }
      return message.copyWith(content: decrypted);
    }
    return message;
  }
}
