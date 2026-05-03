import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    @Default('direct') String type,
    @JsonKey(name: 'other_user_id') required String otherUserId,
    @JsonKey(name: 'other_user_name') required String otherUserName,
    @JsonKey(name: 'other_user_avatar') required String otherUserAvatar,
    @JsonKey(name: 'last_message') String? lastMessage,
    @JsonKey(name: 'last_message_time') DateTime? lastMessageTime,
    @JsonKey(name: 'last_message_read_at') DateTime? lastMessageReadAt,
    @JsonKey(name: 'last_message_sender_id') String? lastMessageSenderId,
    @Default(0) @JsonKey(name: 'unread_count') int unreadCount,
    @JsonKey(name: 'last_message_type') String? lastMessageType,
    @Default(false)
    @JsonKey(name: 'is_other_user_typing')
    bool isOtherUserTyping,
    @Default(0) @JsonKey(name: 'whisper_mode') int whisperMode,
    @Default(false) @JsonKey(name: 'is_pinned') bool isPinned,
    @Default([]) @JsonKey(name: 'recent_messages') List<String> recentMessages,
  }) = _Conversation;

  const Conversation._();

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(_normalizeConversationJson(json));

  static Map<String, dynamic> _normalizeConversationJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic> normalized = Map.from(json);
    final isGroup = json['type'] == 'group';
    
    normalized['type'] = json['type'] ?? 'direct';
    normalized['other_user_id'] = json['other_user_id'] ?? '';
    
    if (isGroup) {
      normalized['other_user_name'] = json['name'] ?? 'Group';
      normalized['other_user_avatar'] = json['image_url'] ?? '';
    } else {
      normalized['other_user_name'] =
          json['other_user_name'] ?? json['other_user_username'] ?? '';
      normalized['other_user_avatar'] =
          json['other_user_avatar'] ?? json['other_user_avatar_url'] ?? '';
    }
    
    normalized['whisper_mode'] =
        json['whisper_mode'] ?? (json['is_whisper_mode'] == true ? 1 : 0);
    return normalized;
  }

  // Helper method to get display text for last message
  String getLastMessageDisplay([String? currentUserId]) {
    if (lastMessage == null || lastMessage!.isEmpty) {
      return '';
    }

    String prefix = '';
    if (currentUserId != null && lastMessageSenderId == currentUserId) {
      prefix = 'You: ';
    }

    switch (lastMessageType) {
      case 'image':
        return '$prefix📷 Photo';
      case 'document':
        return '$prefix📄 Document';
      case 'voice':
        return '$prefix🎤 Voice message';
      case 'poll':
        return '$prefix📊 Poll';
      case 'location':
        return '$prefix📍 Location';
      default:
        return '$prefix$lastMessage';
    }
  }
}
