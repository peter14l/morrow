import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/presentation/widgets/polls/poll_widgets.dart';

class PostContent extends StatelessWidget {
  final Post post;
  final Function(String optionId)? onVote;

  const PostContent({super.key, required this.post, this.onVote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.content != null && post.content!.isNotEmpty)
            Text(post.content!, style: theme.textTheme.bodyLarge),
          if (post.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  post.mediaUrls.first,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                ),
              ),
            ),
          if (post.poll != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: PollWidget(poll: post.poll!, onVote: onVote),
            ),
        ],
      ),
    );
  }
}
