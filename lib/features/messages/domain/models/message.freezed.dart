// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Message {

 String get id;@JsonKey(name: 'conversation_id') String get conversationId;@JsonKey(name: 'sender_id') String get senderId;@JsonKey(name: 'sender_name') String get senderName;@JsonKey(name: 'sender_avatar') String get senderAvatar; String get content;@JsonKey(name: 'is_read') bool get isRead;@JsonKey(name: 'read_at') DateTime? get readAt;@JsonKey(name: 'any_read_at') DateTime? get anyReadAt;@JsonKey(name: 'created_at') DateTime get timestamp;@JsonKey(name: 'message_type') MessageType get messageType;@JsonKey(name: 'media_url') String? get mediaUrl;@JsonKey(name: 'media_thumbnail_url') String? get mediaThumbnailUrl;@JsonKey(name: 'file_name') String? get mediaFileName;@JsonKey(name: 'file_size') int? get mediaFileSize;@JsonKey(name: 'media_mime_type') String? get mediaMimeType;@JsonKey(name: 'poll_data') Map<String, dynamic>? get pollData;@JsonKey(name: 'location_data') Map<String, dynamic>? get locationData;@JsonKey(name: 'share_data') Map<String, dynamic>? get shareData;@JsonKey(name: 'voice_duration') int? get voiceDuration;@JsonKey(name: 'reply_to_id') String? get replyToId; String? get replyToContent; String? get replyToSenderName; Map<String, dynamic>? get replyToData; List<MessageReactionModel> get reactions;@JsonKey(name: 'is_ephemeral') bool get isEphemeral;@JsonKey(name: 'is_spoiler') bool get isSpoiler;@JsonKey(name: 'ephemeral_duration') int get ephemeralDuration;@JsonKey(name: 'whisper_mode') String get whisperMode;@JsonKey(name: 'expires_at') DateTime? get expiresAt;@JsonKey(name: 'encrypted_keys') Map<String, dynamic>? get encryptedKeys; String? get iv;@JsonKey(name: 'signal_message_type') int? get signalMessageType;@JsonKey(name: 'signal_sender_content') String? get signalSenderContent;@JsonKey(name: 'signal_sender_message_type') int? get signalSenderMessageType;// PQ-Aura Post-Quantum encryption fields
@JsonKey(name: 'pq_aura_header') String? get pqAuraHeader;@JsonKey(name: 'pq_aura_payload') String? get pqAuraPayload;@JsonKey(name: 'pq_aura_sender_header') String? get pqAuraSenderHeader;@JsonKey(name: 'pq_aura_sender_payload') String? get pqAuraSenderPayload;@JsonKey(name: 'ripple_id') String? get rippleId;@JsonKey(name: 'story_id') String? get storyId;@JsonKey(name: 'post_id') String? get postId;@JsonKey(name: 'media_view_mode') String get mediaViewMode;@JsonKey(name: 'current_user_view_count') int get currentUserViewCount;@JsonKey(includeFromJson: false, includeToJson: false) bool get isUploading;@JsonKey(includeFromJson: false, includeToJson: false) double get uploadProgress;
/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageCopyWith<Message> get copyWith => _$MessageCopyWithImpl<Message>(this as Message, _$identity);

  /// Serializes this Message to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Message&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatar, senderAvatar) || other.senderAvatar == senderAvatar)&&(identical(other.content, content) || other.content == content)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.anyReadAt, anyReadAt) || other.anyReadAt == anyReadAt)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.mediaUrl, mediaUrl) || other.mediaUrl == mediaUrl)&&(identical(other.mediaThumbnailUrl, mediaThumbnailUrl) || other.mediaThumbnailUrl == mediaThumbnailUrl)&&(identical(other.mediaFileName, mediaFileName) || other.mediaFileName == mediaFileName)&&(identical(other.mediaFileSize, mediaFileSize) || other.mediaFileSize == mediaFileSize)&&(identical(other.mediaMimeType, mediaMimeType) || other.mediaMimeType == mediaMimeType)&&const DeepCollectionEquality().equals(other.pollData, pollData)&&const DeepCollectionEquality().equals(other.locationData, locationData)&&const DeepCollectionEquality().equals(other.shareData, shareData)&&(identical(other.voiceDuration, voiceDuration) || other.voiceDuration == voiceDuration)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToSenderName, replyToSenderName) || other.replyToSenderName == replyToSenderName)&&const DeepCollectionEquality().equals(other.replyToData, replyToData)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.isEphemeral, isEphemeral) || other.isEphemeral == isEphemeral)&&(identical(other.isSpoiler, isSpoiler) || other.isSpoiler == isSpoiler)&&(identical(other.ephemeralDuration, ephemeralDuration) || other.ephemeralDuration == ephemeralDuration)&&(identical(other.whisperMode, whisperMode) || other.whisperMode == whisperMode)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other.encryptedKeys, encryptedKeys)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.signalMessageType, signalMessageType) || other.signalMessageType == signalMessageType)&&(identical(other.signalSenderContent, signalSenderContent) || other.signalSenderContent == signalSenderContent)&&(identical(other.signalSenderMessageType, signalSenderMessageType) || other.signalSenderMessageType == signalSenderMessageType)&&(identical(other.pqAuraHeader, pqAuraHeader) || other.pqAuraHeader == pqAuraHeader)&&(identical(other.pqAuraPayload, pqAuraPayload) || other.pqAuraPayload == pqAuraPayload)&&(identical(other.pqAuraSenderHeader, pqAuraSenderHeader) || other.pqAuraSenderHeader == pqAuraSenderHeader)&&(identical(other.pqAuraSenderPayload, pqAuraSenderPayload) || other.pqAuraSenderPayload == pqAuraSenderPayload)&&(identical(other.rippleId, rippleId) || other.rippleId == rippleId)&&(identical(other.storyId, storyId) || other.storyId == storyId)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.mediaViewMode, mediaViewMode) || other.mediaViewMode == mediaViewMode)&&(identical(other.currentUserViewCount, currentUserViewCount) || other.currentUserViewCount == currentUserViewCount)&&(identical(other.isUploading, isUploading) || other.isUploading == isUploading)&&(identical(other.uploadProgress, uploadProgress) || other.uploadProgress == uploadProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,conversationId,senderId,senderName,senderAvatar,content,isRead,readAt,anyReadAt,timestamp,messageType,mediaUrl,mediaThumbnailUrl,mediaFileName,mediaFileSize,mediaMimeType,const DeepCollectionEquality().hash(pollData),const DeepCollectionEquality().hash(locationData),const DeepCollectionEquality().hash(shareData),voiceDuration,replyToId,replyToContent,replyToSenderName,const DeepCollectionEquality().hash(replyToData),const DeepCollectionEquality().hash(reactions),isEphemeral,isSpoiler,ephemeralDuration,whisperMode,expiresAt,const DeepCollectionEquality().hash(encryptedKeys),iv,signalMessageType,signalSenderContent,signalSenderMessageType,pqAuraHeader,pqAuraPayload,pqAuraSenderHeader,pqAuraSenderPayload,rippleId,storyId,postId,mediaViewMode,currentUserViewCount,isUploading,uploadProgress]);

