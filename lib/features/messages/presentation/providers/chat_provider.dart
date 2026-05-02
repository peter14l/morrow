import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:geolocator/geolocator.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/domain/models/message_reaction.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/features/messages/data/pq_aura/pq_aura_service.dart';
import 'package:oasis/services/smart_reply_service.dart';
import 'package:oasis/features/messages/presentation/providers/chat_encryption_provider.dart';
import 'package:oasis/features/messages/presentation/providers/chat_settings_provider.dart';
import 'package:oasis/features/messages/presentation/providers/chat_state.dart';
import 'package:oasis/features/messages/data/chat_media_service.dart';
import 'package:oasis/services/curation_tracking_service.dart';
import 'package:oasis/services/live_location_tracker.dart';

/// Helper class to hold encrypted content and metadata
class EncryptedContent {
  final String content;
  final String? pqAuraHeader;
  final String? pqAuraPayload;
  final String? pqAuraSenderPayload;
  final int? signalMessageType;
  final Map<String, dynamic>? encryptedKeys;
  final String? iv;
  final String protocol; // 'pq_aura', 'signal', 'rsa', 'plaintext'

  EncryptedContent({
    required this.content,
    this.pqAuraHeader,
    this.pqAuraPayload,
    this.pqAuraSenderPayload,
    this.signalMessageType,
    this.encryptedKeys,
    this.iv,
    required this.protocol,
  });
}

/// Main chat provider managing message list, sending, receiving, and UI state.
/// Fully migrated from _ChatScreenState in chat_screen.dart.
class ChatProvider with ChangeNotifier {
  final String conversationId;
  final String? otherUserId;
  final ChatEncryptionProvider encryptionProvider;
  final ChatSettingsProvider settingsProvider;
  final MessagingService _messagingService;

  ChatState _state = const ChatState();
  ChatState get state => _state;

  // Services
  final AuthService _authService = AuthService();
  final EncryptionService _encryptionService = EncryptionService();
  final ChatMediaService _chatMediaService = ChatMediaService();
  final CurationTrackingService _curationTrackingService =
      CurationTrackingService();

  // Realtime subscriptions (managed here, not in ChatState)
  RealtimeChannel? _messageChannel;
  RealtimeChannel? _readReceiptChannel;
  RealtimeChannel? _conversationChannel;
  RealtimeChannel? _reactionsChannel;
  RealtimeChannel? _backgroundChannel;
  StreamSubscription<List<Map<String, dynamic>>>? _callsSubscription;

