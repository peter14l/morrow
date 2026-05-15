import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

class PostActions extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const PostActions({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onComment,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _ActionButton(
            icon: post.isLiked
                ? FluentIcons.heart_24_filled
                : FluentIcons.heart_24_regular,
            activeColor: Colors.red,
            isActive: post.isLiked,
            onTap: onLike,
            label: post.likeCount.toString(),
          ),
          _ActionButton(
            icon: FluentIcons.comment_24_regular,
            onTap: onComment,
            label: post.commentCount.toString(),
          ),
          _ActionButton(
            icon: post.isBookmarked
                ? FluentIcons.bookmark_24_filled
                : FluentIcons.bookmark_24_regular,
            activeColor: colorScheme.primary,
            isActive: post.isBookmarked,
            onTap: onBookmark,
          ),
          const Spacer(),
          _ActionButton(icon: FluentIcons.share_24_regular, onTap: onShare),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? activeColor;
  final bool isActive;
  final VoidCallback? onTap;
  final String? label;

  const _ActionButton({
    required this.icon,
    this.activeColor,
    this.isActive = false,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive
        ? (activeColor ?? colorScheme.primary)
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