@override
String toString() {
  return 'Message(id: $id, conversationId: $conversationId, senderId: $senderId, senderName: $senderName, senderAvatar: $senderAvatar, content: $content, isRead: $isRead, readAt: $readAt, anyReadAt: $anyReadAt, timestamp: $timestamp, messageType: $messageType, mediaUrl: $mediaUrl, mediaThumbnailUrl: $mediaThumbnailUrl, mediaFileName: $mediaFileName, mediaFileSize: $mediaFileSize, mediaMimeType: $mediaMimeType, pollData: $pollData, locationData: $locationData, shareData: $shareData, voiceDuration: $voiceDuration, replyToId: $replyToId, replyToContent: $replyToContent, replyToSenderName: $replyToSenderName, replyToData: $replyToData, reactions: $reactions, isEphemeral: $isEphemeral, isSpoiler: $isSpoiler, ephemeralDuration: $ephemeralDuration, whisperMode: $whisperMode, expiresAt: $expiresAt, encryptedKeys: $encryptedKeys, iv: $iv, signalMessageType: $signalMessageType, signalSenderContent: $signalSenderContent, signalSenderMessageType: $signalSenderMessageType, pqAuraHeader: $pqAuraHeader, pqAuraPayload: $pqAuraPayload, pqAuraSenderHeader: $pqAuraSenderHeader, pqAuraSenderPayload: $pqAuraSenderPayload, rippleId: $rippleId, storyId: $storyId, postId: $postId, mediaViewMode: $mediaViewMode, currentUserViewCount: $currentUserViewCount, isUploading: $isUploading, uploadProgress: $uploadProgress)';
}


}

