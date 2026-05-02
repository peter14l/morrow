import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:oasis/features/messages/domain/models/message_reaction.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageType { text, image, document, voice, poll, location, ripple, storyReply, postShare, system, gif, sticker }

@freezed
abstract class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'conversation_id') required String conversationId,
    @JsonKey(name: 'sender_id') required String senderId,
    @JsonKey(name: 'sender_name') @Default('') String senderName,
    @JsonKey(name: 'sender_avatar') @Default('') String senderAvatar,
    @Default('') String content,
    @Default(false) @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'any_read_at') DateTime? anyReadAt,
    @JsonKey(name: 'created_at') required DateTime timestamp,
    @Default(MessageType.text) @JsonKey(name: 'message_type') MessageType messageType,
    @JsonKey(name: 'media_url') String? mediaUrl,
    @JsonKey(name: 'media_thumbnail_url') String? mediaThumbnailUrl,
    @JsonKey(name: 'file_name') String? mediaFileName,
    @JsonKey(name: 'file_size') int? mediaFileSize,
    @JsonKey(name: 'media_mime_type') String? mediaMimeType,
    @JsonKey(name: 'poll_data') Map<String, dynamic>? pollData,
    @JsonKey(name: 'location_data') Map<String, dynamic>? locationData,
    @JsonKey(name: 'share_data') Map<String, dynamic>? shareData,
    @JsonKey(name: 'voice_duration') int? voiceDuration,
    @JsonKey(name: 'reply_to_id') String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    Map<String, dynamic>? replyToData,
    @Default([]) List<MessageReactionModel> reactions,
    @Default(false) @JsonKey(name: 'is_ephemeral') bool isEphemeral,
    @Default(false) @JsonKey(name: 'is_spoiler') bool isSpoiler,
    @Default(86400) @JsonKey(name: 'ephemeral_duration') int ephemeralDuration,
    @JsonKey(name: 'whisper_mode') @Default('OFF') String whisperMode,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'encrypted_keys') Map<String, dynamic>? encryptedKeys,
    String? iv,
    @JsonKey(name: 'signal_message_type') int? signalMessageType,
    @JsonKey(name: 'signal_sender_content') String? signalSenderContent,
    @JsonKey(name: 'signal_sender_message_type') int? signalSenderMessageType,
    // PQ-Aura Post-Quantum encryption fields
    @JsonKey(name: 'pq_aura_header') String? pqAuraHeader,
    @JsonKey(name: 'pq_aura_payload') String? pqAuraPayload,
    @JsonKey(name: 'pq_aura_sender_header') String? pqAuraSenderHeader,
    @JsonKey(name: 'pq_aura_sender_payload') String? pqAuraSenderPayload,
    @JsonKey(name: 'ripple_id') String? rippleId,
    @JsonKey(name: 'story_id') String? storyId,
    @JsonKey(name: 'post_id') String? postId,
    @Default('unlimited') @JsonKey(name: 'media_view_mode') String mediaViewMode,
    @Default(0) @JsonKey(name: 'current_user_view_count') int currentUserViewCount,
    @Default(false) @JsonKey(includeFromJson: false, includeToJson: false) bool isUploading,
    @Default(0.0) @JsonKey(includeFromJson: false, includeToJson: false) double uploadProgress,
  }) = _Message;

  const Message._();

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(_normalizeJson(json));

  static Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> normalizedJson = Map.from(json);

    // Derive message type from URL fields since message_type column doesn't exist
    MessageType type = MessageType.text;
    if (json['message_type'] != null) {
      type = MessageType.values.firstWhere(
        (e) => e.name == json['message_type'],
        orElse: () => MessageType.text,
      );
    } else {
      if (json['voice_url'] != null && json['voice_url'].toString().isNotEmpty) {
        type = MessageType.voice;
      } else if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
        // Check if it's a sticker or gif based on some metadata or content
        final String? content = json['content'];
        if (content == '[STICKER]') {
          type = MessageType.sticker;
        } else if (content == '[GIF]') {
          type = MessageType.gif;
        } else {
          type = MessageType.image;
        }
      } else if (json['video_url'] != null && json['video_url'].toString().isNotEmpty) {
        type = MessageType.image;
      } else if (json['file_url'] != null && json['file_url'].toString().isNotEmpty) {
        type = MessageType.document;
      } else if (json['post_id'] != null) {
        type = MessageType.postShare;
      } else if (json['ripple_id'] != null) {
        type = MessageType.ripple;
      } else if (json['location_data'] != null) {
        type = MessageType.location;
      } else if (json['poll_data'] != null) {
        type = MessageType.poll;
      } else if (json['story_id'] != null) {
        type = MessageType.storyReply;
      }
    }
    normalizedJson['message_type'] = type.name;

    // Consolidate media URLs
    normalizedJson['media_url'] = json['voice_url'] ?? json['image_url'] ?? json['video_url'] ?? json['file_url'] ?? json['media_url'];

    // Handle replied message metadata
    String? replyContent;
    String? replySenderName;
    if (json['reply_to'] != null) {
      final replyData = json['reply_to'] as Map<String, dynamic>;
      final isEncrypted = replyData['encrypted_keys'] != null || replyData['signal_message_type'] != null;
      
      if (isEncrypted) {
        if (replyData['voice_url'] != null) {
          replyContent = '🎤 Voice Message';
        } else if (replyData['image_url'] != null) {
          replyContent = '📷 Photo';
        } else if (replyData['video_url'] != null) {
          replyContent = '🎥 Video';
        } else if (replyData['file_url'] != null) {
          replyContent = '📁 File';
        } else {
          replyContent = '🔒 Encrypted message';
        }
      } else {
        replyContent = replyData['content'] as String?;
      }

      if (replyData['profiles'] != null) {
        replySenderName = replyData['profiles']['username'] as String?;
      }
    }
    normalizedJson['replyToContent'] = replyContent;
    normalizedJson['replyToSenderName'] = replySenderName;
    normalizedJson['replyToData'] = json['reply_to'];

    // Basic type normalization
    normalizedJson['sender_name'] = json['sender_name'] ?? '';
    normalizedJson['sender_avatar'] = json['sender_avatar'] ?? '';
    normalizedJson['content'] = json['content'] ?? '';
    normalizedJson['created_at'] = json['created_at'] ?? DateTime.now().toIso8601String();

    return normalizedJson;
  }

  static String formatBytes(int? bytes) {
    if (bytes == null) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
