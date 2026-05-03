// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Conversation {

 String get id; String get type;@JsonKey(name: 'other_user_id') String get otherUserId;@JsonKey(name: 'other_user_name') String get otherUserName;@JsonKey(name: 'other_user_avatar') String get otherUserAvatar;@JsonKey(name: 'last_message') String? get lastMessage;@JsonKey(name: 'last_message_time') DateTime? get lastMessageTime;@JsonKey(name: 'last_message_read_at') DateTime? get lastMessageReadAt;@JsonKey(name: 'last_message_sender_id') String? get lastMessageSenderId;@JsonKey(name: 'unread_count') int get unreadCount;@JsonKey(name: 'last_message_type') String? get lastMessageType;@JsonKey(name: 'is_other_user_typing') bool get isOtherUserTyping;@JsonKey(name: 'whisper_mode') int get whisperMode;@JsonKey(name: 'is_pinned') bool get isPinned;@JsonKey(name: 'recent_messages') List<String> get recentMessages;
/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationCopyWith<Conversation> get copyWith => _$ConversationCopyWithImpl<Conversation>(this as Conversation, _$identity);

  /// Serializes this Conversation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUserName, otherUserName) || other.otherUserName == otherUserName)&&(identical(other.otherUserAvatar, otherUserAvatar) || other.otherUserAvatar == otherUserAvatar)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&(identical(other.lastMessageReadAt, lastMessageReadAt) || other.lastMessageReadAt == lastMessageReadAt)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessageType, lastMessageType) || other.lastMessageType == lastMessageType)&&(identical(other.isOtherUserTyping, isOtherUserTyping) || other.isOtherUserTyping == isOtherUserTyping)&&(identical(other.whisperMode, whisperMode) || other.whisperMode == whisperMode)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&const DeepCollectionEquality().equals(other.recentMessages, recentMessages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,otherUserId,otherUserName,otherUserAvatar,lastMessage,lastMessageTime,lastMessageReadAt,lastMessageSenderId,unreadCount,lastMessageType,isOtherUserTyping,whisperMode,isPinned,const DeepCollectionEquality().hash(recentMessages));

@override
String toString() {
  return 'Conversation(id: $id, type: $type, otherUserId: $otherUserId, otherUserName: $otherUserName, otherUserAvatar: $otherUserAvatar, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, lastMessageReadAt: $lastMessageReadAt, lastMessageSenderId: $lastMessageSenderId, unreadCount: $unreadCount, lastMessageType: $lastMessageType, isOtherUserTyping: $isOtherUserTyping, whisperMode: $whisperMode, isPinned: $isPinned, recentMessages: $recentMessages)';
}


}

