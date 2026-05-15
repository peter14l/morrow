import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/features/feed/presentation/widgets/stories_bar.dart';
import 'package:oasis/features/capsules/presentation/widgets/capsule_carousel.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';

class ClassicFeedLayout extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final bool isDesktop;
  final bool isScrolled;
  final Widget mobileHeader;
  final Widget Function(
    dynamic post,
    FeedProvider provider,
    bool isDesktopPadding,
  )
  buildPostItem;

  const ClassicFeedLayout({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    required this.isDesktop,
    required this.isScrolled,
    required this.mobileHeader,
    required this.buildPostItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop
                ? ResponsiveLayout.maxContentWidth
                : double.infinity,
          ),
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            cacheExtent:
                1500, // Pre-render 1.5 screen heights to prevent lag during fast scrolls
            slivers: [
              if (!isDesktop)
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: isScrolled
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.transparent,
                  toolbarHeight: 70,
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  title: mobileHeader,
                ),

              SliverToBoxAdapter(
                child: _buildFeedInfoBanner(context, colorScheme),
              ),
              SliverToBoxAdapter(
                child: Consumer<StoriesProvider>(
                  builder: (context, storiesProvider, _) {
                    return StoriesBar(
                      storyGroups: storiesProvider.storyGroups,
                      currentUserStories: storiesProvider.userStories,
                      isLoading: storiesProvider.isLoading,
                      onRefresh: () {
                        storiesProvider.loadFollowingStories();
                        storiesProvider.loadMyStories();
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CapsuleCarousel(),
                ),
              ),

              Consumer<FeedProvider>(
                builder: (context, provider, _) {
                  final posts = provider.posts;
                  if (provider.isLoading && posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('No posts found.')),
                    );
                  }

                  if (isDesktop) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return RepaintBoundary(
                            child: buildPostItem(post, provider, true),
                          );
                        },
                        childCount: posts.length,
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final post = posts[index];
                        return RepaintBoundary(
                          child: buildPostItem(post, provider, false),
                        );
                      }, childCount: posts.length),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedInfoBanner(BuildContext context, ColorScheme colorScheme) {
    final wellbeing = context.watch<DigitalWellbeingService>();
    final threshold = wellbeing.lockoutThresholdMinutes;
    final usedMinutes = wellbeing.feedMinutes + wellbeing.ripplesMinutes;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Today\'s Feed time: ${wellbeing.totalMinutes}m / $threshold\m limit (Feed + Ripples)',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