/// @nodoc
abstract mixin class $MessageCopyWith<$Res>  {
  factory $MessageCopyWith(Message value, $Res Function(Message) _then) = _$MessageCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'conversation_id') String conversationId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'sender_name') String senderName,@JsonKey(name: 'sender_avatar') String senderAvatar, String content,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'any_read_at') DateTime? anyReadAt,@JsonKey(name: 'created_at') DateTime timestamp,@JsonKey(name: 'message_type') MessageType messageType,@JsonKey(name: 'media_url') String? mediaUrl,@JsonKey(name: 'media_thumbnail_url') String? mediaThumbnailUrl,@JsonKey(name: 'file_name') String? mediaFileName,@JsonKey(name: 'file_size') int? mediaFileSize,@JsonKey(name: 'media_mime_type') String? mediaMimeType,@JsonKey(name: 'poll_data') Map<String, dynamic>? pollData,@JsonKey(name: 'location_data') Map<String, dynamic>? locationData,@JsonKey(name: 'share_data') Map<String, dynamic>? shareData,@JsonKey(name: 'voice_duration') int? voiceDuration,@JsonKey(name: 'reply_to_id') String? replyToId, String? replyToContent, String? replyToSenderName, Map<String, dynamic>? replyToData, List<MessageReactionModel> reactions,@JsonKey(name: 'is_ephemeral') bool isEphemeral,@JsonKey(name: 'is_spoiler') bool isSpoiler,@JsonKey(name: 'ephemeral_duration') int ephemeralDuration,@JsonKey(name: 'whisper_mode') String whisperMode,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'encrypted_keys') Map<String, dynamic>? encryptedKeys, String? iv,@JsonKey(name: 'signal_message_type') int? signalMessageType,@JsonKey(name: 'signal_sender_content') String? signalSenderContent,@JsonKey(name: 'signal_sender_message_type') int? signalSenderMessageType,@JsonKey(name: 'pq_aura_header') String? pqAuraHeader,@JsonKey(name: 'pq_aura_payload') String? pqAuraPayload,@JsonKey(name: 'pq_aura_sender_header') String? pqAuraSenderHeader,@JsonKey(name: 'pq_aura_sender_payload') String? pqAuraSenderPayload,@JsonKey(name: 'ripple_id') String? rippleId,@JsonKey(name: 'story_id') String? storyId,@JsonKey(name: 'post_id') String? postId,@JsonKey(name: 'media_view_mode') String mediaViewMode,@JsonKey(name: 'current_user_view_count') int currentUserViewCount,@JsonKey(includeFromJson: false, includeToJson: false) bool isUploading,@JsonKey(includeFromJson: false, includeToJson: false) double uploadProgress
});




}
/// @nodoc
class _$MessageCopyWithImpl<$Res>
    implements $MessageCopyWith<$Res> {
  _$MessageCopyWithImpl(this._self, this._then);

  final Message _self;
  final $Res Function(Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? senderName = null,Object? senderAvatar = null,Object? content = null,Object? isRead = null,Object? readAt = freezed,Object? anyReadAt = freezed,Object? timestamp = null,Object? messageType = null,Object? mediaUrl = freezed,Object? mediaThumbnailUrl = freezed,Object? mediaFileName = freezed,Object? mediaFileSize = freezed,Object? mediaMimeType = freezed,Object? pollData = freezed,Object? locationData = freezed,Object? shareData = freezed,Object? voiceDuration = freezed,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToSenderName = freezed,Object? replyToData = freezed,Object? reactions = null,Object? isEphemeral = null,Object? isSpoiler = null,Object? ephemeralDuration = null,Object? whisperMode = null,Object? expiresAt = freezed,Object? encryptedKeys = freezed,Object? iv = freezed,Object? signalMessageType = freezed,Object? signalSenderContent = freezed,Object? signalSenderMessageType = freezed,Object? pqAuraHeader = freezed,Object? pqAuraPayload = freezed,Object? pqAuraSenderHeader = freezed,Object? pqAuraSenderPayload = freezed,Object? rippleId = freezed,Object? storyId = freezed,Object? postId = freezed,Object? mediaViewMode = null,Object? currentUserViewCount = null,Object? isUploading = null,Object? uploadProgress = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,senderAvatar: null == senderAvatar ? _self.senderAvatar : senderAvatar // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,anyReadAt: freezed == anyReadAt ? _self.anyReadAt : anyReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as MessageType,mediaUrl: freezed == mediaUrl ? _self.mediaUrl : mediaUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaThumbnailUrl: freezed == mediaThumbnailUrl ? _self.mediaThumbnailUrl : mediaThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaFileName: freezed == mediaFileName ? _self.mediaFileName : mediaFileName // ignore: cast_nullable_to_non_nullable
as String?,mediaFileSize: freezed == mediaFileSize ? _self.mediaFileSize : mediaFileSize // ignore: cast_nullable_to_non_nullable
as int?,mediaMimeType: freezed == mediaMimeType ? _self.mediaMimeType : mediaMimeType // ignore: cast_nullable_to_non_nullable
as String?,pollData: freezed == pollData ? _self.pollData : pollData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,locationData: freezed == locationData ? _self.locationData : locationData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,shareData: freezed == shareData ? _self.shareData : shareData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,voiceDuration: freezed == voiceDuration ? _self.voiceDuration : voiceDuration // ignore: cast_nullable_to_non_nullable
as int?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderName: freezed == replyToSenderName ? _self.replyToSenderName : replyToSenderName // ignore: cast_nullable_to_non_nullable
as String?,replyToData: freezed == replyToData ? _self.replyToData : replyToData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReactionModel>,isEphemeral: null == isEphemeral ? _self.isEphemeral : isEphemeral // ignore: cast_nullable_to_non_nullable
as bool,isSpoiler: null == isSpoiler ? _self.isSpoiler : isSpoiler // ignore: cast_nullable_to_non_nullable
as bool,ephemeralDuration: null == ephemeralDuration ? _self.ephemeralDuration : ephemeralDuration // ignore: cast_nullable_to_non_nullable
as int,whisperMode: null == whisperMode ? _self.whisperMode : whisperMode // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,encryptedKeys: freezed == encryptedKeys ? _self.encryptedKeys : encryptedKeys // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,iv: freezed == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as String?,signalMessageType: freezed == signalMessageType ? _self.signalMessageType : signalMessageType // ignore: cast_nullable_to_non_nullable
as int?,signalSenderContent: freezed == signalSenderContent ? _self.signalSenderContent : signalSenderContent // ignore: cast_nullable_to_non_nullable
as String?,signalSenderMessageType: freezed == signalSenderMessageType ? _self.signalSenderMessageType : signalSenderMessageType // ignore: cast_nullable_to_non_nullable
as int?,pqAuraHeader: freezed == pqAuraHeader ? _self.pqAuraHeader : pqAuraHeader // ignore: cast_nullable_to_non_nullable
as String?,pqAuraPayload: freezed == pqAuraPayload ? _self.pqAuraPayload : pqAuraPayload // ignore: cast_nullable_to_non_nullable
as String?,pqAuraSenderHeader: freezed == pqAuraSenderHeader ? _self.pqAuraSenderHeader : pqAuraSenderHeader // ignore: cast_nullable_to_non_nullable
as String?,pqAuraSenderPayload: freezed == pqAuraSenderPayload ? _self.pqAuraSenderPayload : pqAuraSenderPayload // ignore: cast_nullable_to_non_nullable
as String?,rippleId: freezed == rippleId ? _self.rippleId : rippleId // ignore: cast_nullable_to_non_nullable
as String?,storyId: freezed == storyId ? _self.storyId : storyId // ignore: cast_nullable_to_non_nullable
as String?,postId: freezed == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String?,mediaViewMode: null == mediaViewMode ? _self.mediaViewMode : mediaViewMode // ignore: cast_nullable_to_non_nullable
as String,currentUserViewCount: null == currentUserViewCount ? _self.currentUserViewCount : currentUserViewCount // ignore: cast_nullable_to_non_nullable
as int,isUploading: null == isUploading ? _self.isUploading : isUploading // ignore: cast_nullable_to_non_nullable
as bool,uploadProgress: null == uploadProgress ? _self.uploadProgress : uploadProgress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Message].
extension MessagePatterns on Message {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Message value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Message value)  $default,){
final _that = this;
switch (_that) {
case _Message():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Message value)?  $default,){
final _that = this;
switch (_that) {
case _Message() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'conversation_id')  String conversationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_avatar')  String senderAvatar,  String content, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'any_read_at')  DateTime? anyReadAt, @JsonKey(name: 'created_at')  DateTime timestamp, @JsonKey(name: 'message_type')  MessageType messageType, @JsonKey(name: 'media_url')  String? mediaUrl, @JsonKey(name: 'media_thumbnail_url')  String? mediaThumbnailUrl, @JsonKey(name: 'file_name')  String? mediaFileName, @JsonKey(name: 'file_size')  int? mediaFileSize, @JsonKey(name: 'media_mime_type')  String? mediaMimeType, @JsonKey(name: 'poll_data')  Map<String, dynamic>? pollData, @JsonKey(name: 'location_data')  Map<String, dynamic>? locationData, @JsonKey(name: 'share_data')  Map<String, dynamic>? shareData, @JsonKey(name: 'voice_duration')  int? voiceDuration, @JsonKey(name: 'reply_to_id')  String? replyToId,  String? replyToContent,  String? replyToSenderName,  Map<String, dynamic>? replyToData,  List<MessageReactionModel> reactions, @JsonKey(name: 'is_ephemeral')  bool isEphemeral, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'ephemeral_duration')  int ephemeralDuration, @JsonKey(name: 'whisper_mode')  String whisperMode, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'encrypted_keys')  Map<String, dynamic>? encryptedKeys,  String? iv, @JsonKey(name: 'signal_message_type')  int? signalMessageType, @JsonKey(name: 'signal_sender_content')  String? signalSenderContent, @JsonKey(name: 'signal_sender_message_type')  int? signalSenderMessageType, @JsonKey(name: 'pq_aura_header')  String? pqAuraHeader, @JsonKey(name: 'pq_aura_payload')  String? pqAuraPayload, @JsonKey(name: 'pq_aura_sender_header')  String? pqAuraSenderHeader, @JsonKey(name: 'pq_aura_sender_payload')  String? pqAuraSenderPayload, @JsonKey(name: 'ripple_id')  String? rippleId, @JsonKey(name: 'story_id')  String? storyId, @JsonKey(name: 'post_id')  String? postId, @JsonKey(name: 'media_view_mode')  String mediaViewMode, @JsonKey(name: 'current_user_view_count')  int currentUserViewCount, @JsonKey(includeFromJson: false, includeToJson: false)  bool isUploading, @JsonKey(includeFromJson: false, includeToJson: false)  double uploadProgress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderName,_that.senderAvatar,_that.content,_that.isRead,_that.readAt,_that.anyReadAt,_that.timestamp,_that.messageType,_that.mediaUrl,_that.mediaThumbnailUrl,_that.mediaFileName,_that.mediaFileSize,_that.mediaMimeType,_that.pollData,_that.locationData,_that.shareData,_that.voiceDuration,_that.replyToId,_that.replyToContent,_that.replyToSenderName,_that.replyToData,_that.reactions,_that.isEphemeral,_that.isSpoiler,_that.ephemeralDuration,_that.whisperMode,_that.expiresAt,_that.encryptedKeys,_that.iv,_that.signalMessageType,_that.signalSenderContent,_that.signalSenderMessageType,_that.pqAuraHeader,_that.pqAuraPayload,_that.pqAuraSenderHeader,_that.pqAuraSenderPayload,_that.rippleId,_that.storyId,_that.postId,_that.mediaViewMode,_that.currentUserViewCount,_that.isUploading,_that.uploadProgress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'conversation_id')  String conversationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_avatar')  String senderAvatar,  String content, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'any_read_at')  DateTime? anyReadAt, @JsonKey(name: 'created_at')  DateTime timestamp, @JsonKey(name: 'message_type')  MessageType messageType, @JsonKey(name: 'media_url')  String? mediaUrl, @JsonKey(name: 'media_thumbnail_url')  String? mediaThumbnailUrl, @JsonKey(name: 'file_name')  String? mediaFileName, @JsonKey(name: 'file_size')  int? mediaFileSize, @JsonKey(name: 'media_mime_type')  String? mediaMimeType, @JsonKey(name: 'poll_data')  Map<String, dynamic>? pollData, @JsonKey(name: 'location_data')  Map<String, dynamic>? locationData, @JsonKey(name: 'share_data')  Map<String, dynamic>? shareData, @JsonKey(name: 'voice_duration')  int? voiceDuration, @JsonKey(name: 'reply_to_id')  String? replyToId,  String? replyToContent,  String? replyToSenderName,  Map<String, dynamic>? replyToData,  List<MessageReactionModel> reactions, @JsonKey(name: 'is_ephemeral')  bool isEphemeral, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'ephemeral_duration')  int ephemeralDuration, @JsonKey(name: 'whisper_mode')  String whisperMode, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'encrypted_keys')  Map<String, dynamic>? encryptedKeys,  String? iv, @JsonKey(name: 'signal_message_type')  int? signalMessageType, @JsonKey(name: 'signal_sender_content')  String? signalSenderContent, @JsonKey(name: 'signal_sender_message_type')  int? signalSenderMessageType, @JsonKey(name: 'pq_aura_header')  String? pqAuraHeader, @JsonKey(name: 'pq_aura_payload')  String? pqAuraPayload, @JsonKey(name: 'pq_aura_sender_header')  String? pqAuraSenderHeader, @JsonKey(name: 'pq_aura_sender_payload')  String? pqAuraSenderPayload, @JsonKey(name: 'ripple_id')  String? rippleId, @JsonKey(name: 'story_id')  String? storyId, @JsonKey(name: 'post_id')  String? postId, @JsonKey(name: 'media_view_mode')  String mediaViewMode, @JsonKey(name: 'current_user_view_count')  int currentUserViewCount, @JsonKey(includeFromJson: false, includeToJson: false)  bool isUploading, @JsonKey(includeFromJson: false, includeToJson: false)  double uploadProgress)  $default,) {final _that = this;
switch (_that) {
case _Message():
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderName,_that.senderAvatar,_that.content,_that.isRead,_that.readAt,_that.anyReadAt,_that.timestamp,_that.messageType,_that.mediaUrl,_that.mediaThumbnailUrl,_that.mediaFileName,_that.mediaFileSize,_that.mediaMimeType,_that.pollData,_that.locationData,_that.shareData,_that.voiceDuration,_that.replyToId,_that.replyToContent,_that.replyToSenderName,_that.replyToData,_that.reactions,_that.isEphemeral,_that.isSpoiler,_that.ephemeralDuration,_that.whisperMode,_that.expiresAt,_that.encryptedKeys,_that.iv,_that.signalMessageType,_that.signalSenderContent,_that.signalSenderMessageType,_that.pqAuraHeader,_that.pqAuraPayload,_that.pqAuraSenderHeader,_that.pqAuraSenderPayload,_that.rippleId,_that.storyId,_that.postId,_that.mediaViewMode,_that.currentUserViewCount,_that.isUploading,_that.uploadProgress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'conversation_id')  String conversationId, @JsonKey(name: 'sender_id')  String senderId, @JsonKey(name: 'sender_name')  String senderName, @JsonKey(name: 'sender_avatar')  String senderAvatar,  String content, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'any_read_at')  DateTime? anyReadAt, @JsonKey(name: 'created_at')  DateTime timestamp, @JsonKey(name: 'message_type')  MessageType messageType, @JsonKey(name: 'media_url')  String? mediaUrl, @JsonKey(name: 'media_thumbnail_url')  String? mediaThumbnailUrl, @JsonKey(name: 'file_name')  String? mediaFileName, @JsonKey(name: 'file_size')  int? mediaFileSize, @JsonKey(name: 'media_mime_type')  String? mediaMimeType, @JsonKey(name: 'poll_data')  Map<String, dynamic>? pollData, @JsonKey(name: 'location_data')  Map<String, dynamic>? locationData, @JsonKey(name: 'share_data')  Map<String, dynamic>? shareData, @JsonKey(name: 'voice_duration')  int? voiceDuration, @JsonKey(name: 'reply_to_id')  String? replyToId,  String? replyToContent,  String? replyToSenderName,  Map<String, dynamic>? replyToData,  List<MessageReactionModel> reactions, @JsonKey(name: 'is_ephemeral')  bool isEphemeral, @JsonKey(name: 'is_spoiler')  bool isSpoiler, @JsonKey(name: 'ephemeral_duration')  int ephemeralDuration, @JsonKey(name: 'whisper_mode')  String whisperMode, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'encrypted_keys')  Map<String, dynamic>? encryptedKeys,  String? iv, @JsonKey(name: 'signal_message_type')  int? signalMessageType, @JsonKey(name: 'signal_sender_content')  String? signalSenderContent, @JsonKey(name: 'signal_sender_message_type')  int? signalSenderMessageType, @JsonKey(name: 'pq_aura_header')  String? pqAuraHeader, @JsonKey(name: 'pq_aura_payload')  String? pqAuraPayload, @JsonKey(name: 'pq_aura_sender_header')  String? pqAuraSenderHeader, @JsonKey(name: 'pq_aura_sender_payload')  String? pqAuraSenderPayload, @JsonKey(name: 'ripple_id')  String? rippleId, @JsonKey(name: 'story_id')  String? storyId, @JsonKey(name: 'post_id')  String? postId, @JsonKey(name: 'media_view_mode')  String mediaViewMode, @JsonKey(name: 'current_user_view_count')  int currentUserViewCount, @JsonKey(includeFromJson: false, includeToJson: false)  bool isUploading, @JsonKey(includeFromJson: false, includeToJson: false)  double uploadProgress)?  $default,) {final _that = this;
switch (_that) {
case _Message() when $default != null:
return $default(_that.id,_that.conversationId,_that.senderId,_that.senderName,_that.senderAvatar,_that.content,_that.isRead,_that.readAt,_that.anyReadAt,_that.timestamp,_that.messageType,_that.mediaUrl,_that.mediaThumbnailUrl,_that.mediaFileName,_that.mediaFileSize,_that.mediaMimeType,_that.pollData,_that.locationData,_that.shareData,_that.voiceDuration,_that.replyToId,_that.replyToContent,_that.replyToSenderName,_that.replyToData,_that.reactions,_that.isEphemeral,_that.isSpoiler,_that.ephemeralDuration,_that.whisperMode,_that.expiresAt,_that.encryptedKeys,_that.iv,_that.signalMessageType,_that.signalSenderContent,_that.signalSenderMessageType,_that.pqAuraHeader,_that.pqAuraPayload,_that.pqAuraSenderHeader,_that.pqAuraSenderPayload,_that.rippleId,_that.storyId,_that.postId,_that.mediaViewMode,_that.currentUserViewCount,_that.isUploading,_that.uploadProgress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Message extends Message {
  const _Message({required this.id, @JsonKey(name: 'conversation_id') required this.conversationId, @JsonKey(name: 'sender_id') required this.senderId, @JsonKey(name: 'sender_name') this.senderName = '', @JsonKey(name: 'sender_avatar') this.senderAvatar = '', this.content = '', @JsonKey(name: 'is_read') this.isRead = false, @JsonKey(name: 'read_at') this.readAt, @JsonKey(name: 'any_read_at') this.anyReadAt, @JsonKey(name: 'created_at') required this.timestamp, @JsonKey(name: 'message_type') this.messageType = MessageType.text, @JsonKey(name: 'media_url') this.mediaUrl, @JsonKey(name: 'media_thumbnail_url') this.mediaThumbnailUrl, @JsonKey(name: 'file_name') this.mediaFileName, @JsonKey(name: 'file_size') this.mediaFileSize, @JsonKey(name: 'media_mime_type') this.mediaMimeType, @JsonKey(name: 'poll_data') final  Map<String, dynamic>? pollData, @JsonKey(name: 'location_data') final  Map<String, dynamic>? locationData, @JsonKey(name: 'share_data') final  Map<String, dynamic>? shareData, @JsonKey(name: 'voice_duration') this.voiceDuration, @JsonKey(name: 'reply_to_id') this.replyToId, this.replyToContent, this.replyToSenderName, final  Map<String, dynamic>? replyToData, final  List<MessageReactionModel> reactions = const [], @JsonKey(name: 'is_ephemeral') this.isEphemeral = false, @JsonKey(name: 'is_spoiler') this.isSpoiler = false, @JsonKey(name: 'ephemeral_duration') this.ephemeralDuration = 86400, @JsonKey(name: 'whisper_mode') this.whisperMode = 'OFF', @JsonKey(name: 'expires_at') this.expiresAt, @JsonKey(name: 'encrypted_keys') final  Map<String, dynamic>? encryptedKeys, this.iv, @JsonKey(name: 'signal_message_type') this.signalMessageType, @JsonKey(name: 'signal_sender_content') this.signalSenderContent, @JsonKey(name: 'signal_sender_message_type') this.signalSenderMessageType, @JsonKey(name: 'pq_aura_header') this.pqAuraHeader, @JsonKey(name: 'pq_aura_payload') this.pqAuraPayload, @JsonKey(name: 'pq_aura_sender_header') this.pqAuraSenderHeader, @JsonKey(name: 'pq_aura_sender_payload') this.pqAuraSenderPayload, @JsonKey(name: 'ripple_id') this.rippleId, @JsonKey(name: 'story_id') this.storyId, @JsonKey(name: 'post_id') this.postId, @JsonKey(name: 'media_view_mode') this.mediaViewMode = 'unlimited', @JsonKey(name: 'current_user_view_count') this.currentUserViewCount = 0, @JsonKey(includeFromJson: false, includeToJson: false) this.isUploading = false, @JsonKey(includeFromJson: false, includeToJson: false) this.uploadProgress = 0.0}): _pollData = pollData,_locationData = locationData,_shareData = shareData,_replyToData = replyToData,_reactions = reactions,_encryptedKeys = encryptedKeys,super._();
  factory _Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

@override final  String id;
@override@JsonKey(name: 'conversation_id') final  String conversationId;
@override@JsonKey(name: 'sender_id') final  String senderId;
@override@JsonKey(name: 'sender_name') final  String senderName;
@override@JsonKey(name: 'sender_avatar') final  String senderAvatar;
@override@JsonKey() final  String content;
@override@JsonKey(name: 'is_read') final  bool isRead;
@override@JsonKey(name: 'read_at') final  DateTime? readAt;
@override@JsonKey(name: 'any_read_at') final  DateTime? anyReadAt;
@override@JsonKey(name: 'created_at') final  DateTime timestamp;
@override@JsonKey(name: 'message_type') final  MessageType messageType;
@override@JsonKey(name: 'media_url') final  String? mediaUrl;
@override@JsonKey(name: 'media_thumbnail_url') final  String? mediaThumbnailUrl;
@override@JsonKey(name: 'file_name') final  String? mediaFileName;
@override@JsonKey(name: 'file_size') final  int? mediaFileSize;
@override@JsonKey(name: 'media_mime_type') final  String? mediaMimeType;
 final  Map<String, dynamic>? _pollData;
@override@JsonKey(name: 'poll_data') Map<String, dynamic>? get pollData {
  final value = _pollData;
  if (value == null) return null;
  if (_pollData is EqualUnmodifiableMapView) return _pollData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _locationData;
@override@JsonKey(name: 'location_data') Map<String, dynamic>? get locationData {
  final value = _locationData;
  if (value == null) return null;
  if (_locationData is EqualUnmodifiableMapView) return _locationData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _shareData;
@override@JsonKey(name: 'share_data') Map<String, dynamic>? get shareData {
  final value = _shareData;
  if (value == null) return null;
  if (_shareData is EqualUnmodifiableMapView) return _shareData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'voice_duration') final  int? voiceDuration;
@override@JsonKey(name: 'reply_to_id') final  String? replyToId;
@override final  String? replyToContent;
@override final  String? replyToSenderName;
 final  Map<String, dynamic>? _replyToData;
@override Map<String, dynamic>? get replyToData {
  final value = _replyToData;
  if (value == null) return null;
  if (_replyToData is EqualUnmodifiableMapView) return _replyToData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<MessageReactionModel> _reactions;
@override@JsonKey() List<MessageReactionModel> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

@override@JsonKey(name: 'is_ephemeral') final  bool isEphemeral;
@override@JsonKey(name: 'is_spoiler') final  bool isSpoiler;
@override@JsonKey(name: 'ephemeral_duration') final  int ephemeralDuration;
@override@JsonKey(name: 'whisper_mode') final  String whisperMode;
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;
 final  Map<String, dynamic>? _encryptedKeys;
@override@JsonKey(name: 'encrypted_keys') Map<String, dynamic>? get encryptedKeys {
  final value = _encryptedKeys;
  if (value == null) return null;
  if (_encryptedKeys is EqualUnmodifiableMapView) return _encryptedKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  String? iv;
@override@JsonKey(name: 'signal_message_type') final  int? signalMessageType;
@override@JsonKey(name: 'signal_sender_content') final  String? signalSenderContent;
@override@JsonKey(name: 'signal_sender_message_type') final  int? signalSenderMessageType;
// PQ-Aura Post-Quantum encryption fields
@override@JsonKey(name: 'pq_aura_header') final  String? pqAuraHeader;
@override@JsonKey(name: 'pq_aura_payload') final  String? pqAuraPayload;
@override@JsonKey(name: 'pq_aura_sender_header') final  String? pqAuraSenderHeader;
@override@JsonKey(name: 'pq_aura_sender_payload') final  String? pqAuraSenderPayload;
@override@JsonKey(name: 'ripple_id') final  String? rippleId;
@override@JsonKey(name: 'story_id') final  String? storyId;
@override@JsonKey(name: 'post_id') final  String? postId;
@override@JsonKey(name: 'media_view_mode') final  String mediaViewMode;
@override@JsonKey(name: 'current_user_view_count') final  int currentUserViewCount;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool isUploading;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  double uploadProgress;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageCopyWith<_Message> get copyWith => __$MessageCopyWithImpl<_Message>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Message&&(identical(other.id, id) || other.id == id)&&(identical(other.conversationId, conversationId) || other.conversationId == conversationId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.senderName, senderName) || other.senderName == senderName)&&(identical(other.senderAvatar, senderAvatar) || other.senderAvatar == senderAvatar)&&(identical(other.content, content) || other.content == content)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.anyReadAt, anyReadAt) || other.anyReadAt == anyReadAt)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.mediaUrl, mediaUrl) || other.mediaUrl == mediaUrl)&&(identical(other.mediaThumbnailUrl, mediaThumbnailUrl) || other.mediaThumbnailUrl == mediaThumbnailUrl)&&(identical(other.mediaFileName, mediaFileName) || other.mediaFileName == mediaFileName)&&(identical(other.mediaFileSize, mediaFileSize) || other.mediaFileSize == mediaFileSize)&&(identical(other.mediaMimeType, mediaMimeType) || other.mediaMimeType == mediaMimeType)&&const DeepCollectionEquality().equals(other._pollData, _pollData)&&const DeepCollectionEquality().equals(other._locationData, _locationData)&&const DeepCollectionEquality().equals(other._shareData, _shareData)&&(identical(other.voiceDuration, voiceDuration) || other.voiceDuration == voiceDuration)&&(identical(other.replyToId, replyToId) || other.replyToId == replyToId)&&(identical(other.replyToContent, replyToContent) || other.replyToContent == replyToContent)&&(identical(other.replyToSenderName, replyToSenderName) || other.replyToSenderName == replyToSenderName)&&const DeepCollectionEquality().equals(other._replyToData, _replyToData)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.isEphemeral, isEphemeral) || other.isEphemeral == isEphemeral)&&(identical(other.isSpoiler, isSpoiler) || other.isSpoiler == isSpoiler)&&(identical(other.ephemeralDuration, ephemeralDuration) || other.ephemeralDuration == ephemeralDuration)&&(identical(other.whisperMode, whisperMode) || other.whisperMode == whisperMode)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&const DeepCollectionEquality().equals(other._encryptedKeys, _encryptedKeys)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.signalMessageType, signalMessageType) || other.signalMessageType == signalMessageType)&&(identical(other.signalSenderContent, signalSenderContent) || other.signalSenderContent == signalSenderContent)&&(identical(other.signalSenderMessageType, signalSenderMessageType) || other.signalSenderMessageType == signalSenderMessageType)&&(identical(other.pqAuraHeader, pqAuraHeader) || other.pqAuraHeader == pqAuraHeader)&&(identical(other.pqAuraPayload, pqAuraPayload) || other.pqAuraPayload == pqAuraPayload)&&(identical(other.pqAuraSenderHeader, pqAuraSenderHeader) || other.pqAuraSenderHeader == pqAuraSenderHeader)&&(identical(other.pqAuraSenderPayload, pqAuraSenderPayload) || other.pqAuraSenderPayload == pqAuraSenderPayload)&&(identical(other.rippleId, rippleId) || other.rippleId == rippleId)&&(identical(other.storyId, storyId) || other.storyId == storyId)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.mediaViewMode, mediaViewMode) || other.mediaViewMode == mediaViewMode)&&(identical(other.currentUserViewCount, currentUserViewCount) || other.currentUserViewCount == currentUserViewCount)&&(identical(other.isUploading, isUploading) || other.isUploading == isUploading)&&(identical(other.uploadProgress, uploadProgress) || other.uploadProgress == uploadProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,conversationId,senderId,senderName,senderAvatar,content,isRead,readAt,anyReadAt,timestamp,messageType,mediaUrl,mediaThumbnailUrl,mediaFileName,mediaFileSize,mediaMimeType,const DeepCollectionEquality().hash(_pollData),const DeepCollectionEquality().hash(_locationData),const DeepCollectionEquality().hash(_shareData),voiceDuration,replyToId,replyToContent,replyToSenderName,const DeepCollectionEquality().hash(_replyToData),const DeepCollectionEquality().hash(_reactions),isEphemeral,isSpoiler,ephemeralDuration,whisperMode,expiresAt,const DeepCollectionEquality().hash(_encryptedKeys),iv,signalMessageType,signalSenderContent,signalSenderMessageType,pqAuraHeader,pqAuraPayload,pqAuraSenderHeader,pqAuraSenderPayload,rippleId,storyId,postId,mediaViewMode,currentUserViewCount,isUploading,uploadProgress]);

