import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/text_bubble.dart'
    as text_bubble;

/// Story reply bubble — shows a muted story thumbnail with a quote reply.
/// Extracted from _buildStoryReplyBubble() in chat_screen.dart.
class StoryReplyBubble extends StatelessWidget {
  const StoryReplyBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.formatTime,
  });

  final dynamic message;
  final bool isMe;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderRadius = BorderRadius.circular(20).copyWith(
      bottomRight: isMe ? const Radius.circular(4) : null,
      bottomLeft: !isMe ? const Radius.circular(4) : null,
    );

    final hasMedia = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMedia)
            ClipRRect(
              borderRadius: borderRadius.copyWith(
                bottomLeft: Radius.zero,
                bottomRight: Radius.zero,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.3),
                    colorBlendMode: BlendMode.darken,
                  ),
                  Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 36,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Replied to a story',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (message.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final bool isCiphertext =
                          text_bubble.MessageTextUtils.isDisplayableCaption(
                            message.content,
                          ) ==
                          false;
                      return Text(
                        isCiphertext ? '🔒 Message encrypted' : message.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontStyle: isCiphertext ? FontStyle.italic : null,
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatTime(message.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onLongPress: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: card,
        ),
      ),
    );
  }
}
