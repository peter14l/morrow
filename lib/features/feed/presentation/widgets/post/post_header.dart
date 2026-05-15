import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class PostHeader extends StatelessWidget {
  final Post post;
  final bool isOwnPost;
  final VoidCallback? onDelete;

  const PostHeader({
    super.key,
    required this.post,
    required this.isOwnPost,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: post.authorAvatar != null
                ? NetworkImage(post.authorAvatar!)
                : null,
            child: post.authorAvatar == null ? Text(post.authorName[0]) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.authorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _QuantumSecureBadge(),
                  ],
                ),
                Text(
                  timeago.format(post.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.more_horizontal_24_regular),
            onPressed: () {
              // TODO: Implement more options flyout
            },
          ),
        ],
      ),
    );
  }
}

class _QuantumSecureBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Quantum-Secure (PQ-Aura)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 10, color: colorScheme.primary),
            const SizedBox(width: 2),
            Text(
              'PQ',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
