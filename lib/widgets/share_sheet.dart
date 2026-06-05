import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/messages/domain/models/message.dart';

class ShareSheet extends StatefulWidget {
  final String title;
  final String payload;
  final String? successMessage;
  final MessageType messageType;
  final String? rippleId;
  final String? storyId;
  final String? externalMessage;

  const ShareSheet({
    super.key,
    required this.title,
    required this.payload,
    this.successMessage,
    this.messageType = MessageType.text,
    this.rippleId,
    this.storyId,
    this.externalMessage,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String payload,
    String? successMessage,
    MessageType messageType = MessageType.text,
    String? rippleId,
    String? storyId,
    String? externalMessage,
  }) {
    return context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(
        title: title,
        payload: payload,
        successMessage: successMessage,
        messageType: messageType,
        rippleId: rippleId,
        storyId: storyId,
        externalMessage: externalMessage,
      ),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  String _searchQuery = '';
  final Set<String> _sentConversationIds = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Ensure conversations are loaded when the sheet is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
      if (currentUserId != null) {
        context.read<ConversationProvider>().initialize(currentUserId);
      }
    });
  }

  List<Conversation> get _filteredConversations {
    final provider = context.watch<ConversationProvider>();
    if (_searchQuery.isEmpty) return provider.conversations;

    return provider.conversations.where((c) {
      return c.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _sendToConversation(Conversation conversation) async {
    if (_sentConversationIds.contains(conversation.id) || _isSending) return;

    final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
    if (currentUserId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messagingService = MessagingService();
      await messagingService.sendMessage(
        conversationId: conversation.id,
        senderId: currentUserId,
        content: widget.payload,
        messageType: widget.messageType,
        rippleId: widget.rippleId,
        storyId: widget.storyId,
      );

      setState(() {
        _sentConversationIds.add(conversation.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.successMessage ?? 'Sent to ${conversation.otherUserName}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _shareExternally() {
    final message = widget.externalMessage ?? widget.payload;
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversations = _filteredConversations;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(FluentIcons.dismiss_24_regular),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        prefixIcon: const Icon(FluentIcons.search_24_regular),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _shareExternally,
                    icon: const Icon(FluentIcons.share_ios_24_regular),
                    tooltip: 'Share externally',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Conversation List
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No conversations yet'
                            : 'No results found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        final hasSent = _sentConversationIds.contains(
                          conversation.id,
                        );

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage:
                                conversation.otherUserAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    conversation.otherUserAvatar,
                                  )
                                : null,
                            child: conversation.otherUserAvatar.isEmpty
                                ? Text(
                                    conversation.otherUserName[0].toUpperCase(),
                                  )
                                : null,
                          ),
                          title: Text(
                            conversation.otherUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: hasSent
                                ? null
                                : () => _sendToConversation(conversation),
                            style: FilledButton.styleFrom(
                              backgroundColor: hasSent
                                  ? colorScheme.surfaceContainerHighest
                                  : colorScheme.primaryContainer,
                              foregroundColor: hasSent
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onPrimaryContainer,
                            ),
                            child: Text(hasSent ? 'Sent' : 'Send'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
