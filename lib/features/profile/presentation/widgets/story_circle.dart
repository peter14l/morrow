import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:provider/provider.dart';

class StoryCircle extends StatelessWidget {
  final StoryEntity story;
  final VoidCallback onTap;

  const StoryCircle({super.key, required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(24) : null,
              gradient: !story.hasViewed
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: story.hasViewed
                  ? Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 2,
                    )
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isM3E ? BorderRadius.circular(21) : null,
                color: theme.colorScheme.surface,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isM3E ? BorderRadius.circular(18) : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: CachedNetworkImageProvider(
                    story.userAvatar ?? '',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            story.username ?? 'Unknown',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isM3E ? FontWeight.bold : null,
              letterSpacing: isM3E ? -0.2 : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