@override
String toString() {
  return 'Message(id: $id, conversationId: $conversationId, senderId: $senderId, senderName: $senderName, senderAvatar: $senderAvatar, content: $content, isRead: $isRead, readAt: $readAt, anyReadAt: $anyReadAt, timestamp: $timestamp, messageType: $messageType, mediaUrl: $mediaUrl, mediaThumbnailUrl: $mediaThumbnailUrl, mediaFileName: $mediaFileName, mediaFileSize: $mediaFileSize, mediaMimeType: $mediaMimeType, pollData: $pollData, locationData: $locationData, shareData: $shareData, voiceDuration: $voiceDuration, replyToId: $replyToId, replyToContent: $replyToContent, replyToSenderName: $replyToSenderName, replyToData: $replyToData, reactions: $reactions, isEphemeral: $isEphemeral, isSpoiler: $isSpoiler, ephemeralDuration: $ephemeralDuration, whisperMode: $whisperMode, expiresAt: $expiresAt, encryptedKeys: $encryptedKeys, iv: $iv, signalMessageType: $signalMessageType, signalSenderContent: $signalSenderContent, signalSenderMessageType: $signalSenderMessageType, pqAuraHeader: $pqAuraHeader, pqAuraPayload: $pqAuraPayload, pqAuraSenderHeader: $pqAuraSenderHeader, pqAuraSenderPayload: $pqAuraSenderPayload, rippleId: $rippleId, storyId: $storyId, postId: $postId, mediaViewMode: $mediaViewMode, currentUserViewCount: $currentUserViewCount, isUploading: $isUploading, uploadProgress: $uploadProgress)';
}


}

