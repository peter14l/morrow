// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  conversationId: json['conversation_id'] as String,
  senderId: json['sender_id'] as String,
  senderName: json['sender_name'] as String? ?? '',
  senderAvatar: json['sender_avatar'] as String? ?? '',
  content: json['content'] as String? ?? '',
  isRead: json['is_read'] as bool? ?? false,
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at'] as String),
  anyReadAt: json['any_read_at'] == null
      ? null
      : DateTime.parse(json['any_read_at'] as String),
  timestamp: DateTime.parse(json['created_at'] as String),
  messageType:
      $enumDecodeNullable(_$MessageTypeEnumMap, json['message_type']) ??
      MessageType.text,
  mediaUrl: json['media_url'] as String?,
  mediaThumbnailUrl: json['media_thumbnail_url'] as String?,
  mediaFileName: json['file_name'] as String?,
  mediaFileSize: (json['file_size'] as num?)?.toInt(),
  mediaMimeType: json['media_mime_type'] as String?,
  pollData: json['poll_data'] as Map<String, dynamic>?,
  locationData: json['location_data'] as Map<String, dynamic>?,
  shareData: json['share_data'] as Map<String, dynamic>?,
  voiceDuration: (json['voice_duration'] as num?)?.toInt(),
  replyToId: json['reply_to_id'] as String?,
  replyToContent: json['replyToContent'] as String?,
  replyToSenderName: json['replyToSenderName'] as String?,
  replyToData: json['replyToData'] as Map<String, dynamic>?,
  reactions:
      (json['reactions'] as List<dynamic>?)
          ?.map((e) => MessageReactionModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  isEphemeral: json['is_ephemeral'] as bool? ?? false,
  isSpoiler: json['is_spoiler'] as bool? ?? false,
  ephemeralDuration: (json['ephemeral_duration'] as num?)?.toInt() ?? 86400,
  whisperMode: json['whisper_mode'] as String? ?? 'OFF',
  expiresAt: json['expires_at'] == null
      ? null
      : DateTime.parse(json['expires_at'] as String),
  encryptedKeys: json['encrypted_keys'] as Map<String, dynamic>?,
  iv: json['iv'] as String?,
  signalMessageType: (json['signal_message_type'] as num?)?.toInt(),
  signalSenderContent: json['signal_sender_content'] as String?,
  signalSenderMessageType: (json['signal_sender_message_type'] as num?)
      ?.toInt(),
  pqAuraHeader: json['pq_aura_header'] as String?,
  pqAuraPayload: json['pq_aura_payload'] as String?,
  pqAuraSenderHeader: json['pq_aura_sender_header'] as String?,
  pqAuraSenderPayload: json['pq_aura_sender_payload'] as String?,
  rippleId: json['ripple_id'] as String?,
  storyId: json['story_id'] as String?,
  postId: json['post_id'] as String?,
  mediaViewMode: json['media_view_mode'] as String? ?? 'unlimited',
  currentUserViewCount: (json['current_user_view_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'conversation_id': instance.conversationId,
  'sender_id': instance.senderId,
  'sender_name': instance.senderName,
  'sender_avatar': instance.senderAvatar,
  'content': instance.content,
  'is_read': instance.isRead,
  'read_at': instance.readAt?.toIso8601String(),
  'any_read_at': instance.anyReadAt?.toIso8601String(),
  'created_at': instance.timestamp.toIso8601String(),
  'message_type': _$MessageTypeEnumMap[instance.messageType]!,
  'media_url': instance.mediaUrl,
  'media_thumbnail_url': instance.mediaThumbnailUrl,
  'file_name': instance.mediaFileName,
  'file_size': instance.mediaFileSize,
  'media_mime_type': instance.mediaMimeType,
  'poll_data': instance.pollData,
  'location_data': instance.locationData,
  'share_data': instance.shareData,
  'voice_duration': instance.voiceDuration,
  'reply_to_id': instance.replyToId,
  'replyToContent': instance.replyToContent,
  'replyToSenderName': instance.replyToSenderName,
  'replyToData': instance.replyToData,
  'reactions': instance.reactions,
  'is_ephemeral': instance.isEphemeral,
  'is_spoiler': instance.isSpoiler,
  'ephemeral_duration': instance.ephemeralDuration,
  'whisper_mode': instance.whisperMode,
  'expires_at': instance.expiresAt?.toIso8601String(),
  'encrypted_keys': instance.encryptedKeys,
  'iv': instance.iv,
  'signal_message_type': instance.signalMessageType,
  'signal_sender_content': instance.signalSenderContent,
  'signal_sender_message_type': instance.signalSenderMessageType,
  'pq_aura_header': instance.pqAuraHeader,
  'pq_aura_payload': instance.pqAuraPayload,
  'pq_aura_sender_header': instance.pqAuraSenderHeader,
  'pq_aura_sender_payload': instance.pqAuraSenderPayload,
  'ripple_id': instance.rippleId,
  'story_id': instance.storyId,
  'post_id': instance.postId,
  'media_view_mode': instance.mediaViewMode,
  'current_user_view_count': instance.currentUserViewCount,
};

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.document: 'document',
  MessageType.voice: 'voice',
  MessageType.poll: 'poll',
  MessageType.location: 'location',
  MessageType.ripple: 'ripple',
  MessageType.storyReply: 'storyReply',
  MessageType.postShare: 'postShare',
  MessageType.system: 'system',
  MessageType.gif: 'gif',
  MessageType.sticker: 'sticker',
  MessageType.collaborationRequest: 'collaborationRequest',
};