  // Polling timer for message sync fallback (when realtime fails)
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);

  // Scroll controller reference
  final ScrollController? scrollController;

  // Session tracking
  final DateTime _sessionStartTime = DateTime.now();
  DateTime? _lastResumeTime;

  // Public key cache for encryption
  final Map<String, String> _publicKeyCache = {};

  // PQ-Aura Service instance for post-quantum encryption
  final PQAuraService _pqauraService = PQAuraService.instance;

  // Callbacks for UI actions
  VoidCallback? onReloadRequested;
  Function(String)? onError;
  Function(EncryptionStatus)? onEncryptionNeeded;

  ChatProvider({
    required this.conversationId,
    this.otherUserId,
    this.scrollController,
    ChatEncryptionProvider? encryptionProvider,
    ChatSettingsProvider? settingsProvider,
    required MessagingService messagingService,
  }) : encryptionProvider = encryptionProvider ?? ChatEncryptionProvider(),
       settingsProvider =
           settingsProvider ??
           ChatSettingsProvider(conversationId: conversationId),
       _messagingService = messagingService;

  /// Helper to update state immutably and notify listeners.
  void setState(ChatState Function(ChatState state) update) {
    _state = update(_state);
    notifyListeners();
  }

  // =========================================================================
  // Initialization
  // =========================================================================

  /// Initialize all chat subsystems. Call this from the screen's initState.
  Future<void> initialize() async {
    // Load settings and cached messages
    await settingsProvider.loadPersistedSettings(
      currentUserId: _authService.currentUser?.id,
      onSettingsLoaded: (bgUrl, bgOpacity, bgBrightness, _, __, ___, ____) {
        setState(
          (s) => s.copyWith(
            backgroundUrl: bgUrl,
            bgOpacity: bgOpacity,
            bgBrightness: bgBrightness,
          ),
        );
        if (bgUrl != null) {
          encryptionProvider.extractColorsFromBackground(bgUrl, (
            bubbleSent,
            bubbleReceived,
            textSent,
            textReceived,
          ) {
            setState(
              (s) => s.copyWith(
                bubbleColorSent: bubbleSent,
                bubbleColorReceived: bubbleReceived,
                textColorSent: textSent,
                textColorReceived: textReceived,
              ),
            );
          });
        }
      },
    );

    await settingsProvider.loadCachedMessages(
      sessionStart: _sessionStartTime,
      onMessagesLoaded: (cached) {
        setState((s) => s.copyWith(messages: cached));
        scrollToBottom(force: true);
      },
    );

    // Initialize encryption — this also loads messages once ready
    // (avoids double-loading: encryption init calls loadMessages internally)
    await _initializeEncryption();

    // Fetch conversation details
    await fetchConversationDetails();

    // Subscribe to realtime channels
    subscribeToMessages();
    subscribeToReadReceipts();
    subscribeToReactions();
    subscribeToBackgroundChanges();

    // Start polling fallback for message sync (works when realtime fails)
    _startPollingFallback();

    // Mark as read immediately — no delay needed since loadMessages
    // has already completed inside _initializeEncryption()
    markAsRead();
  }

  // =========================================================================
  // Encryption
  // =========================================================================

  Future<void> _initializeEncryption() async {
    // Always call init() to check/restore keys - don't return early if not initialized
    // This ensures _encryptionReady is properly set based on actual key status

    if (!SignalService().isInitialized) {
      final success = await SignalService().init();
      if (!success) {
        debugPrint('Failed to initialize SignalService');
      }
    }

    final status = await _encryptionService.init();
    debugPrint('[ChatProvider] Encryption status: $status');

    if (status == EncryptionStatus.ready) {
      setState((s) => s.copyWith(encryptionReady: true));
      await loadMessages(silent: true);
    } else if (status == EncryptionStatus.needsSecurityUpgrade) {
      // Can still decrypt with v1 keys
      setState((s) => s.copyWith(encryptionReady: true));
      await loadMessages(silent: true);
      onEncryptionNeeded?.call(status);
    } else {
      // Encryption needs setup or restore — do NOT load messages yet
      // to ensure security and force the user to enter their PIN first.
      setState((s) => s.copyWith(encryptionReady: false, isLoading: false));
      onEncryptionNeeded?.call(status);
    }
  }

  Future<Message> _decryptSingleMessage(Message message) async {
    return encryptionProvider.decryptSingleMessage(
      message,
      _authService.currentUser?.id,
    );
  }

  /// Encrypts content for a recipient using PQ-Aura -> Signal -> RSA fallback.
  /// Returns encrypted content and metadata based on which protocol was used.
  Future<EncryptedContent?> _encryptContent(
    String recipientId,
    String content,
  ) async {
    // Try PQ-Aura first (post-quantum encryption)
    try {
      final pqaEncrypted = await _pqauraService.encryptMessage(recipientId, content);
      if (pqaEncrypted != null) {
        debugPrint('[ChatProvider] Used PQ-Aura encryption for $recipientId');
        return EncryptedContent(
          content: base64Encode(pqaEncrypted.payload),
          pqAuraHeader: base64Encode(pqaEncrypted.header),
          pqAuraPayload: base64Encode(pqaEncrypted.payload),
          protocol: 'pq_aura',
        );
      }
    } catch (e) {
      debugPrint('[ChatProvider] PQ-Aura encryption failed: $e');
    }

    // Fall back to Signal (classical E2EE)
    if (SignalService().isInitialized) {
      try {
        final cipherMessage = await SignalService().encryptMessage(
          recipientId,
          content,
        );
        debugPrint('[ChatProvider] Used Signal encryption for $recipientId');
        return EncryptedContent(
          content: base64Encode(cipherMessage.serialize()),
          signalMessageType: cipherMessage.getType(),
          protocol: 'signal',
        );
      } catch (e) {
        debugPrint('[ChatProvider] Signal encryption failed: $e');
      }
    }

    // Fall back to RSA encryption (legacy)
    String? recipientPublicKey = _publicKeyCache[recipientId];
    if (recipientPublicKey != null) {
      try {
        final encrypted = await _encryptionService.encryptMessage(
          content,
          [recipientPublicKey],
        );
        debugPrint('[ChatProvider] Used RSA encryption for $recipientId');
        return EncryptedContent(
          content: encrypted.encryptedContent,
          encryptedKeys: encrypted.encryptedKeys,
          iv: encrypted.iv,
          protocol: 'rsa',
        );
      } catch (e) {
        debugPrint('[ChatProvider] RSA encryption failed: $e');
      }
    }

    // No encryption available - send as plaintext (shouldn't happen in production)
    debugPrint('[ChatProvider] No encryption available, sending plaintext');
    return EncryptedContent(
      content: content,
      protocol: 'plaintext',
    );
  }

  // =========================================================================
  // Messages
  // =========================================================================

  /// Load messages from the server and decrypt them.
  Future<void> loadMessages({bool silent = false, int retryCount = 0}) async {
    if (!silent && state.messages.isEmpty) {
      setState((s) => s.copyWith(isLoading: true));
    }

    try {
      final messages = await _messagingService.getMessages(
        conversationId: conversationId,
        sessionStart: _sessionStartTime,
      );

      // Decrypt messages progressively to prevent UI thread blocking
      final List<Message> decryptedMessages = [];
      for (int i = 0; i < messages.length; i++) {
        decryptedMessages.add(await _decryptSingleMessage(messages[i]));
        // Yield to the event loop every 5 messages to keep UI smooth
        if (i % 5 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // Filter expired ephemeral messages
      final now = DateTime.now();
      final filtered = decryptedMessages.where((m) {
        if (!m.isEphemeral) return true;
        if (m.ephemeralDuration == 0 && m.readAt != null) return false;
        if (m.expiresAt != null && now.isAfter(m.expiresAt!)) return false;
        return true;
      }).toList();

      setState((s) => s.copyWith(messages: filtered, isLoading: false));
      scrollToBottom(force: true);
      loadSmartReplies();
      await settingsProvider.saveMessagesToCache(filtered);
    } catch (e) {
      debugPrint('Error loading messages (attempt ${retryCount + 1}): $e');
      
      // Handle network errors with retries
      if (retryCount < 3 && (e.toString().contains('SocketException') || e.toString().contains('ClientException'))) {
        await Future.delayed(Duration(seconds: 1 * (retryCount + 1)));
        return loadMessages(silent: silent, retryCount: retryCount + 1);
      }

      setState((s) => s.copyWith(isLoading: false));
      // Only show error if it's the final attempt and not a silent reload
      if (!silent) {
        onError?.call('Error loading messages: $e');
      }
    }
  }

  /// Subscribe to new messages and deletions via Supabase Realtime.
  void subscribeToMessages() {
    _messageChannel = _messagingService.subscribeToMessages(
      conversationId: conversationId,
      onNewMessage: (message) async {
        final currentUserId = _authService.currentUser?.id;

        final decryptedMessage = await _decryptSingleMessage(message);

        // Apply client-side filtering for whisper mode
        final now = DateTime.now();
        final isExpired =
            decryptedMessage.isEphemeral &&
            ((decryptedMessage.ephemeralDuration == 0 &&
                    decryptedMessage.readAt != null) ||
                (decryptedMessage.expiresAt != null &&
                    now.isAfter(decryptedMessage.expiresAt!)));
        if (isExpired) return;

        // Avoid duplicates (especially from optimistic updates)
        final index = state.messages.indexWhere(
          (m) => m.id == decryptedMessage.id,
        );

        // Also check if there's an optimistic message with the same content/type
        // that this message might be replacing (though ID matching is preferred)
        int optimisticIndex = -1;
        if (index == -1 && decryptedMessage.senderId == currentUserId) {
          optimisticIndex = state.messages.indexWhere(
            (m) => m.id.startsWith('optimistic_') && 
                   m.messageType == decryptedMessage.messageType &&
                   (m.content == decryptedMessage.content || m.mediaFileName == decryptedMessage.mediaFileName)
          );
        }

        List<Message> updatedMessages;
        if (index != -1) {
          updatedMessages = List<Message>.from(state.messages);
          updatedMessages[index] = decryptedMessage;
        } else if (optimisticIndex != -1) {
          updatedMessages = List<Message>.from(state.messages);
          updatedMessages[optimisticIndex] = decryptedMessage;
        } else {
          updatedMessages = [...state.messages, decryptedMessage];
        }

        setState((s) => s.copyWith(messages: updatedMessages));
        scrollToBottom();
        loadSmartReplies();
        settingsProvider.saveMessagesToCache(updatedMessages);

        // Mark as read if message is from other user
        if (decryptedMessage.senderId != currentUserId) {
          markAsRead();
          
          // Auto-download media in background
          if (decryptedMessage.mediaUrl != null && 
              decryptedMessage.encryptedKeys != null && 
              decryptedMessage.iv != null &&
              decryptedMessage.messageType != MessageType.text &&
              decryptedMessage.messageType != MessageType.system &&
              decryptedMessage.messageType != MessageType.location) {
            
            String mediaType = 'images';
            if (decryptedMessage.messageType == MessageType.document) {
               if (decryptedMessage.mediaUrl!.contains('videos')) {
                 mediaType = 'videos';
               } else {
                 mediaType = 'documents';
               }
            } else if (decryptedMessage.messageType == MessageType.voice) {
               mediaType = 'recordings';
            }

            // Fire and forget download
            _chatMediaService.downloadAndDecryptMedia(
              remoteUrl: decryptedMessage.mediaUrl!,
              type: mediaType,
              fileId: decryptedMessage.id,
              iv: decryptedMessage.iv!,
              encryptedKeys: decryptedMessage.encryptedKeys!,
            ).then((localPath) {
               // Update state to trigger UI refresh (shows the image instead of download button)
               final updatedIndex = state.messages.indexWhere((m) => m.id == decryptedMessage.id);
               if (updatedIndex != -1) {
                  // We just need to force a rebuild, the bubbles check cache in initState
                  setState((s) => s); 
               }
            }).catchError((e) {
               debugPrint('[AutoDownload] Failed for message ${decryptedMessage.id}: $e');
            });
          }
        }
      },
      onDeleteMessage: (messageId) {
        setState(
          (s) => s.copyWith(
            messages: s.messages.where((m) => m.id != messageId).toList(),
          ),
        );
        settingsProvider.saveMessagesToCache(state.messages);
      },
    );
  }

  /// Subscribe to read receipt updates via Supabase Realtime.
  void subscribeToReadReceipts() {
    _readReceiptChannel = _messagingService.subscribeToReadReceipts(
      conversationId: conversationId,
      onUpdate: (messageId, userId, readAt) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final index = state.messages.indexWhere((m) => m.id == messageId);
          if (index < 0) return;

          final msg = state.messages[index];
          final senderId = msg.senderId;
          final isMe = _authService.currentUser?.id == senderId;

          // Only consider it "read" for vanish logic if the person reading is NOT the sender
          if (userId != senderId) {
            DateTime? currentAnyReadAt = msg.anyReadAt;
            if (currentAnyReadAt == null || readAt.isBefore(currentAnyReadAt)) {
              currentAnyReadAt = readAt;
            }

            final updatedMsg = msg.copyWith(
              anyReadAt: currentAnyReadAt,
              isRead: isMe ? true : msg.isRead,
            );

            // Instant vanish: if Whisper Mode and receiver read it, remove immediately
            if (updatedMsg.isEphemeral && updatedMsg.ephemeralDuration == 0) {
              setState(
                (s) => s.copyWith(
                  messages: List<Message>.from(s.messages)..removeAt(index),
                ),
              );
              return;
            }

            final updatedMessages = List<Message>.from(state.messages);
            updatedMessages[index] = updatedMsg;
            setState((s) => s.copyWith(messages: updatedMessages));
          }
        });
      },
    );
  }

  /// Subscribe to reaction updates.
  void subscribeToReactions() {
    _reactionsChannel = _messagingService.subscribeToReactions(
      conversationId: conversationId,
      onUpdate: (messageId, reactions) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final index = state.messages.indexWhere((m) => m.id == messageId);
          if (index < 0) return;

          final updatedMessages = List<Message>.from(state.messages);
          updatedMessages[index] = updatedMessages[index].copyWith(
            reactions: reactions,
          );
          setState((s) => s.copyWith(messages: updatedMessages));
        });
      },
    );
  }

  /// Subscribe to background image changes.
  void subscribeToBackgroundChanges() {
    _backgroundChannel = _messagingService.subscribeToBackgroundChanges(
      conversationId: conversationId,
      onUpdate: (backgroundUrl) {
        if (backgroundUrl != state.backgroundUrl) {
          setState((s) => s.copyWith(backgroundUrl: backgroundUrl));
          if (backgroundUrl != null) {
            encryptionProvider.extractColorsFromBackground(backgroundUrl, (
              bubbleSent,
              bubbleReceived,
              textSent,
              textReceived,
            ) {
              setState(
                (s) => s.copyWith(
                  bubbleColorSent: bubbleSent,
                  bubbleColorReceived: bubbleReceived,
                  textColorSent: textSent,
                  textColorReceived: textReceived,
                ),
              );
            });
          } else {
            setState(
              (s) => s.copyWith(
                bubbleColorSent: null,
                bubbleColorReceived: null,
                textColorSent: null,
                textColorReceived: null,
              ),
            );
          }
        }
      },
    );
  }

  /// Mark unread messages as read.
  Future<void> markAsRead() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return;

    final unreadMessageIds = state.messages
        .where((m) => m.senderId != currentUserId && !m.isRead)
        .map((m) => m.id)
        .toList();

    if (unreadMessageIds.isEmpty) return;

    // Optimistically update
    final updatedMessages = state.messages.map((m) {
      if (unreadMessageIds.contains(m.id)) {
        return m.copyWith(isRead: true, readAt: DateTime.now());
      }
      return m;
    }).toList();

    setState((s) => s.copyWith(messages: updatedMessages));

    for (final id in unreadMessageIds) {
      final msg = state.messages.firstWhere((m) => m.id == id);
      try {
        await _messagingService.markAsRead(
          messageId: id,
          userId: currentUserId,
          isWhisper: msg.isEphemeral || msg.whisperMode != 'OFF',
        );
      } catch (e) {
        debugPrint('Error marking message $id as read: $e');
      }
    }
  }

  // =========================================================================
  // Sending Messages
  // =========================================================================

  /// Send a text or media message.
  Future<void> sendMessage({
    required String content,
    XFile? imageFile,
    File? videoFile,
    File? audioFile,
    PlatformFile? docFile,
    Message? replyMessage,
    String mediaViewMode = 'unlimited',
    bool isSpoiler = false,
  }) async {
    if (content.isEmpty &&
        imageFile == null &&
        videoFile == null &&
        audioFile == null &&
        docFile == null) {
      return;
    }

    if (_encryptionService.isInitialized && !state.encryptionReady) {
      onError?.call('Encryption not ready. Please set up encryption first.');
      return;
    }

    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    // Determine message type and media info for optimistic message
    MessageType messageType = MessageType.text;
    String? mediaUrl;
    String? fileName;
    int? fileSize;

    if (imageFile != null) {
      messageType = MessageType.image;
      mediaUrl = imageFile.path;
      fileName = imageFile.name;
    } else if (videoFile != null) {
      messageType = MessageType.document; // Videos are sent as document type in this app
      mediaUrl = videoFile.path;
      fileName = videoFile.path.split(Platform.pathSeparator).last;
    } else if (audioFile != null) {
      messageType = MessageType.voice;
      mediaUrl = audioFile.path;
      fileName = audioFile.path.split(Platform.pathSeparator).last;
    } else if (docFile != null) {
      messageType = MessageType.document;
      mediaUrl = docFile.path;
      fileName = docFile.name;
      fileSize = docFile.size;
    }

    // Create and add optimistic message
    final optimisticMessage = Message(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: userId,
      senderName: _authService.currentUser?.username ?? 'Me',
      senderAvatar: _authService.currentUser?.photoUrl ?? '',
      content: content,
      timestamp: DateTime.now(),
      isRead: false,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaFileName: fileName,
      mediaFileSize: fileSize,
      isEphemeral: state.whisperMode > 0,
      isSpoiler: isSpoiler,
      ephemeralDuration: state.ephemeralDuration,
      replyToId: replyMessage?.id,
      replyToContent: replyMessage?.content,
      replyToSenderName: replyMessage?.senderName,
      mediaViewMode: mediaViewMode,
      isUploading: imageFile != null || videoFile != null || audioFile != null || docFile != null,
      uploadProgress: 0.0,
    );

    setState(
      (s) => s.copyWith(
        messages: [...s.messages, optimisticMessage],
        isSending: false, 
        replyMessage: null,
        selectedImages: const <XFile>[],
        selectedVideo: null,
        selectedAudio: null,
        selectedFile: null,
      ),
    );
    scrollToBottom(force: true);

    try {
      String? finalContent;
      Map<String, String>? encryptedKeys;
      String? iv;
      int? signalMessageType;
      String? signalSenderContent;
      String? pqAuraHeader;
      String? pqAuraPayload;

      // Prepare recipient keys for media E2EE
      final recipientId = otherUserId ?? state.otherUserId;
      if (recipientId == null) throw Exception('Recipient ID is required');
      
      String? recipientPublicKey = _publicKeyCache[recipientId];
      if (recipientPublicKey == null) {
        recipientPublicKey = await _authService.getPublicKey(recipientId);
        if (recipientPublicKey != null) {
          _publicKeyCache[recipientId] = recipientPublicKey;
        }
      }
      
      final senderPublicKey = await _authService.getPublicKey(userId);
      final List<String> mediaRecipientPublicKeys = [];
      if (recipientPublicKey != null) mediaRecipientPublicKeys.add(recipientPublicKey);
      if (senderPublicKey != null) mediaRecipientPublicKeys.add(senderPublicKey);

      // Use PQ-Aura -> Signal -> RSA fallback encryption
      if (_encryptionService.isInitialized && content.isNotEmpty) {
        final encrypted = await _encryptContent(recipientId, content);
        if (encrypted != null) {
          finalContent = encrypted.content;
          
          // Extract encryption metadata based on protocol used
          if (encrypted.protocol == 'pq_aura') {
            pqAuraHeader = encrypted.pqAuraHeader;
            pqAuraPayload = encrypted.pqAuraPayload;
          } else if (encrypted.protocol == 'signal') {
            signalMessageType = encrypted.signalMessageType;
          } else if (encrypted.protocol == 'rsa') {
            encryptedKeys = encrypted.encryptedKeys?.map((k, v) => MapEntry(k, v.toString()));
            iv = encrypted.iv;
          }
        }
      } else {
        finalContent = content;
      }

      // Upload media securely if present
      String? remoteMediaUrl;
      String? finalMimeType;
      MediaUploadResult? uploadResult;

      final onProgress = (double progress) {
        _updateMessageProgress(optimisticMessage.id, progress);
      };

      if (imageFile != null) {
        uploadResult = await _chatMediaService.uploadChatMediaSecure(
          imageFile.path,
          type: 'images',
          recipientPublicKeysPem: mediaRecipientPublicKeys,
          recipientUserId: recipientId,
          onProgress: onProgress,
        );
      } else if (videoFile != null) {
        uploadResult = await _chatMediaService.uploadChatMediaSecure(
          videoFile.path,
          type: 'videos',
          recipientPublicKeysPem: mediaRecipientPublicKeys,
          recipientUserId: recipientId,
          onProgress: onProgress,
        );
      } else if (docFile != null) {
        if (docFile.path != null) {
          uploadResult = await _chatMediaService.uploadChatMediaSecure(
            docFile.path!,
            type: 'documents',
            recipientPublicKeysPem: mediaRecipientPublicKeys,
            recipientUserId: recipientId,
            onProgress: onProgress,
          );
          finalMimeType = docFile.extension;
        }
      } else if (audioFile != null) {
        uploadResult = await _chatMediaService.uploadChatMediaSecure(
          audioFile.path,
          type: 'recordings',
          recipientPublicKeysPem: mediaRecipientPublicKeys,
          recipientUserId: recipientId,
          onProgress: onProgress,
        );
      }

      if (uploadResult != null) {
        remoteMediaUrl = uploadResult.remoteUrl;
      }

      // Generate dual-layer fallback (RSA encrypted copy for both sender and recipient)
      // Only needed if Signal or PQ-Aura was used, otherwise content is already RSA encrypted.
      final encryptedFallback = await _encryptContent(recipientId, content);
      if (encryptedFallback != null && encryptedFallback.protocol != 'rsa' && _encryptionService.isInitialized && content.isNotEmpty) {
        try {
          final List<String> publicKeys = [];
          if (recipientPublicKey != null) publicKeys.add(recipientPublicKey);
          if (senderPublicKey != null) publicKeys.add(senderPublicKey);

          if (publicKeys.isNotEmpty) {
            final fallbackEncryption = await _encryptionService.encryptMessage(
              content.isNotEmpty ? content : '',
              publicKeys,
            );
            signalSenderContent = fallbackEncryption.encryptedContent;
            encryptedKeys = fallbackEncryption.encryptedKeys;
            iv = fallbackEncryption.iv;
          }
        } catch (e) {
          debugPrint('Failed to generate dual-layer fallback: $e');
        }
      }

      // Send message
      final sentMessage = await _messagingService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        content: finalContent ?? '',
        messageType: messageType,
        mediaUrl: remoteMediaUrl,
        mediaFileName: fileName,
        mediaFileSize: fileSize,
        mediaMimeType: finalMimeType,
        encryptedKeys: uploadResult != null ? uploadResult.encryptedKeys : encryptedKeys,
        iv: uploadResult != null ? uploadResult.iv : iv,
        signalMessageType: signalMessageType,
        signalSenderContent: signalSenderContent,
        whisperMode: state.whisperMode,
        isSpoiler: isSpoiler,
        replyToId: replyMessage?.id,
        mediaViewMode: mediaViewMode,
        pqAuraHeader: pqAuraHeader,
        pqAuraPayload: pqAuraPayload,
      );

      // Replace optimistic message with the real one
      var decrypted = await _decryptSingleMessage(sentMessage);
      
      if (decrypted.replyToId != null && decrypted.replyToContent == null) {
        decrypted = decrypted.copyWith(
          replyToContent: optimisticMessage.replyToContent,
          replyToSenderName: optimisticMessage.replyToSenderName,
        );
      }
      if (decrypted.content == '🔒 Message encrypted' || decrypted.content.contains('🔒')) {
        decrypted = decrypted.copyWith(content: optimisticMessage.content);
      }
      if (optimisticMessage.mediaUrl != null && !optimisticMessage.mediaUrl!.startsWith('http')) {
        decrypted = decrypted.copyWith(mediaUrl: optimisticMessage.mediaUrl);
      }

      setState(
        (s) => s.copyWith(
          messages: [
            ...s.messages.where((m) => m.id != optimisticMessage.id && m.id != decrypted.id),
            decrypted,
          ],
        ),
      );

      await settingsProvider.saveMessagesToCache(state.messages);
    } catch (e) {
      debugPrint('Error sending message: $e');
      // Remove optimistic message on failure
      setState(
        (s) => s.copyWith(
          messages: s.messages
              .where((m) => m.id != optimisticMessage.id)
              .toList(),
        ),
      );
      onError?.call('Failed to send message: $e');
    }
  }

  void _updateMessageProgress(String messageId, double progress) {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final updatedMessages = List<Message>.from(state.messages);
      updatedMessages[index] = updatedMessages[index].copyWith(
        uploadProgress: progress,
        isUploading: progress < 1.0,
      );
      setState((s) => s.copyWith(messages: updatedMessages));
    }
  }

  /// Delete a sent message (unsend).
  Future<void> unsendMessage(Message message) async {
    // Optimistically remove
    setState(
      (s) => s.copyWith(
        messages: s.messages.where((m) => m.id != message.id).toList(),
      ),
    );

    try {
      await _messagingService.deleteMessage(message.id);
    } catch (e) {
      debugPrint('Error unsending message: $e');
      onError?.call('Failed to unsend message');
      // Reload on failure
      onReloadRequested?.call();
    }
  }

  /// Send a GIF message.
  Future<void> sendGif(String gifUrl, {Message? replyMessage}) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    setState((s) => s.copyWith(isSending: true, replyMessage: null));

    try {
      String content = '[GIF]';
      final recipientId = otherUserId ?? state.otherUserId;

      EncryptedContent? encrypted;
      if (_encryptionService.isInitialized && recipientId != null) {
        encrypted = await _encryptContent(recipientId, content);
      }

      final sentMessage = await _messagingService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        content: encrypted?.content ?? content,
        messageType: MessageType.gif,
        mediaUrl: gifUrl,
        whisperMode: state.whisperMode,
        replyToId: replyMessage?.id,
        encryptedKeys: encrypted?.encryptedKeys != null 
            ? encrypted!.encryptedKeys!.map((k, v) => MapEntry(k, v.toString()))
            : null,
        iv: encrypted?.iv,
        signalMessageType: encrypted?.signalMessageType,
        pqAuraHeader: encrypted?.pqAuraHeader,
        pqAuraPayload: encrypted?.pqAuraPayload,
      );

      final decrypted = await _decryptSingleMessage(sentMessage);
      setState(
        (s) =>
            s.copyWith(messages: [...s.messages, decrypted], isSending: false),
      );
      scrollToBottom();
      await settingsProvider.saveMessagesToCache(state.messages);
    } catch (e) {
      debugPrint('Error sending GIF: $e');
      setState((s) => s.copyWith(isSending: false));
      onError?.call('Failed to send GIF: $e');
    }
  }

  /// Send a sticker message.
  Future<void> sendSticker(String stickerUrl, {Message? replyMessage}) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    setState((s) => s.copyWith(isSending: true, replyMessage: null));

    try {
      String content = '[STICKER]';
      final recipientId = otherUserId ?? state.otherUserId;

      EncryptedContent? encrypted;
      if (_encryptionService.isInitialized && recipientId != null) {
        encrypted = await _encryptContent(recipientId, content);
      }

      final sentMessage = await _messagingService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        content: encrypted?.content ?? content,
        messageType: MessageType.sticker,
        mediaUrl: stickerUrl,
        whisperMode: state.whisperMode,
        replyToId: replyMessage?.id,
        encryptedKeys: encrypted?.encryptedKeys != null 
            ? encrypted!.encryptedKeys!.map((k, v) => MapEntry(k, v.toString()))
            : null,
        iv: encrypted?.iv,
        signalMessageType: encrypted?.signalMessageType,
        pqAuraHeader: encrypted?.pqAuraHeader,
        pqAuraPayload: encrypted?.pqAuraPayload,
      );

      final decrypted = await _decryptSingleMessage(sentMessage);
      setState(
        (s) =>
            s.copyWith(messages: [...s.messages, decrypted], isSending: false),
      );
      scrollToBottom();
      await settingsProvider.saveMessagesToCache(state.messages);
    } catch (e) {
      debugPrint('Error sending sticker: $e');
      setState((s) => s.copyWith(isSending: false));
      onError?.call('Failed to send sticker: $e');
    }
  }

  /// Update reactions on a specific message (optimistic UI update).
  void updateMessageReactions(
    String messageId,
    List<MessageReactionModel> reactions,
  ) {
    setState(
      (s) => s.copyWith(
        messages: s.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(reactions: reactions);
          }
          return m;
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // Conversation Details
  // =========================================================================

  /// Fetch conversation details (other user info, whisper mode).
  Future<void> fetchConversationDetails() async {
    try {
      final details = await _messagingService.getConversationDetails(
        conversationId,
      );
      setState(
        (s) => s.copyWith(
          otherUserName: details.otherUserName,
          otherUserId: details.otherUserId,
          otherUserAvatar: details.otherUserAvatar,
          whisperMode: 0, // Forced to 0 to disable Whisper Mode
          ephemeralDuration: details.whisperMode == 1 ? 0 : 86400,
        ),
      );
    } catch (e) {
      debugPrint('Error fetching conversation details: $e');
    }
  }

  // =========================================================================
  // Smart Replies
  // =========================================================================

  /// Load smart reply suggestions for the last received message.
  void loadSmartReplies() {
    final messages = state.messages;
    if (messages.isEmpty) {
      setState((s) => s.copyWith(smartReplies: [], showingSmartReplies: false));
      return;
    }

    // Find last message from other user
    final currentUserId = _authService.currentUser?.id;
    Message? lastOtherMessage;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderId != currentUserId &&
          messages[i].messageType == MessageType.text) {
        lastOtherMessage = messages[i];
        break;
      }
    }

    if (lastOtherMessage == null ||
        lastOtherMessage.content == 'Sent attachment' ||
        lastOtherMessage.content.contains('🔒')) {
      setState((s) => s.copyWith(smartReplies: [], showingSmartReplies: false));
      return;
    }

    // Get suggestions (SmartReplyService is static)
    final suggestions = SmartReplyService.getSuggestions(
      lastOtherMessage.content,
    );
    setState(
      (s) => s.copyWith(
        smartReplies: suggestions,
        showingSmartReplies: suggestions.isNotEmpty,
      ),
    );
  }

  // =========================================================================
  // Scroll
  // =========================================================================

  /// Scroll the message list to the bottom (latest messages).
  void scrollToBottom({bool force = false}) {
    if (scrollController != null && scrollController!.hasClients) {
      final position = scrollController!.position;
      final isNearBottom = position.pixels <= 100;

      if (force || isNearBottom) {
        scrollController!.animateTo(
          0.0, // reverse list: 0 is bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Scroll to a specific message and highlight it briefly.
  void scrollToMessage(String messageId) {
    final index = _state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    // ListView is reversed, so index 0 is at the bottom (latest message).
    // The message at messages[index] corresponds to ListView index:
    // listIndex = messages.length - 1 - index
    final listIndex = _state.messages.length - 1 - index;

    if (scrollController != null && scrollController!.hasClients) {
      // Basic approximation of item height. Since messages vary, this is a best-effort scroll.
      // For more precision, ScrollablePositionedList would be needed.
      double offset = listIndex * 120.0;

      if (offset > scrollController!.position.maxScrollExtent) {
        offset = scrollController!.position.maxScrollExtent;
      }

      scrollController!.animateTo(
        offset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );

      // Highlight the message
      setState((s) => s.copyWith(highlightedMessageId: messageId));

      // Remove highlight after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (_state.highlightedMessageId == messageId) {
          setState((s) => s.copyWith(highlightedMessageId: null));
        }
      });
    }
  }

  // =========================================================================
  // Lifecycle
  // =========================================================================

  /// Called when the app comes back to foreground.
  Future<void> onAppResumed() async {
    final now = DateTime.now();
    if (_lastResumeTime != null &&
        now.difference(_lastResumeTime!).inSeconds < 5) {
      return; // rapid switching, skip reload
    }
    _lastResumeTime = now;

    // Small delay to let the OS re-establish network connectivity
    await Future.delayed(const Duration(seconds: 1));

    // Reload messages silently, reconnect realtime
    await loadMessages(silent: true);
    _reconnectRealtime();
    await fetchConversationDetails();
  }

  void _reconnectRealtime() {
    if (_messageChannel != null) {
      _messagingService.unsubscribeFromMessages(_messageChannel!);
    }
    subscribeToMessages();

    if (_readReceiptChannel != null) {
      SupabaseService().client.removeChannel(_readReceiptChannel!);
    }
    subscribeToReadReceipts();

    if (_reactionsChannel != null) {
      SupabaseService().client.removeChannel(_reactionsChannel!);
    }
    subscribeToReactions();
  }

  /// Start polling fallback to ensure messages sync even if realtime fails.
  void _startPollingFallback() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _loadMessagesPolled();
    });
  }

  /// Polling callback - just loads messages without full re-init.
  Future<void> _loadMessagesPolled() async {
    if (_state.isLoading) return; // Skip if already loading

    // Skip rapid calls (within 3 seconds of last load)
    final now = DateTime.now();
    if (_lastResumeTime != null &&
        now.difference(_lastResumeTime!).inSeconds < 3) {
      return;
    }

    // Do a lightweight sync - just fetch latest messages
    try {
      await loadMessages(silent: true);
    } catch (e) {
      debugPrint('[ChatProvider] Polling sync error: $e');
    }
  }

  /// Insert a system message (e.g., "Encryption enabled").
  void insertSystemMessage(String content) {
    setState(
      (s) => s.copyWith(
        messages: [
          ...s.messages,
          Message(
            id: 'system_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: conversationId,
            senderId: 'system',
            senderName: 'System',
            senderAvatar: '',
            content: content,
            timestamp: DateTime.now(),
            messageType: MessageType.system,
            isRead: true,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Stop polling fallback
    _pollingTimer?.cancel();
    _pollingTimer = null;

    // Clean up Realtime subscriptions
    if (_messageChannel != null) {
      _messagingService.unsubscribeFromMessages(_messageChannel!);
    }
    if (_backgroundChannel != null) {
      SupabaseService().client.removeChannel(_backgroundChannel!);
    }
    if (_readReceiptChannel != null) {
      SupabaseService().client.removeChannel(_readReceiptChannel!);
    }
    if (_conversationChannel != null) {
      SupabaseService().client.removeChannel(_conversationChannel!);
    }
    if (_reactionsChannel != null) {
      SupabaseService().client.removeChannel(_reactionsChannel!);
    }
    _callsSubscription?.cancel();
    _publicKeyCache.clear();

    // Track time spent in chat for curation
    _trackChatTimeSpent();

    super.dispose();
  }

  /// Track time spent in this conversation for curation.
  Future<void> _trackChatTimeSpent() async {
    final duration = DateTime.now().difference(_sessionStartTime).inSeconds;
    if (duration < 5) return; // Ignore sessions less than 5 seconds

    // Use conversation name or default to 'direct_messages'
    final category = state.otherUserName?.toLowerCase() ?? 'direct_messages';
    try {
      await _curationTrackingService.trackTimeSpent(category, duration);
    } catch (e) {
      debugPrint('[ChatProvider] Time tracking error: $e');
    }
  }

  void incrementLocalMediaViewCount(String messageId) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final msg = state.messages[idx];
      final newCount = msg.currentUserViewCount + 1;
      final newMsgs = List<Message>.from(state.messages);
      newMsgs[idx] = msg.copyWith(currentUserViewCount: newCount);
      setState((s) => s.copyWith(messages: newMsgs));
    }
  }

  Future<void> shareLiveLocation(Duration duration) async {
    try {
      setState((s) => s.copyWith(isSending: true, replyMessage: null));

      // Get initial location before sending the message
      double? latitude;
      double? longitude;

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        debugPrint('Failed to get initial location: $e');
        // Continue without initial location - tracker will update later
      }

      // Build initial location data
      Map<String, dynamic>? locationData;
      if (latitude != null && longitude != null) {
        locationData = {
          'latitude': latitude,
          'longitude': longitude,
          'is_live': true,
          'started_at': DateTime.now().toIso8601String(),
          'expires_at': DateTime.now().add(duration).toIso8601String(),
        };
      }

      final sentMessage = await _messagingService.sendMessage(
        conversationId: conversationId,
        senderId: _authService.currentUser!.id,
        content: 'Live Location Shared',
        messageType: MessageType.location,
        mediaViewMode: 'live_location',
        locationData: locationData,
        replyToId: state.replyMessage?.id,
      );

      // Start the tracker
      await LiveLocationTracker().startSharing(sentMessage.id, duration);

      final decrypted = await _decryptSingleMessage(sentMessage);
      setState(
        (s) =>
            s.copyWith(messages: [...s.messages, decrypted], isSending: false),
      );
      scrollToBottom();
      await settingsProvider.saveMessagesToCache(state.messages);
    } catch (e) {
      debugPrint('Error starting live location: $e');
      setState((s) => s.copyWith(isSending: false));
      onError?.call('Failed to share live location: $e');
    }
  }

  Future<void> sendAudioMessage({
    required String audioPath,
    required int duration,
  }) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    // Create and add optimistic message
    final optimisticMessage = Message(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: userId,
      senderName: _authService.currentUser?.username ?? 'Me',
      senderAvatar: _authService.currentUser?.photoUrl ?? '',
      content: 'Audio message',
      timestamp: DateTime.now(),
      isRead: false,
      messageType: MessageType.voice,
      mediaUrl: audioPath,
      mediaFileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      voiceDuration: duration,
      isEphemeral: state.whisperMode > 0,
      ephemeralDuration: state.ephemeralDuration,
      replyToId: state.replyMessage?.id,
      isUploading: true,
      uploadProgress: 0.0,
    );

    setState(
      (s) => s.copyWith(
        messages: [...s.messages, optimisticMessage],
        isSending: false,
        replyMessage: null,
      ),
    );
    scrollToBottom(force: true);

    try {
      final recipientId = otherUserId ?? state.otherUserId;
      if (recipientId == null) throw Exception('Recipient ID is required');

      final recipientPublicKey = await _authService.getPublicKey(recipientId);
      final senderPublicKey = await _authService.getPublicKey(userId);
      final List<String> mediaRecipientPublicKeys = [];
      if (recipientPublicKey != null) mediaRecipientPublicKeys.add(recipientPublicKey);
      if (senderPublicKey != null) mediaRecipientPublicKeys.add(senderPublicKey);

      final uploadResult = await _chatMediaService.uploadChatMediaSecure(
        audioPath,
        type: 'recordings',
        recipientPublicKeysPem: mediaRecipientPublicKeys,
        recipientUserId: recipientId,
        onProgress: (progress) {
          _updateMessageProgress(optimisticMessage.id, progress);
        },
      );

      final sentMessage = await _messagingService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        content: 'Audio message',
        messageType: MessageType.voice,
        mediaUrl: uploadResult.remoteUrl,
        mediaFileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        voiceDuration: duration,
        replyToId: state.replyMessage?.id,
        whisperMode: state.whisperMode,
        shareData: {
          'media_iv': uploadResult.iv,
          'media_keys': uploadResult.encryptedKeys,
        },
      );

      final decrypted = await _decryptSingleMessage(sentMessage);
      setState(
        (s) => s.copyWith(
          messages: [
            ...s.messages.where((m) => m.id != optimisticMessage.id),
            decrypted,
          ],
        ),
      );
      await settingsProvider.saveMessagesToCache(state.messages);
    } catch (e) {
      debugPrint('Error sending audio message: $e');
      setState(
        (s) => s.copyWith(
          messages: s.messages.where((m) => m.id != optimisticMessage.id).toList(),
        ),
      );
      onError?.call('Failed to send audio message: $e');
    }
  }

  Future<void> stopLiveLocation() async {
    try {
      final activeMsgId = LiveLocationTracker().activeMessageId;
      await LiveLocationTracker().stopSharing();

      // Optimistically update the UI to show sharing has stopped
      if (activeMsgId != null) {
        final index = state.messages.indexWhere((m) => m.id == activeMsgId);
        if (index != -1) {
          final msg = state.messages[index];
          final currentLocData = msg.locationData != null
              ? Map<String, dynamic>.from(msg.locationData!)
              : <String, dynamic>{};
          currentLocData['is_live'] = false;

          final updatedMsg = msg.copyWith(locationData: currentLocData);
          final newMsgs = List<Message>.from(state.messages);
          newMsgs[index] = updatedMsg;

          setState((s) => s.copyWith(messages: newMsgs));
        }
      }
    } catch (e) {
      debugPrint('Failed to stop live location: $e');
    }
  }
}
