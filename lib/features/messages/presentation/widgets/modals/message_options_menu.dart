import 'package:flutter/material.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/widgets/messages/forward_message_modal.dart';
import 'package:oasis/widgets/messages/message_reactions.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/widgets/moderation_dialogs.dart';
import 'package:oasis/core/utils/responsive_layout.dart';

/// Desktop context menu for message options.
/// Extracted from the desktop branch of _showMessageOptions() in chat_screen.dart.
class MessageOptionsMenu extends StatelessWidget {
  const MessageOptionsMenu({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.position,
    required this.onReply,
    this.onEdit,
    required this.onForward,
    required this.onCopy,
    required this.onUnsend,
    required this.onReactionSelected,
  });

  final Message message;
  final bool isOwnMessage;
  final Offset position;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback onForward;
  final VoidCallback onCopy;
  final VoidCallback onUnsend;
  final Function(String) onReactionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: <PopupMenuEntry>[
        PopupMenuItem(
          onTap: () {
            showMenu(
              context: context,
              position: RelativeRect.fromLTRB(
                position.dx + 120,
                position.dy,
                position.dx + 120,
                position.dy,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              elevation: 8,
              items: <PopupMenuEntry>[
                PopupMenuItem(
                  enabled: false,
                  child: MessageReactionPicker(
                    onReactionSelected: onReactionSelected,
                  ),
                ),
              ],
            );
          },
          child: Row(
            children: [
              const Text('😀', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text('Add Reaction', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onReply,
          child: const Row(
            children: [
              Icon(FluentIcons.arrow_reply_24_regular, size: 20),
              SizedBox(width: 12),
              Text('Reply'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            // Desktop: Show forward selection inline, Mobile: Show bottom sheet
            if (ResponsiveLayout.isDesktop(context)) {
              _showForwardDialog(context);
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (context) =>
                    SafeArea(child: ForwardMessageModal(message: message)),
              );
            }
          },
          child: const Row(
            children: [
              Icon(FluentIcons.share_24_regular, size: 20),
              SizedBox(width: 12),
              Text('Forward'),
            ],
          ),
        ),
        if (isOwnMessage && message.messageType == MessageType.text && onEdit != null && message.content != '🔒 Message encrypted')
          PopupMenuItem(
            onTap: onEdit,
            child: const Row(
              children: [
                Icon(FluentIcons.edit_24_regular, size: 20),
                SizedBox(width: 12),
                Text('Edit'),
              ],
            ),
          ),
        if (message.messageType == MessageType.text &&
            message.content != '🔒 Message encrypted')
          PopupMenuItem(
            onTap: () {
              onCopy();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Row(
              children: [
                Icon(FluentIcons.copy_24_regular, size: 20),
                SizedBox(width: 12),
                Text('Copy Text'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        if (!isOwnMessage)
          PopupMenuItem(
            onTap: () {
              ReportDialog.show(
                context,
                messageId: message.id,
                userId: message.senderId,
              );
            },
            child: Row(
              children: [
                Icon(
                  FluentIcons.flag_24_regular,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 12),
                const Text('Report', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        if (isOwnMessage)
          PopupMenuItem(
            onTap: onUnsend,
            child: Row(
              children: [
                Icon(
                  FluentIcons.delete_24_regular,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 12),
                const Text('Unsend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );

    return const SizedBox.shrink();
  }

  void _showForwardDialog(BuildContext context) {
    // Show a simple dialog for forward selection on desktop
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward Message'),
        content: const Text(
          'Use the search to find a conversation to forward to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to new message screen
              onForward();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}
