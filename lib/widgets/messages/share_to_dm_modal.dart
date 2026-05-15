import 'package:flutter/material.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/messages/domain/models/conversation.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:oasis/themes/theme_provider.dart';

class ShareToDirectMessageModal extends StatefulWidget {
  final String? content;
  final MessageType messageType;
  final String? mediaUrl;
  final String? postId;
  final String? rippleId;
  final String? title;
  final Map<String, dynamic>? shareData;

  const ShareToDirectMessageModal({
    super.key,
    this.content,
    required this.messageType,
    this.mediaUrl,
    this.postId,
    this.rippleId,
    this.title = 'Share to...',
    this.shareData,
  });

  @override
  State<ShareToDirectMessageModal> createState() =>
      _ShareToDirectMessageModalState();
}

class _ShareToDirectMessageModalState extends State<ShareToDirectMessageModal> {
  String _searchQuery = '';
  bool _isSending = false;
  final List<String> _selectedConversationIds = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversations = context.watch<ConversationProvider>().conversations;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final filteredConversations = conversations.where((c) {
      return c.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final modalContent = Column(
      children: [
        if (!isDesktop) ...[
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Text(
                widget.title!,
                style:
                    (isDesktop
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
              ),
              const Spacer(),
              if (_isSending)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (isDesktop)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search people...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final conv = filteredConversations[index];
                    final isSelected = _selectedConversationIds.contains(
                      conv.id,
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: conv.otherUserAvatar.isNotEmpty
                            ? NetworkImage(conv.otherUserAvatar)
                            : null,
                        child: conv.otherUserAvatar.isEmpty
                            ? Text(conv.otherUserName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        conv.otherUserName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.send_rounded,
                          color: isSelected
                              ? Colors.green
                              : colorScheme.primary,
                        ),
                        onPressed: _isSending || isSelected
                            ? null
                            : () => _shareToConversation(conv),
                      ),
                      onTap: _isSending || isSelected
                          ? null
                          : () => _shareToConversation(conv),
                    );
                  },
                ),
        ),
      ],
    );

    if (isDesktop) {
      return Center(
        child: Container(
          width: 500,
          height: 600,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
              ),
            ],
          ),
          child: Material(color: Colors.transparent, child: modalContent),
        ),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: disableTransparency
              ? colorScheme.surface
              : colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: disableTransparency
              ? modalContent
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: modalContent,
                ),
        ),
      ),
    );
  }

  Future<void> _shareToConversation(Conversation conversation) async {
    setState(() {
      _isSending = true;
      _selectedConversationIds.add(conversation.id);
    });

    try {
      final messagingService = MessagingService();
      final authService = AuthService();
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      await messagingService.sendMessage(
        conversationId: conversation.id,
        senderId: userId,
        content: widget.content ?? '',
        messageType: widget.messageType,
        mediaUrl: widget.mediaUrl,
        postId: widget.postId,
        rippleId: widget.rippleId,
        shareData: widget.shareData,
      );

      if (mounted) {
        context.read<ConversationProvider>().onMessageSent(
          conversation.id,
          widget.content ?? '',
          widget.messageType.name,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to ${conversation.otherUserName}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _selectedConversationIds.remove(conversation.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
