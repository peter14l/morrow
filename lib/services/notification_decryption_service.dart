import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/session_registry_service.dart';

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
      'actor_id': notification.actorId,
      'encrypted_keys': notification.metadata?['encrypted_keys'],
      'iv': notification.metadata?['iv'],
      'signal_message_type': notification.metadata?['signal_message_type'],
      'signal_sender_content': notification.metadata?['signal_sender_content'],
      'pq_aura_header': notification.metadata?['pq_aura_header'],
      'pq_aura_payload': notification.metadata?['pq_aura_payload'],
    };

    return decryptMessage(data);
  }

  /// Decrypts a message from FCM data payload.
  Future<String?> decryptMessage(
    Map<String, dynamic> data, {
    String? targetUserId,
  }) async {
    // Check if metadata is nested as a JSON string or map in 'metadata'
    Map<String, dynamic> mergedData = Map<String, dynamic>.from(data);
    if (data['metadata'] != null) {
      if (data['metadata'] is String) {
        try {
          final parsed = jsonDecode(data['metadata'] as String);
          if (parsed is Map) {
            mergedData.addAll(Map<String, dynamic>.from(parsed));
          }
        } catch (_) {}
      } else if (data['metadata'] is Map) {
        mergedData.addAll(Map<String, dynamic>.from(data['metadata']));
      }
    }

    final String? content =
        mergedData['signal_sender_content'] ??
        mergedData['body'] ??
        mergedData['content'] ??
        mergedData['message'];
    if (content == null) return null;

    // If it's the generic placeholder, try to find actual ciphertext in signal_sender_content or data['body']
    final bool isGenericPlaceholder =
        content == 'New Encrypted Message' ||
        content == 'New message' ||
        content.contains('🔒');

    final bool hasEncryptedKeys = mergedData['encrypted_keys'] != null;
    final bool hasSignalType = mergedData['signal_message_type'] != null;
    final bool hasPQAura =
        mergedData['pq_aura_header'] != null &&
        mergedData['pq_aura_payload'] != null;
    final bool isLikelyEncrypted =
        !content.contains(' ') && (content.length > 30 || _isBase64(content));

    // If it doesn't look encrypted and we don't have metadata, return as is
    if (!isGenericPlaceholder &&
        !hasEncryptedKeys &&
        !hasSignalType &&
        !hasPQAura &&
        !isLikelyEncrypted) {
      return content;
    }

    try {
      String? userId = targetUserId ?? _authService.currentUser?.id;
      if (userId == null) {
        try {
          final accounts = await SessionRegistryService().getAllAccounts();
          if (accounts.isNotEmpty) {
            userId = accounts.first.userId;
          }
        } catch (_) {}
      }
      final senderId = mergedData['sender_id'] ?? mergedData['actor_id'];

      if (userId == null) {
        debugPrint(
          '[NotificationDecryption] Decryption failed: No active session/userId',
        );
        return '🔒 Encrypted message';
      }

      // Initialize encryption services if needed
      if (!_encryptionService.isInitialized) {
        debugPrint(
          '[NotificationDecryption] Initializing EncryptionService...',
        );
        await _encryptionService.init();
      }

      // SignalService handles its own per-user initialization
      await _signalService.init(userId: userId);

      // 0. Try PQ-Aura decryption first if applicable
      if (hasPQAura && senderId != null) {
        debugPrint(
          '[NotificationDecryption] Attempting PQ-Aura decryption for $userId...',
        );
        try {
          final header = base64Decode(mergedData['pq_aura_header'].toString());
          final payload = base64Decode(mergedData['pq_aura_payload'].toString());
          final decrypted = await PQAuraService.instance.decryptMessage(
            senderId.toString(),
            header,
            payload,
          );
          if (decrypted != null && decrypted.isNotEmpty) {
            return decrypted;
          }
        } catch (e) {
          debugPrint('[NotificationDecryption] PQ-Aura decryption failed: $e');
        }
      }

      // 1. Try Signal decryption first if applicable
      if (hasSignalType && senderId != null) {
        debugPrint(
          '[NotificationDecryption] Attempting Signal decryption for $userId...',
        );
        final signalType = int.tryParse(mergedData['signal_message_type'].toString());
        if (signalType != null) {
          try {
            // Use signal_sender_content or fallback content
            final ciphertext =
                mergedData['signal_sender_content']?.toString() ??
                (isGenericPlaceholder ? '' : content);

            if (ciphertext.isNotEmpty) {
              final decrypted = await _signalService.decryptMessage(
                senderId.toString(),
                ciphertext,
                signalType,
                localUserId: userId,
              );

              if (decrypted.isNotEmpty &&
                  !decrypted.contains('🔒') &&
                  !decrypted.contains('Optimizing secure connection')) {
                return decrypted;
              }

              // If signal decryption returned placeholder but we have RSA fallback
              if (hasEncryptedKeys && mergedData['iv'] != null) {
                debugPrint(
                  '[NotificationDecryption] Signal returned placeholder, trying RSA fallback...',
                );
                return await _decryptRSAFallback(mergedData, userId: userId);
              }

              if (decrypted.isNotEmpty) {
                return decrypted;
              }
            }
          } catch (e) {
            debugPrint('[NotificationDecryption] Signal decryption failed: $e');
          }
        }
      }

      // 2. Try RSA decryption
      if (hasEncryptedKeys && mergedData['iv'] != null) {
        debugPrint(
          '[NotificationDecryption] Attempting RSA decryption for $userId...',
        );
        final rsaDecrypted = await _decryptRSAFallback(mergedData, userId: userId);
        if (rsaDecrypted != null && rsaDecrypted.isNotEmpty) {
          return rsaDecrypted;
        }
      }
    } catch (e) {
      debugPrint('[NotificationDecryption] Decryption error: $e');
    }

    // If we reached here, decryption failed or metadata was missing
    if (isGenericPlaceholder ||
        hasEncryptedKeys ||
        hasSignalType ||
        hasPQAura ||
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
      return str.length > 10;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _decryptRSAFallback(
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    final String? content =
        data['signal_sender_content']?.toString() ??
        data['body']?.toString() ??
        data['content']?.toString();
    final dynamic encryptedKeysRaw = data['encrypted_keys'];
    final String? iv = data['iv']?.toString();

    if (content == null || encryptedKeysRaw == null || iv == null) return null;

    Map<String, String> encryptedKeys = {};
    if (encryptedKeysRaw is String) {
      try {
        final decoded = jsonDecode(encryptedKeysRaw);
        if (decoded is Map) {
          encryptedKeys = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (e) {
        debugPrint(
          '[NotificationDecryption] Failed to parse encrypted_keys string: $e',
        );
        return null;
      }
    } else if (encryptedKeysRaw is Map) {
      encryptedKeys = encryptedKeysRaw.map((k, v) => MapEntry(k.toString(), v.toString()));
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
