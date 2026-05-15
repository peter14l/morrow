import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_reaction.freezed.dart';
part 'message_reaction.g.dart';

/// Available message reaction emojis
enum MessageReaction {
  heart('❤️'),
  thumbsUp('👍'),
  thumbsDown('👎'),
  laugh('😂'),
  surprised('😮'),
  sad('😢'),
  fire('🔥'),
  celebrate('🎉');

  final String emoji;
  const MessageReaction(this.emoji);

  static MessageReaction? fromEmoji(String emoji) {
    for (final reaction in MessageReaction.values) {
      if (reaction.emoji == emoji) return reaction;
    }
    return null;
  }
}

@freezed
abstract class MessageReactionModel with _$MessageReactionModel {
  const factory MessageReactionModel({
    @Default('') String id,
    @JsonKey(name: 'message_id') @Default('') String messageId,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @Default('Unknown') String username,
    @JsonKey(readValue: _readReaction) required String reaction,
    @JsonKey(name: 'created_at', fromJson: _dateTimeFromJson)
    required DateTime createdAt,
  }) = _MessageReactionModel;

  const MessageReactionModel._();

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) =>
      _$MessageReactionModelFromJson(json);
}

Object? _readReaction(Map json, String key) {
  return json['emoji'] ?? json['reaction'] ?? '';
}

DateTime _dateTimeFromJson(Object? json) {
  if (json == null) return DateTime.now();
  if (json is DateTime) return json;
  return DateTime.parse(json as String);
}

@freezed
abstract class GroupedReaction with _$GroupedReaction {
  const factory GroupedReaction({
    required String emoji,
    required int count,
    required List<String> usernames,
    @Default(false) bool hasCurrentUserReacted,
  }) = _GroupedReaction;

  const GroupedReaction._();
}
