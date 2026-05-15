import 'package:oasis/widgets/skeleton_container.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';

class StoriesBar extends StatefulWidget {
  final List<StoryGroupEntity> storyGroups;
  final List<StoryEntity>? currentUserStories;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const StoriesBar({
    super.key,
    required this.storyGroups,
    this.currentUserStories,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  final AuthService _authService = AuthService();

  Widget _buildYourStoryButton(BuildContext context, ThemeData theme) {
    final currentUser = _authService.currentUser;
    final hasOwnStories = widget.currentUserStories?.isNotEmpty ?? false;
    final hasUnviewedOwnStories =
        widget.currentUserStories?.any((s) => !s.hasViewed) ?? false;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return _AnimatedStoryScale(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isM3E ? BorderRadius.circular(24) : null,
                  gradient: hasOwnStories && hasUnviewedOwnStories
                      ? LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.colorScheme.secondary,
                            theme.colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: hasOwnStories && !hasUnviewedOwnStories
                      ? Border.all(color: Colors.grey.shade300, width: 2)
                      : (!hasOwnStories
                            ? Border.all(
                                color: theme.colorScheme.outlineVariant,
                              )
                            : null),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isM3E ? BorderRadius.circular(21) : null,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: hasOwnStories ? 3 : 0,
                    ),
                  ),
                  child: hasOwnStories && currentUser?.photoUrl != null
                      ? Container(
                          decoration: BoxDecoration(
                            shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: isM3E
                                ? BorderRadius.circular(18)
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: currentUser!.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.add,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                ),
              ),
              // Add button overlay when user has stories
              if (hasOwnStories)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Create Story Screen
                      context.push('/stories/create');
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              'Your Story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isM3E ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
      onTap: () async {
        if (hasOwnStories) {
          // View own stories
          context.push(
            '/story/${widget.currentUserStories!.first.id}',
            extra: widget.currentUserStories,
          );
        } else {
          // Create new story - navigate to Create Story Screen
          context.push('/stories/create');
        }
      },
    );
  }

  Widget _buildStoryGroupCircle(
    BuildContext context,
    ThemeData theme,
    StoryGroupEntity group,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return _AnimatedStoryScale(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(24) : null,
              gradient: group.hasUnviewed
                  ? LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.colorScheme.secondary,
                        theme.colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: !group.hasUnviewed
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
                  imageUrl: group.avatarUrl,
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
              group.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: group.hasUnviewed || isM3E
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      onTap: () {
        // Navigate to story viewer with all stories from this user
        if (group.stories.isNotEmpty) {
          context.push(
            '/story/${group.stories.first.id}',
            extra: group.stories,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = _authService.currentUser?.id;

    // Filter out current user's stories from groups (they go in "Your Story")
    final otherUserGroups = widget.storyGroups
        .where((group) => group.userId != currentUserId)
        .toList();

    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: widget.isLoading ? 6 : otherUserGroups.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          if (widget.isLoading) {
            return const Column(
              children: [
                SkeletonContainer.circular(size: 70),
                SizedBox(height: 4),
                SkeletonContainer.rounded(width: 50, height: 10),
              ],
            );
          }

          if (index == 0) {
            return _buildYourStoryButton(context, theme);
          }

          final group = otherUserGroups[index - 1];
          return _buildStoryGroupCircle(context, theme, group);
        },
      ),
    );
  }
}

class _AnimatedStoryScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedStoryScale({required this.child, required this.onTap});

  @override
  State<_AnimatedStoryScale> createState() => _AnimatedStoryScaleState();
}

class _AnimatedStoryScaleState extends State<_AnimatedStoryScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
