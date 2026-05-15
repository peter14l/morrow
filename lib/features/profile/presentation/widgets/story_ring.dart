import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:provider/provider.dart';

class StoryRing extends StatelessWidget {
  final StoryGroupEntity storyGroup;
  final VoidCallback? onTap;

  const StoryRing({super.key, required this.storyGroup, this.onTap});

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
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(24) : null,
              gradient: storyGroup.hasUnviewed
                  ? LinearGradient(
                      colors: [theme.primaryColor, theme.colorScheme.secondary],
                    )
                  : null,
              border: !storyGroup.hasUnviewed
                  ? Border.all(color: Colors.grey.shade300, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isM3E ? BorderRadius.circular(21) : null,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 3,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isM3E ? BorderRadius.circular(18) : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: storyGroup.avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey.shade200),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              storyGroup.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: storyGroup.hasUnviewed || isM3E
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