/// @nodoc
abstract mixin class $ConversationCopyWith<$Res>  {
  factory $ConversationCopyWith(Conversation value, $Res Function(Conversation) _then) = _$ConversationCopyWithImpl;
@useResult
$Res call({
 String id, String type,@JsonKey(name: 'other_user_id') String otherUserId,@JsonKey(name: 'other_user_name') String otherUserName,@JsonKey(name: 'other_user_avatar') String otherUserAvatar,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_time') DateTime? lastMessageTime,@JsonKey(name: 'last_message_read_at') DateTime? lastMessageReadAt,@JsonKey(name: 'last_message_sender_id') String? lastMessageSenderId,@JsonKey(name: 'unread_count') int unreadCount,@JsonKey(name: 'last_message_type') String? lastMessageType,@JsonKey(name: 'is_other_user_typing') bool isOtherUserTyping,@JsonKey(name: 'whisper_mode') int whisperMode,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'recent_messages') List<String> recentMessages
});




}
/// @nodoc
class _$ConversationCopyWithImpl<$Res>
    implements $ConversationCopyWith<$Res> {
  _$ConversationCopyWithImpl(this._self, this._then);

  final Conversation _self;
  final $Res Function(Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? otherUserId = null,Object? otherUserName = null,Object? otherUserAvatar = null,Object? lastMessage = freezed,Object? lastMessageTime = freezed,Object? lastMessageReadAt = freezed,Object? lastMessageSenderId = freezed,Object? unreadCount = null,Object? lastMessageType = freezed,Object? isOtherUserTyping = null,Object? whisperMode = null,Object? isPinned = null,Object? recentMessages = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,otherUserId: null == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String,otherUserName: null == otherUserName ? _self.otherUserName : otherUserName // ignore: cast_nullable_to_non_nullable
as String,otherUserAvatar: null == otherUserAvatar ? _self.otherUserAvatar : otherUserAvatar // ignore: cast_nullable_to_non_nullable
as String,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessageReadAt: freezed == lastMessageReadAt ? _self.lastMessageReadAt : lastMessageReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessageType: freezed == lastMessageType ? _self.lastMessageType : lastMessageType // ignore: cast_nullable_to_non_nullable
as String?,isOtherUserTyping: null == isOtherUserTyping ? _self.isOtherUserTyping : isOtherUserTyping // ignore: cast_nullable_to_non_nullable
as bool,whisperMode: null == whisperMode ? _self.whisperMode : whisperMode // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,recentMessages: null == recentMessages ? _self.recentMessages : recentMessages // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Conversation].
extension ConversationPatterns on Conversation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Conversation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Conversation value)  $default,){
final _that = this;
switch (_that) {
case _Conversation():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Conversation value)?  $default,){
final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String type, @JsonKey(name: 'other_user_id')  String otherUserId, @JsonKey(name: 'other_user_name')  String otherUserName, @JsonKey(name: 'other_user_avatar')  String otherUserAvatar, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  DateTime? lastMessageTime, @JsonKey(name: 'last_message_read_at')  DateTime? lastMessageReadAt, @JsonKey(name: 'last_message_sender_id')  String? lastMessageSenderId, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'last_message_type')  String? lastMessageType, @JsonKey(name: 'is_other_user_typing')  bool isOtherUserTyping, @JsonKey(name: 'whisper_mode')  int whisperMode, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'recent_messages')  List<String> recentMessages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.otherUserId,_that.otherUserName,_that.otherUserAvatar,_that.lastMessage,_that.lastMessageTime,_that.lastMessageReadAt,_that.lastMessageSenderId,_that.unreadCount,_that.lastMessageType,_that.isOtherUserTyping,_that.whisperMode,_that.isPinned,_that.recentMessages);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String type, @JsonKey(name: 'other_user_id')  String otherUserId, @JsonKey(name: 'other_user_name')  String otherUserName, @JsonKey(name: 'other_user_avatar')  String otherUserAvatar, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  DateTime? lastMessageTime, @JsonKey(name: 'last_message_read_at')  DateTime? lastMessageReadAt, @JsonKey(name: 'last_message_sender_id')  String? lastMessageSenderId, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'last_message_type')  String? lastMessageType, @JsonKey(name: 'is_other_user_typing')  bool isOtherUserTyping, @JsonKey(name: 'whisper_mode')  int whisperMode, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'recent_messages')  List<String> recentMessages)  $default,) {final _that = this;
switch (_that) {
case _Conversation():
return $default(_that.id,_that.type,_that.otherUserId,_that.otherUserName,_that.otherUserAvatar,_that.lastMessage,_that.lastMessageTime,_that.lastMessageReadAt,_that.lastMessageSenderId,_that.unreadCount,_that.lastMessageType,_that.isOtherUserTyping,_that.whisperMode,_that.isPinned,_that.recentMessages);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String type, @JsonKey(name: 'other_user_id')  String otherUserId, @JsonKey(name: 'other_user_name')  String otherUserName, @JsonKey(name: 'other_user_avatar')  String otherUserAvatar, @JsonKey(name: 'last_message')  String? lastMessage, @JsonKey(name: 'last_message_time')  DateTime? lastMessageTime, @JsonKey(name: 'last_message_read_at')  DateTime? lastMessageReadAt, @JsonKey(name: 'last_message_sender_id')  String? lastMessageSenderId, @JsonKey(name: 'unread_count')  int unreadCount, @JsonKey(name: 'last_message_type')  String? lastMessageType, @JsonKey(name: 'is_other_user_typing')  bool isOtherUserTyping, @JsonKey(name: 'whisper_mode')  int whisperMode, @JsonKey(name: 'is_pinned')  bool isPinned, @JsonKey(name: 'recent_messages')  List<String> recentMessages)?  $default,) {final _that = this;
switch (_that) {
case _Conversation() when $default != null:
return $default(_that.id,_that.type,_that.otherUserId,_that.otherUserName,_that.otherUserAvatar,_that.lastMessage,_that.lastMessageTime,_that.lastMessageReadAt,_that.lastMessageSenderId,_that.unreadCount,_that.lastMessageType,_that.isOtherUserTyping,_that.whisperMode,_that.isPinned,_that.recentMessages);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Conversation extends Conversation {
  const _Conversation({required this.id, this.type = 'direct', @JsonKey(name: 'other_user_id') required this.otherUserId, @JsonKey(name: 'other_user_name') required this.otherUserName, @JsonKey(name: 'other_user_avatar') required this.otherUserAvatar, @JsonKey(name: 'last_message') this.lastMessage, @JsonKey(name: 'last_message_time') this.lastMessageTime, @JsonKey(name: 'last_message_read_at') this.lastMessageReadAt, @JsonKey(name: 'last_message_sender_id') this.lastMessageSenderId, @JsonKey(name: 'unread_count') this.unreadCount = 0, @JsonKey(name: 'last_message_type') this.lastMessageType, @JsonKey(name: 'is_other_user_typing') this.isOtherUserTyping = false, @JsonKey(name: 'whisper_mode') this.whisperMode = 0, @JsonKey(name: 'is_pinned') this.isPinned = false, @JsonKey(name: 'recent_messages') final  List<String> recentMessages = const []}): _recentMessages = recentMessages,super._();
  factory _Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);

@override final  String id;
@override@JsonKey() final  String type;
@override@JsonKey(name: 'other_user_id') final  String otherUserId;
@override@JsonKey(name: 'other_user_name') final  String otherUserName;
@override@JsonKey(name: 'other_user_avatar') final  String otherUserAvatar;
@override@JsonKey(name: 'last_message') final  String? lastMessage;
@override@JsonKey(name: 'last_message_time') final  DateTime? lastMessageTime;
@override@JsonKey(name: 'last_message_read_at') final  DateTime? lastMessageReadAt;
@override@JsonKey(name: 'last_message_sender_id') final  String? lastMessageSenderId;
@override@JsonKey(name: 'unread_count') final  int unreadCount;
@override@JsonKey(name: 'last_message_type') final  String? lastMessageType;
@override@JsonKey(name: 'is_other_user_typing') final  bool isOtherUserTyping;
@override@JsonKey(name: 'whisper_mode') final  int whisperMode;
@override@JsonKey(name: 'is_pinned') final  bool isPinned;
 final  List<String> _recentMessages;
@override@JsonKey(name: 'recent_messages') List<String> get recentMessages {
  if (_recentMessages is EqualUnmodifiableListView) return _recentMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentMessages);
}


/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationCopyWith<_Conversation> get copyWith => __$ConversationCopyWithImpl<_Conversation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ConversationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Conversation&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.otherUserId, otherUserId) || other.otherUserId == otherUserId)&&(identical(other.otherUserName, otherUserName) || other.otherUserName == otherUserName)&&(identical(other.otherUserAvatar, otherUserAvatar) || other.otherUserAvatar == otherUserAvatar)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage)&&(identical(other.lastMessageTime, lastMessageTime) || other.lastMessageTime == lastMessageTime)&&(identical(other.lastMessageReadAt, lastMessageReadAt) || other.lastMessageReadAt == lastMessageReadAt)&&(identical(other.lastMessageSenderId, lastMessageSenderId) || other.lastMessageSenderId == lastMessageSenderId)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessageType, lastMessageType) || other.lastMessageType == lastMessageType)&&(identical(other.isOtherUserTyping, isOtherUserTyping) || other.isOtherUserTyping == isOtherUserTyping)&&(identical(other.whisperMode, whisperMode) || other.whisperMode == whisperMode)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&const DeepCollectionEquality().equals(other._recentMessages, _recentMessages));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,otherUserId,otherUserName,otherUserAvatar,lastMessage,lastMessageTime,lastMessageReadAt,lastMessageSenderId,unreadCount,lastMessageType,isOtherUserTyping,whisperMode,isPinned,const DeepCollectionEquality().hash(_recentMessages));

