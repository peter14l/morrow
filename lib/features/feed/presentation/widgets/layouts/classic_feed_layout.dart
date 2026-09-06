import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:oasis/features/feed/presentation/widgets/stories_bar.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/features/monetization/presentation/widgets/privacy_ad_banner.dart';

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


              Consumer<FeedProvider>(
                builder: (context, provider, _) {
                  final posts = provider.posts;
                  if (provider.isLoading && posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (posts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                blurRadius: 24,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 48, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Your feed is empty',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Follow some friends or join a circle to see their updates here.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                          if ((index + 1) % 6 == 0) {
                            return const PrivacyAdBanner(screenCategory: 'feed');
                          }
                          final postIndex = index - (index / 6).floor();
                          final post = posts[postIndex];
                          return RepaintBoundary(
                            child: buildPostItem(post, provider, true),
                          );
                        },
                        childCount: posts.length + (posts.length / 5).floor(),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if ((index + 1) % 6 == 0) {
                          return const PrivacyAdBanner(screenCategory: 'feed');
                        }
                        final postIndex = index - (index / 6).floor();
                        final post = posts[postIndex];
                        return RepaintBoundary(
                          child: buildPostItem(post, provider, false),
                        );
                      }, childCount: posts.length + (posts.length / 5).floor()),
                    ),
                  );                },
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
              'Today\'s Feed time: ${wellbeing.totalMinutes}m / ${threshold}m limit (Feed + Ripples)',
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
