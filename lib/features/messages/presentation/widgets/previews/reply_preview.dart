import 'package:flutter/material.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';

/// Reply preview bar shown above the input area when replying to a message.
/// Extracted from _buildReplyPreview() in chat_screen.dart.
class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final Message message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget previewContent = Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                message.content == 'Sent attachment'
                    ? (message.messageType == MessageType.voice
                          ? '🎤 Voice Message'
                          : '📷 Image')
                    : message.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: onDismiss,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: LiquidGlassWrapper(
        borderRadius: 16,
        config: LiquidGlassConfig.Light,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: previewContent,
      ),
    );
  }
}
