import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/services/auth_service.dart';

import 'package:oasis/features/notifications/domain/models/notification_entity.dart';

/// Service responsible for decrypting message content in notifications.
class NotificationDecryptionService {
  static final NotificationDecryptionService _instance =
      NotificationDecryptionService._internal();
  factory NotificationDecryptionService() => _instance;
  NotificationDecryptionService._internal();

  final EncryptionService _encryptionService = EncryptionService();
  final SignalService _signalService = SignalService();
  final AuthService _authService = AuthService();

  /// Decrypts a notification entity (from Supabase Realtime).
  Future<String?> decryptNotification(AppNotification notification) async {
    final Map<String, dynamic> data = {
      'body': notification.message,
      'content': notification.message,
      'sender_id': notification.actorId,
      'encrypted_keys': notification.metadata?['encrypted_keys'],
      'iv': notification.metadata?['iv'],
      'signal_message_type': notification.metadata?['signal_message_type'],
      'signal_sender_content': notification.metadata?['signal_sender_content'],
    };

    return decryptMessage(data);
  }

  /// Decrypts a message from FCM data payload.
  Future<String?> decryptMessage(
    Map<String, dynamic> data, {
    String? targetUserId,
  }) async {
    final String? content = data['body'] ?? data['content'] ?? data['message'];
    if (content == null) return null;

    // If it's the generic placeholder, try to find actual ciphertext in signal_sender_content or data['body']
    final bool isGenericPlaceholder =
        content == 'New Encrypted Message' || content.contains('🔒');

    final bool hasEncryptedKeys = data['encrypted_keys'] != null;
    final bool hasSignalType = data['signal_message_type'] != null;
    final bool isLikelyEncrypted =
        !content.contains(' ') && (content.length > 30 || _isBase64(content));

    // If it doesn't look encrypted and we don't have metadata, return as is
    if (!isGenericPlaceholder &&
        !hasEncryptedKeys &&
        !hasSignalType &&
        !isLikelyEncrypted) {
      return content;
    }

    try {
      final userId = targetUserId ?? _authService.currentUser?.id;
      final senderId = data['sender_id'] ?? data['actor_id'];

      if (userId == null) {
        debugPrint(
          '[NotificationDecryption] Decryption failed: No active session/userId',
        );
        return '🔒 New Message';
      }

      // Initialize encryption services if needed
      if (!_encryptionService.isInitialized) {
        debugPrint(
          '[NotificationDecryption] Initializing EncryptionService...',
        );
        await _encryptionService.init();
      }

      // SignalService handles its own per-user initialization now
      // but we might want to ensure it's ready for this user
      await _signalService.init(userId: userId);

      // 1. Try Signal decryption first if applicable
      if (hasSignalType && senderId != null) {
        debugPrint(
          '[NotificationDecryption] Attempting Signal decryption for $userId...',
        );
        final signalType = int.tryParse(data['signal_message_type'].toString());
        if (signalType != null) {
          try {
            // Use signal_sender_content if body is just a placeholder
            final ciphertext =
                (isGenericPlaceholder && data['signal_sender_content'] != null)
                ? data['signal_sender_content']
                : content;

            final decrypted = await _signalService.decryptMessage(
              senderId,
              ciphertext,
              signalType,
              localUserId: userId,
            );

            // If signal decryption returned a placeholder but we have RSA fallback
            if ((decrypted.contains('🔒') ||
                    decrypted.contains('Optimizing secure connection')) &&
                data['signal_sender_content'] != null &&
                hasEncryptedKeys &&
                data['iv'] != null) {
              debugPrint(
                '[NotificationDecryption] Signal returned placeholder, trying RSA fallback...',
              );
              return await _decryptRSAFallback(data, userId: userId);
            }

            return decrypted;
          } catch (e) {
            debugPrint('[NotificationDecryption] Signal decryption failed: $e');
          }
        }
      }

      // 2. Try RSA decryption
      if (hasEncryptedKeys && data['iv'] != null) {
        debugPrint(
          '[NotificationDecryption] Attempting RSA decryption for $userId...',
        );
        return await _decryptRSAFallback(data, userId: userId);
      }
    } catch (e) {
      debugPrint('[NotificationDecryption] Decryption error: $e');
    }

    // If we reached here, decryption failed or metadata was missing
    if (isGenericPlaceholder ||
        hasEncryptedKeys ||
        hasSignalType ||
        isLikelyEncrypted) {
      debugPrint(
        '[NotificationDecryption] Decryption reached fallback: placeholder returned',
      );
      return '🔒 Encrypted message';
    }

    return content;
  }

  bool _isBase64(String str) {
    try {
      base64.decode(str);
      return str.length >
          10; // Simple length check to avoid false positives for tiny strings
    } catch (_) {
      return false;
    }
  }

  Future<String?> _decryptRSAFallback(
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    final String? content =
        data['signal_sender_content'] ?? data['body'] ?? data['content'];
    final dynamic encryptedKeysRaw = data['encrypted_keys'];
    final String? iv = data['iv'];

    if (content == null || encryptedKeysRaw == null || iv == null) return null;

    Map<String, String> encryptedKeys;
    if (encryptedKeysRaw is String) {
      try {
        encryptedKeys = Map<String, String>.from(jsonDecode(encryptedKeysRaw));
      } catch (e) {
        debugPrint(
          '[NotificationDecryption] Failed to parse encrypted_keys string: $e',
        );
        return null;
      }
    } else if (encryptedKeysRaw is Map) {
      encryptedKeys = Map<String, String>.from(encryptedKeysRaw);
    } else {
      return null;
    }

    return await _encryptionService.decryptMessage(
      content,
      encryptedKeys,
      iv,
      userId: userId,
    );
  }
}
