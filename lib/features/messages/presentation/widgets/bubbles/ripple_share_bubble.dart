import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/text_bubble.dart'
    as text_bubble;

/// Ripple share bubble — shows a ripple preview card with thumbnail.
/// Extracted from _buildRippleBubble() in chat_screen.dart.
class RippleShareBubble extends StatelessWidget {
  const RippleShareBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final dynamic message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shareData = message.shareData;

    final username = shareData?['username'] ?? 'User';
    final userAvatar = shareData?['user_avatar'];
    final caption = shareData?['caption'] ?? message.content;
    final mediaUrl = message.mediaUrl ?? shareData?['thumbnail_url'];

    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMe
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (message.rippleId != null) {
            context.push(
              '/ripples',
              extra: {'initialRippleId': message.rippleId},
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage:
                          (userAvatar != null && userAvatar.isNotEmpty)
                          ? NetworkImage(userAvatar)
                          : null,
                      child: (userAvatar == null || userAvatar.isEmpty)
                          ? Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(fontSize: 8),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      username,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 9 / 16,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mediaUrl != null)
                      CachedNetworkImage(imageUrl: mediaUrl, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey.withValues(alpha: 0.2)),
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 48,
                      ),
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
                          Icons.blur_on_rounded,
                          size: 14,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ripple shared',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final bool isCiphertext =
                              text_bubble.MessageTextUtils.isDisplayableCaption(
                                caption,
                              ) ==
                              false;
                          return Text(
                            isCiphertext ? '🔒 Message encrypted' : caption,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: isCiphertext ? FontStyle.italic : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
