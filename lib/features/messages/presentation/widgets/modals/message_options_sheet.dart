import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/widgets/messages/forward_message_modal.dart';
import 'package:oasis/widgets/messages/message_reactions.dart';
import 'package:oasis/widgets/moderation_dialogs.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

/// Message reactions picker sheet.
class MessageOptionsSheet extends StatelessWidget {
  const MessageOptionsSheet({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.onReply,
    this.onEdit,
    required this.onForward,
    required this.onCopy,
    required this.onUnsend,
    required this.onReactionSelected,
  });

  final Message message;
  final bool isOwnMessage;
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final isSolid = ContextX(context).shouldUseSolidBackground;
    final isDark = theme.brightness == Brightness.dark;

    final sheetContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MessageReactionPicker(
            onReactionSelected: (emoji) {
              onReactionSelected(emoji);
              Navigator.pop(context);
            },
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, indent: 24, endIndent: 24),
        const SizedBox(height: 8),
        _ModalAction(
          icon: Icons.reply_rounded,
          label: 'Reply',
          onTap: () {
            Navigator.pop(context);
            onReply();
          },
        ),
        _ModalAction(
          icon: Icons.shortcut_rounded,
          label: 'Forward',
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (context) =>
                  SafeArea(child: ForwardMessageModal(message: message)),
            );
          },
        ),
        if (isOwnMessage && message.messageType == MessageType.text && onEdit != null && message.content != '🔒 Message encrypted')
          _ModalAction(
            icon: Icons.edit_rounded,
            label: 'Edit',
            onTap: () {
              Navigator.pop(context);
              onEdit!();
            },
          ),
        if (message.messageType == MessageType.text &&
            message.content != '🔒 Message encrypted')
          _ModalAction(
            icon: Icons.copy_rounded,
            label: 'Copy Text',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        if (isOwnMessage)
          _ModalAction(
            icon: Icons.delete_outline_rounded,
            label: 'Unsend',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              onUnsend();
            },
          ),
        if (!isOwnMessage)
          _ModalAction(
            icon: Icons.flag_outlined,
            label: 'Report Message',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              ReportDialog.show(
                context,
                messageId: message.id,
                userId: message.senderId,
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isSolid
              ? (isDark ? const Color(0xFF1A1D24) : Colors.white)
              : (disableTransparency
                    ? colorScheme.surface
                    : colorScheme.surface.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: (isSolid || disableTransparency)
              ? sheetContent
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: sheetContent,
                ),
        ),
      ),
    );
  }
}

class _ModalAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ModalAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive ? Colors.red : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color.withValues(alpha: 0.8), size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
