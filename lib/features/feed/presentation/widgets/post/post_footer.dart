import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

class PostFooter extends StatelessWidget {
  final Post post;

  const PostFooter({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // Current post footer for circles/mentions/hashtags
    if (post.hashtags.isEmpty && post.mentions.isEmpty)
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        children: [
          ...post.hashtags.map((tag) => _TagPill(label: '#$tag')),
          ...post.mentions.map((m) => _TagPill(label: '@$m', isMention: true)),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final bool isMention;

  const _TagPill({required this.label, this.isMention = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: isMention ? colorScheme.secondary : colorScheme.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
