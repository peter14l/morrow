import 'dart:async';
import 'package:oasis/widgets/custom_snackbar.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:provider/provider.dart';

import 'package:oasis/core/config/feature_flags.dart';

class SharingService {
  static final SharingService _instance = SharingService._internal();
  factory SharingService() => _instance;
  SharingService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  final AuthService _authService = AuthService();

  // Queue for pending shared files when navigator is not ready
  List<SharedMediaFile>? _pendingFiles;
  bool _isShowingModal = false;
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 10;

  void init(BuildContext context) {
    if (!FeatureFlags.supportSystemIntents) return;

    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              _handleSharedFiles(context, value);
            }
          },
          onError: (err) {
            debugPrint('getIntentDataStream error: $err');
          },
        );

    // For sharing images coming from outside the app while the app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _handleSharedFiles(context, value);
      }
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  void _handleSharedFiles(BuildContext context, List<SharedMediaFile> files) {
    if (_authService.currentUser == null) return;

    // Check if context is still valid (mounted and has navigator)
    if (!_isContextValid(context)) {
      _queueFilesForLater(context, files);
      return;
    }

    _showShareModal(context, files);
  }

  bool _isContextValid(BuildContext context) {
    // Check if context is still mounted by verifying it can access a navigator
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      return navigator.mounted;
    } catch (e) {
      // Navigator.of throws when no navigator is found
      return false;
    }
  }

  void _queueFilesForLater(BuildContext context, List<SharedMediaFile> files) {
    // Accumulate all pending files
    _pendingFiles = [...?_pendingFiles, ...files];

    // If already scheduled, don't schedule again
    if (_isShowingModal) return;

    _retryAttempts = 0;
    _scheduleRetry(context);
  }

  void _scheduleRetry(BuildContext context) {
    _isShowingModal = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryShowPendingFiles(context);
    });
  }

  void _tryShowPendingFiles(BuildContext context) {
    if (_pendingFiles == null || _pendingFiles!.isEmpty) {
      _isShowingModal = false;
      _retryAttempts = 0;
      return;
    }

    // Check if we should stop retrying
    if (_retryAttempts >= _maxRetryAttempts) {
      debugPrint(
        'SharingService: Max retry attempts reached, clearing pending files',
      );
      _pendingFiles = null;
      _isShowingModal = false;
      _retryAttempts = 0;
      return;
    }

    // Try to show the modal
    if (_isContextValid(context)) {
      final files = _pendingFiles!;
      _pendingFiles = null;
      _isShowingModal = false;
      _retryAttempts = 0;
      _showShareModal(context, files);
    } else {
      // Schedule another retry
      _retryAttempts++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryShowPendingFiles(context);
      });
    }
  }

  void _showShareModal(BuildContext context, List<SharedMediaFile> files) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareToChatModal(files: files),
    ).catchError((e) {
      // Handle case where modal is dismissed or fails to show
      debugPrint('SharingService: ModalBottomSheet error: $e');
      return null;
    });
  }
}

class ShareToChatModal extends StatefulWidget {
  final List<SharedMediaFile> files;
  const ShareToChatModal({super.key, required this.files});

  @override
  State<ShareToChatModal> createState() => _ShareToChatModalState();
}

class _ShareToChatModalState extends State<ShareToChatModal> {
  String _searchQuery = '';
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversations = context.watch<ConversationProvider>().conversations;

    final filteredConversations = conversations.where((c) {
      return c.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Share to...',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isSending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredConversations.isEmpty
                ? Center(
                    child: Text(
                      'No conversations found',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conv = filteredConversations[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: conv.otherUserAvatar.isNotEmpty
                              ? NetworkImage(conv.otherUserAvatar)
                              : null,
                          child: conv.otherUserAvatar.isEmpty
                              ? Text(conv.otherUserName[0].toUpperCase())
                              : null,
                        ),
                        title: Text(conv.otherUserName),
                        onTap: _isSending
                            ? null
                            : () => _shareToConversation(conv),
                        trailing: const Icon(Icons.send_rounded),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToConversation(Conversation conversation) async {
    setState(() => _isSending = true);

    try {
      final messagingService = MessagingService();
      final authService = AuthService();
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      for (final sharedFile in widget.files) {
        final String filePath = sharedFile.path;
        final file = File(filePath);
        final sizeInBytes = await file.length();
        final sizeInMb = sizeInBytes / (1024 * 1024);

        // Simple type detection
        final pathLower = sharedFile.path.toLowerCase();
        final isAudio =
            pathLower.endsWith('.mp3') ||
            pathLower.endsWith('.m4a') ||
            pathLower.endsWith('.wav');

        if (sizeInMb > 50) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              'File ${sharedFile.path.split('/').last} is too large (Max 50MB). Skipping.',
            );
          }
          continue;
        }

        String folder = 'files';
        MessageType type = MessageType.document;

        if (pathLower.endsWith('.jpg') ||
            pathLower.endsWith('.jpeg') ||
            pathLower.endsWith('.png')) {
          folder = 'images';
          type = MessageType.image;
        } else if (pathLower.endsWith('.mp4') || pathLower.endsWith('.mov')) {
          folder = 'videos';
          type = MessageType.document;
        } else if (isAudio) {
          folder = 'audio';
          type = MessageType.voice;
        }

        final mediaUrl = await messagingService.uploadChatMedia(
          filePath,
          folder: folder,
        );

        await messagingService.sendMessage(
          conversationId: conversation.id,
          senderId: userId,
          content: 'Shared a file',
          messageType: type,
          mediaUrl: mediaUrl,
          mediaFileName: filePath.split('/').last,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.showSuccess(context, 'Shared successfully!');
        // Optionally navigate to the chat
        // context.push('/chat/${conversation.id}');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
