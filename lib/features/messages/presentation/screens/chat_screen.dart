import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/providers/typing_indicator_provider.dart';
import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/features/messages/presentation/screens/chat_details_screen.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/widgets/security_pin_sheet.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:go_router/go_router.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/messages/presentation/providers/providers.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_app_bar.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_background.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_message_list.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_typing_indicator.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_input_area.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/chat_whisper_gesture.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/reply_preview.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/image_preview.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/video_preview.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/audio_preview.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/file_preview.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/attachment_options_sheet.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/attachment_options_menu.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/message_options_sheet.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/message_options_menu.dart';
import 'package:oasis/features/messages/data/datasources/chat_media_picker.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/giphy_picker_sheet.dart';
import 'package:oasis/features/messages/presentation/widgets/modals/location_duration_sheet.dart';

import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';

/// Fully wired ChatScreen — thin orchestrator composing extracted widgets.
/// Replaces the 4,682-line legacy chat_screen.dart.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? otherUserId;
  final VoidCallback? onDetailsToggle;
  final bool isDetailsOpen;
  final double? bgOpacity;
  final double? bgBrightness;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.otherUserName,
    this.otherUserAvatar,
    this.otherUserId,
    this.onDetailsToggle,
    this.isDetailsOpen = false,
    this.bgOpacity,
    this.bgBrightness,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ChatProvider _chatProvider;
  late ChatEncryptionProvider _encryptionProvider;
  late ChatSettingsProvider _settingsProvider;
  late ChatRecordingProvider _recordingProvider;
  late ChatReactionsProvider _reactionsProvider;

  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<String> _textNotifier = ValueNotifier<String>('');
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ChatMediaPicker _mediaPicker = ChatMediaPicker();

  Timer? _typingDebounceTimer;
  Timer? _typingThrottleTimer;
  bool _isTypingThrottled = false;

  bool _isSpoiler = false;
  late VaultService _vaultService;
  late PresenceProvider _presenceProvider;
  late TypingIndicatorProvider _typingProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Create providers
    final messagingService = context.read<MessagingService>();
    _encryptionProvider = ChatEncryptionProvider();
    _settingsProvider = ChatSettingsProvider(
      conversationId: widget.conversationId,
      messagingService: messagingService,
    );
    _recordingProvider = ChatRecordingProvider();
    _reactionsProvider =
        ChatReactionsProvider(messagingService: messagingService);

    _chatProvider = ChatProvider(
      conversationId: widget.conversationId,
      otherUserId: widget.otherUserId,
      scrollController: _scrollController,
      encryptionProvider: _encryptionProvider,
      settingsProvider: _settingsProvider,
      messagingService: messagingService,
    );

    _recordingProvider.addListener(() {
      if (mounted) {
        _chatProvider.setState(
          (s) => s.copyWith(
            isRecording: _recordingProvider.isRecording,
            recordDuration: _recordingProvider.recordDuration,
          ),
        );
      }
    });

    _recordingProvider.onRecordingComplete = (path, duration) async {
      await _chatProvider.sendAudioMessage(
        audioPath: path,
        duration: duration,
      );
    };

    _recordingProvider.onError = (error) => _showError(error);

    _chatProvider.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    };

    _chatProvider.onReloadRequested = () {
      if (mounted) _chatProvider.loadMessages(silent: true);
    };

    _chatProvider.onEncryptionNeeded = (status) {
      if (mounted) _handleEncryptionNeeded(status);
    };

    _messageController.addListener(() {
      if (!mounted) return;
      _textNotifier.value = _messageController.text;
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        final text = _messageController.text;
        final isTyping = text.isNotEmpty;
        final typingProvider = context.read<TypingIndicatorProvider>();

        if (isTyping) {
          // Throttle: Send true immediately if not throttled
          if (!_isTypingThrottled) {
            typingProvider.setTyping(widget.conversationId, userId, true);
            _isTypingThrottled = true;
            _typingThrottleTimer = Timer(const Duration(seconds: 2), () {
              _isTypingThrottled = false;
            });
          }
          
          // Debounce: Reset to false after 2 seconds of no typing
          _typingDebounceTimer?.cancel();
          _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
            typingProvider.setTyping(widget.conversationId, userId, false);
          });
        } else {
          // If text is empty, send false immediately and cancel timers
          _typingDebounceTimer?.cancel();
          typingProvider.setTyping(widget.conversationId, userId, false);
        }
      }
    });

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _chatProvider.initialize();

    // Subscribe to presence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final otherId = widget.otherUserId ?? _chatProvider.state.otherUserId;
      if (otherId != null) {
        context.read<PresenceProvider>().subscribeToUserPresence(otherId);
      }
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        context.read<TypingIndicatorProvider>().subscribeToTypingStatus(
          widget.conversationId,
          userId,
        );
      }
      // Immediately reset unread badge in the inbox — no delay needed
      context.read<ConversationProvider>().markAsRead(widget.conversationId);

      // Clear any active notification group for this chat
      NotificationManager.instance.clearGroup(widget.conversationId);

      // Check if vault needs to be unlocked on entry
      _checkVaultOnEntry();
    });
  }

  Future<void> _checkVaultOnEntry() async {
    // Ensure vault service is initialized
    await _vaultService.isReady;
    
    if (!mounted) return;

    if (_vaultService.isInVaultSync(widget.conversationId) &&
        !_vaultService.isItemUnlocked(widget.conversationId)) {
      final authenticated = await _vaultService.authenticate(
        itemId: widget.conversationId,
        context: context,
      );
      if (!authenticated && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vaultService = Provider.of<VaultService>(context);
    _presenceProvider = Provider.of<PresenceProvider>(context, listen: false);
    _typingProvider = Provider.of<TypingIndicatorProvider>(context, listen: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatProvider.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    _typingDebounceTimer?.cancel();
    _typingThrottleTimer?.cancel();

    // Capture IDs before state is gone
    final otherId = widget.otherUserId ?? _chatProvider.state.otherUserId;
    final convId = widget.conversationId;

    if (otherId != null) {
      _presenceProvider.unsubscribeFromUserPresence(otherId);
    }
    _typingProvider.unsubscribeFromTypingStatus(convId);

    // Lock chat if interval is set to On Chat Close
    _vaultService.lockOnChatClose(widget.conversationId);

    _chatProvider.dispose();
    _encryptionProvider.dispose();
    _settingsProvider.dispose();
    _recordingProvider.dispose();

    _messageController.dispose();
    _textNotifier.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // =========================================================================
  // Encryption
  // =========================================================================

  Future<void> _handleEncryptionNeeded(EncryptionStatus status) async {
    final success = await SecurityPinSheet.show(context, status);
    if (success == true) {
      // Encryption is now ready, reinitialize the provider
      _chatProvider.setState((s) => s.copyWith(encryptionReady: true));
      await _chatProvider.loadMessages(silent: true);
    }
  }

  // =========================================================================
  // Media Picking
  // =========================================================================

  Future<void> _pickImage() async {
    try {
      if (Platform.isWindows) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
          initialDirectory: await _mediaPicker.getInitialDirectory(),
        );
        if (result != null && result.paths.isNotEmpty) {
          final images = result.paths.where((path) => path != null).map((path) => XFile(path!)).toList();
          _chatProvider.setState(
            (s) => s.copyWith(selectedImages: [...s.selectedImages, ...images]),
          );
        }
      } else {
        final images = await _mediaPicker.pickMultiImage();
        if (images.isNotEmpty) {
          _chatProvider.setState((s) => s.copyWith(selectedImages: [...s.selectedImages, ...images]));
        }
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      if (Platform.isWindows) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          initialDirectory: await _mediaPicker.getInitialDirectory(),
        );
        if (result != null && result.files.single.path != null) {
          _chatProvider.setState(
            (s) => s.copyWith(selectedVideo: File(result.files.single.path!)),
          );
        }
      } else {
        final video = await _mediaPicker.pickVideo();
        if (video != null) {
          _chatProvider.setState(
            (s) => s.copyWith(selectedVideo: File(video.path)),
          );
        }
      }
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await _mediaPicker.pickFile();
      if (result != null) {
        _chatProvider.setState((s) => s.copyWith(selectedFile: result));
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      final result = await _mediaPicker.pickAudio();
      if (result != null) {
        _chatProvider.setState((s) => s.copyWith(selectedAudio: result));
      }
    } catch (e) {
      _showError('Error picking audio: $e');
    }
  }

  // =========================================================================
  // Recording
  // =========================================================================

  Future<void> _toggleRecording() async {
    await _recordingProvider.toggleRecording();
  }

  // =========================================================================
  // Message Actions
  // =========================================================================

  void _showGiphyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder:
          (context) => GiphyPickerSheet(
            onSelected: (url, isSticker) {
              if (isSticker) {
                _chatProvider.sendSticker(
                  url,
                  replyMessage: _chatProvider.state.replyMessage,
                );
              } else {
                _chatProvider.sendGif(
                  url,
                  replyMessage: _chatProvider.state.replyMessage,
                );
              }
            },
          ),
    );
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    final state = _chatProvider.state;

    // Capture media state locally before clearing (for the call to provider)
    final images = state.selectedImages;
    final videoFile = state.selectedVideo;
    final audioFile = state.selectedAudio;
    final docFile = state.selectedFile;
    final replyMessage = state.replyMessage;
    final mediaViewMode = state.mediaViewMode;

    if (content.isEmpty &&
        images.isEmpty &&
        videoFile == null &&
        audioFile == null &&
        docFile == null) {
      return;
    }

    // Clear text input immediately for snappy UX
    _messageController.clear();
    _textNotifier.value = '';

    try {
      if (images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          await _chatProvider.sendMessage(
            content: i == 0 ? content : '',
            imageFile: images[i],
            replyMessage: i == 0 ? replyMessage : null,
            mediaViewMode: mediaViewMode,
            isSpoiler: _isSpoiler,
          );
        }
      } else {
        await _chatProvider.sendMessage(
          content: content,
          videoFile: videoFile,
          audioFile: audioFile,
          docFile: docFile,
          replyMessage: replyMessage,
          mediaViewMode: mediaViewMode,
          isSpoiler: _isSpoiler,
        );
      }
      
      // Reset spoiler state after sending
      if (_isSpoiler) {
        setState(() => _isSpoiler = false);
      }
    } catch (e) {
      _showError('Error sending message: $e');
    }
  }

  void _toggleSpoiler() {
    HapticUtils.lightImpact();
    setState(() => _isSpoiler = !_isSpoiler);
  }

  Future<void> _unsendMessage(Message message) async {
    await _chatProvider.unsendMessage(message);
  }

  void _showMessageOptions(Message message, Offset? position) {
    final currentUserId = AuthService().currentUser?.id;
    final isOwn = message.senderId == currentUserId;

    if (ResponsiveLayout.isDesktop(context) && position != null) {
      MessageOptionsMenu(
        message: message,
        isOwnMessage: isOwn,
        position: position,
        onReply: () => _setReplyMessage(message),
        onForward: () {},
        onCopy: () {
          Clipboard.setData(ClipboardData(text: message.content));
        },
        onUnsend: () => _unsendMessage(message),
        onReactionSelected: (emoji) async {
          await _reactionsProvider.onReactionSelected(
            message: message,
            reaction: emoji,
            userId: currentUserId ?? '',
            username: AuthService().currentUser?.username ?? 'Unknown',
            currentReactions: message.reactions,
            onReactionsUpdated: (updatedReactions) {
              _chatProvider.updateMessageReactions(
                message.id,
                updatedReactions,
              );
            },
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useRootNavigator: true,
        builder:
            (context) => MessageOptionsSheet(
              message: message,
              isOwnMessage: isOwn,
              onReply: () => _setReplyMessage(message),
              onForward: () {},
              onCopy: () {
                Clipboard.setData(ClipboardData(text: message.content));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
              onUnsend: () => _unsendMessage(message),
              onReactionSelected: (emoji) async {
                await _reactionsProvider.onReactionSelected(
                  message: message,
                  reaction: emoji,
                  userId: currentUserId ?? '',
                  username: AuthService().currentUser?.username ?? 'Unknown',
                  currentReactions: message.reactions,
                  onReactionsUpdated: (updatedReactions) {
                    _chatProvider.updateMessageReactions(
                      message.id,
                      updatedReactions,
                    );
                  },
                );
              },
            ),
      );
    }
  }

  void _setReplyMessage(Message message) {
    _chatProvider.setState((s) => s.copyWith(replyMessage: message));
    _focusNode.requestFocus();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder:
          (context) => AttachmentOptionsSheet(
            onPhotoSelected: _pickImage,
            onVideoSelected: _pickVideo,
            onFileSelected: _pickFile,
            onAudioSelected: _pickAudio,
            onLocationSelected: _showLocationDurationOptions,
          ),
    );
  }

  void _showLocationDurationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder:
          (context) => LocationDurationSheet(
            onDurationSelected: (duration) async {
               try {
                 await _chatProvider.shareLiveLocation(duration);
               } catch (e) {
                 _showError('Failed to share location: $e');
               }
            },
          ),
    );
  }

  void _openChatDetails() {
    final state = _chatProvider.state;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChangeNotifierProvider.value(
              value: _chatProvider,
              child: ChatDetailsScreen(
                conversationId: widget.conversationId,
                otherUserName:
                    widget.otherUserName ?? state.otherUserName ?? 'Unknown',
                otherUserAvatar: widget.otherUserAvatar ?? '',
                otherUserId: widget.otherUserId ?? state.otherUserId ?? '',
                whisperMode: state.whisperMode,
                currentBackground: state.backgroundUrl,
                onBackgroundSettingsChanged: (opacity, brightness) {
                  _chatProvider.setState(
                    (s) => s.copyWith(
                      bgOpacity: opacity,
                      bgBrightness: brightness,
                    ),
                  );
                },
              ),
            ),
      ),
    );
  }

  Future<void> _initiateCall(CallType type) async {
    final callProvider = context.read<CallProvider>();
    final currentUserId = AuthService().currentUser?.id;
    final otherUserId = widget.otherUserId ?? _chatProvider.state.otherUserId;

    if (currentUserId == null || otherUserId == null) {
      _showError('Cannot initiate call: User info missing');
      return;
    }

    try {
      final call = await callProvider.initiateCall(
        conversationId: widget.conversationId,
        callerId: currentUserId,
        receiverId: otherUserId,
        type: type,
      );
      if (call != null && mounted) {
        context.pushNamed('active_call', pathParameters: {'callId': call.id});
      } else if (mounted && callProvider.state.error != null) {
        _showError(callProvider.state.error!);
      }
    } catch (e) {
      _showError('Failed to initiate call: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return ChangeNotifierProvider.value(
      value: _chatProvider,
      child: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final state = chatProvider.state;
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return PopScope(
            canPop: !_focusNode
                .hasFocus, // Enable predictive back when keyboard is down
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;

              if (_focusNode.hasFocus) {
                // If keyboard is up, just dismiss it
                _focusNode.unfocus();
              }
            },
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                body: Stack(
                  children: [
                    // Background
                    ChatBackground(
                      backgroundUrl: state.backgroundUrl,
                      bgOpacity: state.bgOpacity,
                      bgBrightness: state.bgBrightness,
                    ),

                    // Main content
                    Column(
                      children: [
                        // Message list
                        Expanded(
                          child: ChatMessageList(
                            messages: state.messages,
                            isLoading: state.isLoading,
                            currentUserId: AuthService().currentUser?.id,
                            onMessageLongPress: _showMessageOptions,
                            onMessageDoubleTap: (message) async {
                              final currentUserId =
                                  AuthService().currentUser?.id;
                              if (currentUserId != null) {
                                await _reactionsProvider.onReactionSelected(
                                  message: message,
                                  reaction: '❤️',
                                  userId: currentUserId,
                                  username:
                                      AuthService().currentUser?.username ??
                                      'Unknown',
                                  currentReactions: message.reactions,
                                  onReactionsUpdated: (updatedReactions) {
                                    _chatProvider.updateMessageReactions(
                                      message.id,
                                      updatedReactions,
                                    );
                                  },
                                );
                              }
                            },
                            onReply: _setReplyMessage,
                            bubbleColorSent: state.bubbleColorSent,
                            bubbleColorReceived: state.bubbleColorReceived,
                            textColorSent: state.textColorSent,
                            textColorReceived: state.textColorReceived,
                            scrollController: _scrollController,
                            highlightedMessageId: state.highlightedMessageId,
                          ),
                        ),

                        // Reply preview
                        if (state.replyMessage != null)
                          ReplyPreview(
                            message: state.replyMessage!,
                            onDismiss:
                                () => chatProvider.setState(
                                  (s) => s.copyWith(replyMessage: null),
                                ),
                          ),

                        // Media previews
                        if (state.selectedImages.isNotEmpty)
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: state.selectedImages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0, left: 16.0),
                                  child: ImagePreview(
                                    imagePath: state.selectedImages[index].path,
                                    mediaViewMode: state.mediaViewMode,
                                    onDismiss: () {
                                      final newList = List<XFile>.from(state.selectedImages)..removeAt(index);
                                      chatProvider.setState((s) => s.copyWith(selectedImages: newList));
                                    },
                                    onViewModeChanged: (mode) => chatProvider.setState((s) => s.copyWith(mediaViewMode: mode)),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (state.selectedVideo != null)
                          VideoPreview(
                            mediaViewMode: state.mediaViewMode,
                            onDismiss:
                                () => chatProvider.setState(
                                  (s) => s.copyWith(selectedVideo: null),
                                ),
                            onViewModeChanged:
                                (mode) => chatProvider.setState(
                                  (s) => s.copyWith(mediaViewMode: mode),
                                ),
                          ),
                        if (state.selectedAudio != null)
                          AudioPreview(
                            onDismiss:
                                () => chatProvider.setState(
                                  (s) => s.copyWith(selectedAudio: null),
                                ),
                          ),
                        if (state.selectedFile != null)
                          FilePreview(
                            file: state.selectedFile!,
                            onDismiss:
                                () => chatProvider.setState(
                                  (s) => s.copyWith(selectedFile: null),
                                ),
                          ),

                        // Smart replies
                        if (state.showingSmartReplies)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    state.smartReplies.map((reply) {
                                      final bubbleColor =
                                          state.bubbleColorSent ??
                                          theme.colorScheme.primaryContainer;
                                      
                                      // Use dynamic text color based on bubble luminance
                                      final bool isLight = bubbleColor.computeLuminance() > 0.5;
                                      final textColor =
                                          state.textColorSent ??
                                          (isLight ? Colors.black87 : theme.colorScheme.onPrimaryContainer);

                                      return GestureDetector(
                                        onTap: () {
                                          _messageController.text = reply;
                                          _chatProvider.setState(
                                            (s) => s.copyWith(
                                              smartReplies: [],
                                              showingSmartReplies: false,
                                            ),
                                          );
                                          _sendMessage();
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bubbleColor,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            reply,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: textColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),

                        // Typing indicator + Input area
                        Container(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            top: 8,
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Typing indicator
                                ChatTypingIndicator(
                                  conversationId: widget.conversationId,
                                ),

                                // Whisper mode drag gesture
                                ChatWhisperGesture(
                                  isWhisperMode: state.whisperMode,
                                  onWhisperToggle: () {
                                    _settingsProvider.toggleWhisperMode(
                                      currentWhisperMode: state.whisperMode,
                                      onModeChanged: (
                                        newMode,
                                        ephemeralDuration,
                                      ) {
                                        chatProvider.setState(
                                          (s) => s.copyWith(
                                            whisperMode: newMode,
                                            ephemeralDuration:
                                                ephemeralDuration,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  builder: (context, dragProgress, dragOffset) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Circular progress ring (visible while dragging)
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 80,
                                          ),
                                          height: dragProgress > 0 ? 52 : 0,
                                          child:
                                              dragProgress > 0
                                                  ? Material(
                                                    type: MaterialType.transparency,
                                                    child: Center(
                                                      child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          Container(
                                                            width: 40,
                                                            height: 40,
                                                            decoration:
                                                                BoxDecoration(
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                  color: colorScheme
                                                                      .secondary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                                ),
                                                          ),
                                                          SizedBox(
                                                            width: 40,
                                                            height: 40,
                                                            child: CircularProgressIndicator(
                                                              value: dragProgress,
                                                              strokeWidth: 3,
                                                              backgroundColor:
                                                                  colorScheme
                                                                      .secondary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.15,
                                                                      ),
                                                              valueColor: AlwaysStoppedAnimation<
                                                                Color
                                                              >(
                                                                dragProgress >=
                                                                        1.0
                                                                    ? colorScheme
                                                                        .secondary
                                                                    : colorScheme
                                                                        .secondary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.4 +
                                                                              dragProgress *
                                                                                  0.6,
                                                                        ),
                                                              ),
                                                            ),
                                                          ),
                                                          Icon(
                                                            dragProgress >= 1.0
                                                                ? Icons
                                                                    .auto_delete
                                                                : Icons
                                                                    .arrow_upward_rounded,
                                                            size: 18,
                                                            color: colorScheme
                                                                .secondary
                                                                .withValues(
                                                                  alpha:
                                                                      0.5 +
                                                                      dragProgress *
                                                                          0.5,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  : const SizedBox.shrink(),
                                        ),
                                        // Input row
                                        Transform.translate(
                                          offset: Offset(0, -dragOffset * 0.3),
                                          child: ChatInputArea(
                                            controller: _messageController,
                                            focusNode: _focusNode,
                                            onSend: _sendMessage,
                                            onAttachment:
                                                _showAttachmentOptions,
                                            onSticker: _showGiphyPicker,
                                            isRecording: state.isRecording,
                                            recordDuration:
                                                state.recordDuration,
                                            isSending: state.isSending,
                                            isWhisperMode: state.whisperMode,
                                            onToggleRecording: _toggleRecording,
                                            textNotifier: _textNotifier,
                                            backgroundUrl: state.backgroundUrl,
                                            textColor:
                                                state.textColorSent ??
                                                (state.backgroundUrl != null
                                                    ? Colors.white
                                                    : null),
                                            hintText:
                                                state.whisperMode > 0
                                                    ? 'Disappearing message...'
                                                    : 'Type a message...',
                                            hasAttachment: state.selectedImages.isNotEmpty || 
                                                           state.selectedVideo != null || 
                                                           state.selectedAudio != null || 
                                                           state.selectedFile != null,                                            isDesktop: isDesktop,
                                            onPickImage: _pickImage,
                                            onPickVideo: _pickVideo,
                                            onPickFile: _pickFile,
                                            onPickAudio: _pickAudio,
                                            isSpoiler: _isSpoiler,
                                            onSpoilerToggle: () => setState(() => _isSpoiler = !_isSpoiler),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Floating Header
                    ChatAppBar(
                      otherUserName:
                          widget.otherUserName ??
                          state.otherUserName ??
                          'Unknown',
                      otherUserAvatar:
                          (widget.otherUserAvatar ?? '').isNotEmpty
                              ? widget.otherUserAvatar
                              : state.otherUserAvatar,
                      otherUserId: widget.otherUserId ?? state.otherUserId,
                      isEncryptionReady: state.encryptionReady,
                      isDesktop: isDesktop,
                      isDetailsOpen: widget.isDetailsOpen,
                      onDetailsToggle: _openChatDetails,
                      // onCallPressed: () => _initiateCall(CallType.voice),
                      // onVideoCallPressed: () => _initiateCall(CallType.video),
                      backgroundUrl: state.backgroundUrl,
                    ),

                    // Vault Lock Overlay
                    if (_vaultService.isInVaultSync(widget.conversationId) &&
                        !_vaultService.isItemUnlocked(widget.conversationId))
                      Positioned.fill(
                        child: Stack(
                          children: [
                            const ModalBarrier(
                              dismissible: false,
                              color: Colors.transparent,
                            ),
                            Container(
                              color: theme.colorScheme.surface,
                              child: Stack(
                                children: [
                                  if (state.backgroundUrl != null)
                                  ChatBackground(
                                    backgroundUrl: state.backgroundUrl,
                                    bgOpacity: 0.1,
                                    bgBrightness: 0.2,
                                  ),
                                BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 30,
                                    sigmaY: 30,
                                  ),
                                  child: Container(
                                    color: colorScheme.surface.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                SafeArea(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            FluentIcons.lock_closed_48_filled,
                                            size: 64,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Chat Locked',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Authenticate to view this conversation',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 48),
                                        FilledButton.icon(
                                          onPressed:
                                              () => _vaultService.authenticate(
                                                itemId: widget.conversationId,
                                                context: context,
                                              ),
                                          icon: const Icon(
                                            FluentIcons.fingerprint_24_regular,
                                          ),
                                          label: const Text('Unlock Chat'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Go Back'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
