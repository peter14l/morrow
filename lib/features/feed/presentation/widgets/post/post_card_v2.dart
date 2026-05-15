import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/presentation/widgets/post/post_header.dart';
import 'package:oasis/features/feed/presentation/widgets/post/post_content.dart';
import 'package:oasis/features/feed/presentation/widgets/post/post_actions.dart';
import 'package:oasis/features/feed/presentation/widgets/post/post_footer.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final Function(String optionId)? onVote;
  final bool isOwnPost;
  final bool showInteractionButtons;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onBookmark,
    this.onComment,
    this.onShare,
    this.onDelete,
    this.onVote,
    this.isOwnPost = false,
    this.showInteractionButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(post: post, isOwnPost: isOwnPost, onDelete: onDelete),
          PostContent(post: post, onVote: onVote),
          if (showInteractionButtons)
            PostActions(
              post: post,
              onLike: onLike,
              onBookmark: onBookmark,
              onComment: onComment,
              onShare: onShare,
            ),
          PostFooter(post: post),
        ],
      ),
    );
  }
}