/// @nodoc
abstract mixin class _$MessageCopyWith<$Res> implements $MessageCopyWith<$Res> {
  factory _$MessageCopyWith(_Message value, $Res Function(_Message) _then) = __$MessageCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'conversation_id') String conversationId,@JsonKey(name: 'sender_id') String senderId,@JsonKey(name: 'sender_name') String senderName,@JsonKey(name: 'sender_avatar') String senderAvatar, String content,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'any_read_at') DateTime? anyReadAt,@JsonKey(name: 'created_at') DateTime timestamp,@JsonKey(name: 'message_type') MessageType messageType,@JsonKey(name: 'media_url') String? mediaUrl,@JsonKey(name: 'media_thumbnail_url') String? mediaThumbnailUrl,@JsonKey(name: 'file_name') String? mediaFileName,@JsonKey(name: 'file_size') int? mediaFileSize,@JsonKey(name: 'media_mime_type') String? mediaMimeType,@JsonKey(name: 'poll_data') Map<String, dynamic>? pollData,@JsonKey(name: 'location_data') Map<String, dynamic>? locationData,@JsonKey(name: 'share_data') Map<String, dynamic>? shareData,@JsonKey(name: 'voice_duration') int? voiceDuration,@JsonKey(name: 'reply_to_id') String? replyToId, String? replyToContent, String? replyToSenderName, Map<String, dynamic>? replyToData, List<MessageReactionModel> reactions,@JsonKey(name: 'is_ephemeral') bool isEphemeral,@JsonKey(name: 'is_spoiler') bool isSpoiler,@JsonKey(name: 'ephemeral_duration') int ephemeralDuration,@JsonKey(name: 'whisper_mode') String whisperMode,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'encrypted_keys') Map<String, dynamic>? encryptedKeys, String? iv,@JsonKey(name: 'signal_message_type') int? signalMessageType,@JsonKey(name: 'signal_sender_content') String? signalSenderContent,@JsonKey(name: 'signal_sender_message_type') int? signalSenderMessageType,@JsonKey(name: 'pq_aura_header') String? pqAuraHeader,@JsonKey(name: 'pq_aura_payload') String? pqAuraPayload,@JsonKey(name: 'pq_aura_sender_header') String? pqAuraSenderHeader,@JsonKey(name: 'pq_aura_sender_payload') String? pqAuraSenderPayload,@JsonKey(name: 'ripple_id') String? rippleId,@JsonKey(name: 'story_id') String? storyId,@JsonKey(name: 'post_id') String? postId,@JsonKey(name: 'media_view_mode') String mediaViewMode,@JsonKey(name: 'current_user_view_count') int currentUserViewCount,@JsonKey(includeFromJson: false, includeToJson: false) bool isUploading,@JsonKey(includeFromJson: false, includeToJson: false) double uploadProgress
});




}
/// @nodoc
class __$MessageCopyWithImpl<$Res>
    implements _$MessageCopyWith<$Res> {
  __$MessageCopyWithImpl(this._self, this._then);

  final _Message _self;
  final $Res Function(_Message) _then;

/// Create a copy of Message
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? conversationId = null,Object? senderId = null,Object? senderName = null,Object? senderAvatar = null,Object? content = null,Object? isRead = null,Object? readAt = freezed,Object? anyReadAt = freezed,Object? timestamp = null,Object? messageType = null,Object? mediaUrl = freezed,Object? mediaThumbnailUrl = freezed,Object? mediaFileName = freezed,Object? mediaFileSize = freezed,Object? mediaMimeType = freezed,Object? pollData = freezed,Object? locationData = freezed,Object? shareData = freezed,Object? voiceDuration = freezed,Object? replyToId = freezed,Object? replyToContent = freezed,Object? replyToSenderName = freezed,Object? replyToData = freezed,Object? reactions = null,Object? isEphemeral = null,Object? isSpoiler = null,Object? ephemeralDuration = null,Object? whisperMode = null,Object? expiresAt = freezed,Object? encryptedKeys = freezed,Object? iv = freezed,Object? signalMessageType = freezed,Object? signalSenderContent = freezed,Object? signalSenderMessageType = freezed,Object? pqAuraHeader = freezed,Object? pqAuraPayload = freezed,Object? pqAuraSenderHeader = freezed,Object? pqAuraSenderPayload = freezed,Object? rippleId = freezed,Object? storyId = freezed,Object? postId = freezed,Object? mediaViewMode = null,Object? currentUserViewCount = null,Object? isUploading = null,Object? uploadProgress = null,}) {
  return _then(_Message(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,conversationId: null == conversationId ? _self.conversationId : conversationId // ignore: cast_nullable_to_non_nullable
as String,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as String,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,senderAvatar: null == senderAvatar ? _self.senderAvatar : senderAvatar // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,anyReadAt: freezed == anyReadAt ? _self.anyReadAt : anyReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as MessageType,mediaUrl: freezed == mediaUrl ? _self.mediaUrl : mediaUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaThumbnailUrl: freezed == mediaThumbnailUrl ? _self.mediaThumbnailUrl : mediaThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,mediaFileName: freezed == mediaFileName ? _self.mediaFileName : mediaFileName // ignore: cast_nullable_to_non_nullable
as String?,mediaFileSize: freezed == mediaFileSize ? _self.mediaFileSize : mediaFileSize // ignore: cast_nullable_to_non_nullable
as int?,mediaMimeType: freezed == mediaMimeType ? _self.mediaMimeType : mediaMimeType // ignore: cast_nullable_to_non_nullable
as String?,pollData: freezed == pollData ? _self._pollData : pollData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,locationData: freezed == locationData ? _self._locationData : locationData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,shareData: freezed == shareData ? _self._shareData : shareData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,voiceDuration: freezed == voiceDuration ? _self.voiceDuration : voiceDuration // ignore: cast_nullable_to_non_nullable
as int?,replyToId: freezed == replyToId ? _self.replyToId : replyToId // ignore: cast_nullable_to_non_nullable
as String?,replyToContent: freezed == replyToContent ? _self.replyToContent : replyToContent // ignore: cast_nullable_to_non_nullable
as String?,replyToSenderName: freezed == replyToSenderName ? _self.replyToSenderName : replyToSenderName // ignore: cast_nullable_to_non_nullable
as String?,replyToData: freezed == replyToData ? _self._replyToData : replyToData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<MessageReactionModel>,isEphemeral: null == isEphemeral ? _self.isEphemeral : isEphemeral // ignore: cast_nullable_to_non_nullable
as bool,isSpoiler: null == isSpoiler ? _self.isSpoiler : isSpoiler // ignore: cast_nullable_to_non_nullable
as bool,ephemeralDuration: null == ephemeralDuration ? _self.ephemeralDuration : ephemeralDuration // ignore: cast_nullable_to_non_nullable
as int,whisperMode: null == whisperMode ? _self.whisperMode : whisperMode // ignore: cast_nullable_to_non_nullable
as String,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,encryptedKeys: freezed == encryptedKeys ? _self._encryptedKeys : encryptedKeys // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,iv: freezed == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as String?,signalMessageType: freezed == signalMessageType ? _self.signalMessageType : signalMessageType // ignore: cast_nullable_to_non_nullable
as int?,signalSenderContent: freezed == signalSenderContent ? _self.signalSenderContent : signalSenderContent // ignore: cast_nullable_to_non_nullable
as String?,signalSenderMessageType: freezed == signalSenderMessageType ? _self.signalSenderMessageType : signalSenderMessageType // ignore: cast_nullable_to_non_nullable
as int?,pqAuraHeader: freezed == pqAuraHeader ? _self.pqAuraHeader : pqAuraHeader // ignore: cast_nullable_to_non_nullable
as String?,pqAuraPayload: freezed == pqAuraPayload ? _self.pqAuraPayload : pqAuraPayload // ignore: cast_nullable_to_non_nullable
as String?,pqAuraSenderHeader: freezed == pqAuraSenderHeader ? _self.pqAuraSenderHeader : pqAuraSenderHeader // ignore: cast_nullable_to_non_nullable
as String?,pqAuraSenderPayload: freezed == pqAuraSenderPayload ? _self.pqAuraSenderPayload : pqAuraSenderPayload // ignore: cast_nullable_to_non_nullable
as String?,rippleId: freezed == rippleId ? _self.rippleId : rippleId // ignore: cast_nullable_to_non_nullable
as String?,storyId: freezed == storyId ? _self.storyId : storyId // ignore: cast_nullable_to_non_nullable
as String?,postId: freezed == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String?,mediaViewMode: null == mediaViewMode ? _self.mediaViewMode : mediaViewMode // ignore: cast_nullable_to_non_nullable
as String,currentUserViewCount: null == currentUserViewCount ? _self.currentUserViewCount : currentUserViewCount // ignore: cast_nullable_to_non_nullable
as int,isUploading: null == isUploading ? _self.isUploading : isUploading // ignore: cast_nullable_to_non_nullable
as bool,uploadProgress: null == uploadProgress ? _self.uploadProgress : uploadProgress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