@override
String toString() {
  return 'Conversation(id: $id, type: $type, otherUserId: $otherUserId, otherUserName: $otherUserName, otherUserAvatar: $otherUserAvatar, lastMessage: $lastMessage, lastMessageTime: $lastMessageTime, lastMessageReadAt: $lastMessageReadAt, lastMessageSenderId: $lastMessageSenderId, unreadCount: $unreadCount, lastMessageType: $lastMessageType, isOtherUserTyping: $isOtherUserTyping, whisperMode: $whisperMode, isPinned: $isPinned, recentMessages: $recentMessages)';
}


}

/// @nodoc
abstract mixin class _$ConversationCopyWith<$Res> implements $ConversationCopyWith<$Res> {
  factory _$ConversationCopyWith(_Conversation value, $Res Function(_Conversation) _then) = __$ConversationCopyWithImpl;
@override @useResult
$Res call({
 String id, String type,@JsonKey(name: 'other_user_id') String otherUserId,@JsonKey(name: 'other_user_name') String otherUserName,@JsonKey(name: 'other_user_avatar') String otherUserAvatar,@JsonKey(name: 'last_message') String? lastMessage,@JsonKey(name: 'last_message_time') DateTime? lastMessageTime,@JsonKey(name: 'last_message_read_at') DateTime? lastMessageReadAt,@JsonKey(name: 'last_message_sender_id') String? lastMessageSenderId,@JsonKey(name: 'unread_count') int unreadCount,@JsonKey(name: 'last_message_type') String? lastMessageType,@JsonKey(name: 'is_other_user_typing') bool isOtherUserTyping,@JsonKey(name: 'whisper_mode') int whisperMode,@JsonKey(name: 'is_pinned') bool isPinned,@JsonKey(name: 'recent_messages') List<String> recentMessages
});




}
/// @nodoc
class __$ConversationCopyWithImpl<$Res>
    implements _$ConversationCopyWith<$Res> {
  __$ConversationCopyWithImpl(this._self, this._then);

  final _Conversation _self;
  final $Res Function(_Conversation) _then;

/// Create a copy of Conversation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? otherUserId = null,Object? otherUserName = null,Object? otherUserAvatar = null,Object? lastMessage = freezed,Object? lastMessageTime = freezed,Object? lastMessageReadAt = freezed,Object? lastMessageSenderId = freezed,Object? unreadCount = null,Object? lastMessageType = freezed,Object? isOtherUserTyping = null,Object? whisperMode = null,Object? isPinned = null,Object? recentMessages = null,}) {
  return _then(_Conversation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,otherUserId: null == otherUserId ? _self.otherUserId : otherUserId // ignore: cast_nullable_to_non_nullable
as String,otherUserName: null == otherUserName ? _self.otherUserName : otherUserName // ignore: cast_nullable_to_non_nullable
as String,otherUserAvatar: null == otherUserAvatar ? _self.otherUserAvatar : otherUserAvatar // ignore: cast_nullable_to_non_nullable
as String,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as String?,lastMessageTime: freezed == lastMessageTime ? _self.lastMessageTime : lastMessageTime // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessageReadAt: freezed == lastMessageReadAt ? _self.lastMessageReadAt : lastMessageReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastMessageSenderId: freezed == lastMessageSenderId ? _self.lastMessageSenderId : lastMessageSenderId // ignore: cast_nullable_to_non_nullable
as String?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessageType: freezed == lastMessageType ? _self.lastMessageType : lastMessageType // ignore: cast_nullable_to_non_nullable
as String?,isOtherUserTyping: null == isOtherUserTyping ? _self.isOtherUserTyping : isOtherUserTyping // ignore: cast_nullable_to_non_nullable
as bool,whisperMode: null == whisperMode ? _self.whisperMode : whisperMode // ignore: cast_nullable_to_non_nullable
as int,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,recentMessages: null == recentMessages ? _self._recentMessages : recentMessages // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
