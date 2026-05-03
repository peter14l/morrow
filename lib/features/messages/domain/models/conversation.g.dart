// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Conversation _$ConversationFromJson(Map<String, dynamic> json) =>
    _Conversation(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'direct',
      otherUserId: json['other_user_id'] as String,
      otherUserName: json['other_user_name'] as String,
      otherUserAvatar: json['other_user_avatar'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] == null
          ? null
          : DateTime.parse(json['last_message_time'] as String),
      lastMessageReadAt: json['last_message_read_at'] == null
          ? null
          : DateTime.parse(json['last_message_read_at'] as String),
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageType: json['last_message_type'] as String?,
      isOtherUserTyping: json['is_other_user_typing'] as bool? ?? false,
      whisperMode: (json['whisper_mode'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      recentMessages:
          (json['recent_messages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ConversationToJson(_Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'other_user_id': instance.otherUserId,
      'other_user_name': instance.otherUserName,
      'other_user_avatar': instance.otherUserAvatar,
      'last_message': instance.lastMessage,
      'last_message_time': instance.lastMessageTime?.toIso8601String(),
      'last_message_read_at': instance.lastMessageReadAt?.toIso8601String(),
      'last_message_sender_id': instance.lastMessageSenderId,
      'unread_count': instance.unreadCount,
      'last_message_type': instance.lastMessageType,
      'is_other_user_typing': instance.isOtherUserTyping,
      'whisper_mode': instance.whisperMode,
      'is_pinned': instance.isPinned,
      'recent_messages': instance.recentMessages,
    };
