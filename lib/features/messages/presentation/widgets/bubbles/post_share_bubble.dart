import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/text_bubble.dart'
    as text_bubble;

/// Post share bubble — shows a post card with thumbnail + author + caption.
/// Extracted from _buildPostShareBubble() in chat_screen.dart.
class PostShareBubble extends StatelessWidget {
  const PostShareBubble({super.key, required this.message, required this.isMe});

  final dynamic message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shareData = message.shareData;

    final username = shareData?['username'] ?? 'User';
    final userAvatar = shareData?['user_avatar'];
    final postContent = shareData?['content'] ?? message.content;
    final mediaUrl = message.mediaUrl ?? shareData?['image_url'];

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
          if (message.postId != null) {
            context.push('/post/${message.postId}');
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Author Info Header
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
            if (mediaUrl != null)
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.cover,
                  ),
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
                        Icons.grid_view_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Post shared',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (postContent.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final bool isCiphertext =
                            text_bubble.MessageTextUtils.isDisplayableCaption(
                              postContent,
                            ) ==
                            false;
                        return Text(
                          isCiphertext ? '🔒 Message encrypted' : postContent,
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
