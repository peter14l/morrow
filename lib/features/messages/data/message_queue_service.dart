import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Metadata for a queued outgoing message.
class QueuedMessage {
  final String clientId;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType;
  final String? mediaPath;
  final String? mediaFileName;
  final int? mediaFileSize;
  final String? replyToId;
  final int whisperMode;
  final bool isSpoiler;
  final String mediaViewMode;
  final DateTime queuedAt;
  final int retryCount;

  const QueuedMessage({
    required this.clientId,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.mediaPath,
    this.mediaFileName,
    this.mediaFileSize,
    this.replyToId,
    this.whisperMode = 0,
    this.isSpoiler = false,
    this.mediaViewMode = 'unlimited',
    required this.queuedAt,
    this.retryCount = 0,
  });

  QueuedMessage copyWith({int? retryCount}) {
    return QueuedMessage(
      clientId: clientId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      messageType: messageType,
      mediaPath: mediaPath,
      mediaFileName: mediaFileName,
      mediaFileSize: mediaFileSize,
      replyToId: replyToId,
      whisperMode: whisperMode,
      isSpoiler: isSpoiler,
      mediaViewMode: mediaViewMode,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'conversationId': conversationId,
    'senderId': senderId,
    'content': content,
    'messageType': messageType,
    'mediaPath': mediaPath,
    'mediaFileName': mediaFileName,
    'mediaFileSize': mediaFileSize,
    'replyToId': replyToId,
    'whisperMode': whisperMode,
    'isSpoiler': isSpoiler,
    'mediaViewMode': mediaViewMode,
    'queuedAt': queuedAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      clientId: json['clientId'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String? ?? '',
      messageType: json['messageType'] as String? ?? 'text',
      mediaPath: json['mediaPath'] as String?,
      mediaFileName: json['mediaFileName'] as String?,
      mediaFileSize: json['mediaFileSize'] as int?,
      replyToId: json['replyToId'] as String?,
      whisperMode: json['whisperMode'] as int? ?? 0,
      isSpoiler: json['isSpoiler'] as bool? ?? false,
      mediaViewMode: json['mediaViewMode'] as String? ?? 'unlimited',
      queuedAt: json['queuedAt'] != null
          ? DateTime.parse(json['queuedAt'] as String)
          : DateTime.now(),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Persists unsent messages and retries them on connectivity restore.
/// Each conversation gets its own queue key in SharedPreferences.
class MessageQueueService {
  static const String _queuePrefix = 'msg_queue_';

  final Uuid _uuid = const Uuid();

  /// Generates a unique client-side message ID.
  String generateClientId() => _uuid.v4();

  /// Enqueue an outgoing message for offline persistence.
  Future<void> enqueue(String conversationId, QueuedMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(conversationId);
    final queue = await _loadQueueInternal(prefs, key);
    queue.add(message.toJson());
    await prefs.setString(key, jsonEncode(queue));
    debugPrint(
      '[MessageQueue] Enqueued ${message.clientId} for $conversationId (${queue.length} pending)',
    );
  }

  /// Dequeue a specific message by clientId after successful send.
  Future<void> dequeue(String conversationId, String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(conversationId);
    final queue = await _loadQueueInternal(prefs, key);
    queue.removeWhere((m) => m['clientId'] == clientId);
    if (queue.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(queue));
    }
  }

  /// Load all queued messages for a conversation.
  Future<List<QueuedMessage>> loadQueue(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(conversationId);
    final raw = await _loadQueueInternal(prefs, key);
    return raw.map((m) => QueuedMessage.fromJson(m)).toList();
  }

  /// Increment retry count for a message.
  Future<void> incrementRetry(String conversationId, String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(conversationId);
    final queue = await _loadQueueInternal(prefs, key);
    final index = queue.indexWhere((m) => m['clientId'] == clientId);
    if (index == -1) return;
    queue[index]['retryCount'] = (queue[index]['retryCount'] as int? ?? 0) + 1;
    await prefs.setString(key, jsonEncode(queue));
  }

  /// Clear the entire queue for a conversation.
  Future<void> clearQueue(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey(conversationId));
  }

  /// Check if there are pending messages for a conversation.
  Future<bool> hasPending(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _queueKey(conversationId);
    final raw = await _loadQueueInternal(prefs, key);
    return raw.isNotEmpty;
  }

  String _queueKey(String conversationId) => '$_queuePrefix$conversationId';

  Future<List<Map<String, dynamic>>> _loadQueueInternal(
    SharedPreferences prefs,
    String key,
  ) async {
    final String? raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[MessageQueue] Error parsing queue: $e');
      return [];
    }
  }
}
