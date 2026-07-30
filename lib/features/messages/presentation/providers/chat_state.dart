import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/models/chat_theme.dart';

/// Per-message delivery status for sent messages.
/// Mirrors WhatsApp/Telegram-style indicators: single check → double check → blue.
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Immutable UI state for the chat screen.
/// Extracted from the 4,571-line _ChatScreenState in chat_screen.dart.
/// Does NOT include RealtimeChannel subscriptions — those live in the Provider.
class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final bool isRecording;
  final int recordDuration;
  final Message? replyMessage;
  final Message? editingMessage;
  final List<String> smartReplies;
  final bool showingSmartReplies;
  final ChatTheme? activeTheme;
  final int whisperMode;
  final int lastActiveWhisperMode;
  final int ephemeralDuration;
  final String? backgroundUrl;
  final double bgOpacity;
  final double bgBrightness;
  final String mediaViewMode;
  final Color? bubbleColorSent;
  final Color? bubbleColorReceived;
  final Color? textColorSent;
  final Color? textColorReceived;
  final bool encryptionReady;
  final List<XFile> selectedImages;
  final File? selectedVideo;
  final File? selectedAudio;
  final PlatformFile? selectedFile;
  final double whisperDragProgress;
  final double whisperDragOffset;
  final bool whisperTriggered;
  final String? otherUserName;
  final String? otherUserId;
  final String? otherUserAvatar;
  final String? highlightedMessageId;
  final String conversationType;
  final List<String> participantIds;
  final Map<String, MessageStatus> messageStatuses;
  final Map<String, String> clientIdToServerId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isRecording = false,
    this.recordDuration = 0,
    this.replyMessage,
    this.editingMessage,
    this.smartReplies = const [],
    this.showingSmartReplies = false,
    this.activeTheme,
    this.whisperMode = 0,
    this.lastActiveWhisperMode = 1,
    this.ephemeralDuration = 86400,
    this.backgroundUrl,
    this.bgOpacity = 1.0,
    this.bgBrightness = 0.7,
    this.mediaViewMode = 'unlimited',
    this.bubbleColorSent,
    this.bubbleColorReceived,
    this.textColorSent,
    this.textColorReceived,
    this.encryptionReady = false,
    this.selectedImages = const [],
    this.selectedVideo,
    this.selectedAudio,
    this.selectedFile,
    this.whisperDragProgress = 0.0,
    this.whisperDragOffset = 0.0,
    this.whisperTriggered = false,
    this.otherUserName,
    this.otherUserId,
    this.otherUserAvatar,
    this.highlightedMessageId,
    this.conversationType = 'direct',
    this.participantIds = const [],
    this.messageStatuses = const {},
    this.clientIdToServerId = const {},
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isRecording,
    int? recordDuration,
    Object? replyMessage = _sentinel,
    Object? editingMessage = _sentinel,
    List<String>? smartReplies,
    bool? showingSmartReplies,
    ChatTheme? activeTheme,
    int? whisperMode,
    int? lastActiveWhisperMode,
    int? ephemeralDuration,
    Object? backgroundUrl = _sentinel,
    double? bgOpacity,
    double? bgBrightness,
    String? mediaViewMode,
    Object? bubbleColorSent = _sentinel,
    Object? bubbleColorReceived = _sentinel,
    Object? textColorSent = _sentinel,
    Object? textColorReceived = _sentinel,
    bool? encryptionReady,
    List<XFile>? selectedImages,
    Object? selectedVideo = _sentinel,
    Object? selectedAudio = _sentinel,
    Object? selectedFile = _sentinel,
    double? whisperDragProgress,
    double? whisperDragOffset,
    bool? whisperTriggered,
    Object? otherUserName = _sentinel,
    Object? otherUserId = _sentinel,
    Object? otherUserAvatar = _sentinel,
    Object? highlightedMessageId = _sentinel,
    String? conversationType,
    List<String>? participantIds,
    Map<String, MessageStatus>? messageStatuses,
    Map<String, String>? clientIdToServerId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isRecording: isRecording ?? this.isRecording,
      recordDuration: recordDuration ?? this.recordDuration,
      replyMessage: replyMessage == _sentinel
          ? this.replyMessage
          : (replyMessage as Message?),
      editingMessage: editingMessage == _sentinel
          ? this.editingMessage
          : editingMessage as Message?,
      smartReplies: smartReplies ?? this.smartReplies,
      showingSmartReplies: showingSmartReplies ?? this.showingSmartReplies,
      activeTheme: activeTheme ?? this.activeTheme,
      whisperMode: whisperMode ?? this.whisperMode,
      lastActiveWhisperMode:
          lastActiveWhisperMode ?? this.lastActiveWhisperMode,
      ephemeralDuration: ephemeralDuration ?? this.ephemeralDuration,
      backgroundUrl: backgroundUrl == _sentinel
          ? this.backgroundUrl
          : (backgroundUrl as String?),
      bgOpacity: bgOpacity ?? this.bgOpacity,
      bgBrightness: bgBrightness ?? this.bgBrightness,
      mediaViewMode: mediaViewMode ?? this.mediaViewMode,
      bubbleColorSent: bubbleColorSent == _sentinel
          ? this.bubbleColorSent
          : (bubbleColorSent as Color?),
      bubbleColorReceived: bubbleColorReceived == _sentinel
          ? this.bubbleColorReceived
          : (bubbleColorReceived as Color?),
      textColorSent: textColorSent == _sentinel
          ? this.textColorSent
          : (textColorSent as Color?),
      textColorReceived: textColorReceived == _sentinel
          ? this.textColorReceived
          : (textColorReceived as Color?),
      encryptionReady: encryptionReady ?? this.encryptionReady,
      selectedImages: selectedImages ?? this.selectedImages,
      selectedVideo: selectedVideo == _sentinel
          ? this.selectedVideo
          : (selectedVideo as File?),
      selectedAudio: selectedAudio == _sentinel
          ? this.selectedAudio
          : (selectedAudio as File?),
      selectedFile: selectedFile == _sentinel
          ? this.selectedFile
          : (selectedFile as PlatformFile?),
      whisperDragProgress: whisperDragProgress ?? this.whisperDragProgress,
      whisperDragOffset: whisperDragOffset ?? this.whisperDragOffset,
      whisperTriggered: whisperTriggered ?? this.whisperTriggered,
      otherUserName: otherUserName == _sentinel
          ? this.otherUserName
          : (otherUserName as String?),
      otherUserId: otherUserId == _sentinel
          ? this.otherUserId
          : (otherUserId as String?),
      otherUserAvatar: otherUserAvatar == _sentinel
          ? this.otherUserAvatar
          : (otherUserAvatar as String?),
      highlightedMessageId: highlightedMessageId == _sentinel
          ? this.highlightedMessageId
          : (highlightedMessageId as String?),
      conversationType: conversationType ?? this.conversationType,
      participantIds: participantIds ?? this.participantIds,
      messageStatuses: messageStatuses ?? this.messageStatuses,
      clientIdToServerId: clientIdToServerId ?? this.clientIdToServerId,
    );
  }
}

const _sentinel = Object();
