import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;
import 'package:oasis/services/digital_wellbeing_service.dart';

class SpatialGliderLayout extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget mobileHeader;
  final Widget Function(
    dynamic post,
    FeedProvider provider,
    bool isDesktopPadding,
  )
  buildPostItem;

  const SpatialGliderLayout({
    super.key,
    required this.onRefresh,
    required this.mobileHeader,
    required this.buildPostItem,
  });

  @override
  State<SpatialGliderLayout> createState() => _SpatialGliderLayoutState();
}

class _SpatialGliderLayoutState extends State<SpatialGliderLayout>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _scrollController.addListener(() {
      setState(() {}); // Rebuild for parallax calculations
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        // Ambient Background
        AnimatedBuilder(
          animation: _bgAnimationController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.5 * (1 + 0.2 * (0.5 - _bgAnimationController.value)),
                    0.5 * (1 + 0.2 * (_bgAnimationController.value - 0.5)),
                  ),
                  radius: 1.5,
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                ),
              ),
            );
          },
        ),

        RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (!isDesktop)
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  toolbarHeight: 70,
                  automaticallyImplyLeading: false,
                  centerTitle: true,
                  title: widget.mobileHeader,
                  floating: true,
                ),

              SliverToBoxAdapter(
                child: _buildFeedInfoBanner(context, colorScheme),
              ),

              Consumer<FeedProvider>(
                builder: (context, provider, _) {
                  final posts = provider.posts;
                  if (provider.isLoading && posts.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 60 : 16,
                      vertical: 32,
                    ),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: isDesktop ? 3 : 1,
                      mainAxisSpacing: 40,
                      crossAxisSpacing: 40,
                      itemBuilder: (context, index) {
                        return _buildGliderItem(
                          posts[index],
                          provider,
                          isDesktop,
                          index,
                        );
                      },
                      childCount: posts.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedInfoBanner(BuildContext context, ColorScheme colorScheme) {
    final wellbeing = context.watch<DigitalWellbeingService>();
    final threshold = wellbeing.lockoutThresholdMinutes;

    return Center(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Intentional Limit: ${wellbeing.totalMinutes}m / $threshold\m',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGliderItem(
    dynamic post,
    FeedProvider provider,
    bool isDesktop,
    int index,
  ) {
    // Parallax & Depth logic - create a more 'spatial' feeling
    double scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    double horizontalShift = 0;
    if (!isDesktop) {
      final itemPosition = (index * 400.0) - scrollOffset;
      horizontalShift =
          (index % 2 == 0 ? 1 : -1) *
          20.0 *
          (1.0 -
              (itemPosition / MediaQuery.of(context).size.height)
                  .clamp(-1.0, 1.0)
                  .abs());
    }

    return Transform.translate(
      offset: Offset(horizontalShift, 0),
      child: motion.Animate(
        effects: [
          motion.FadeEffect(delay: (index % 5 * 100).ms, duration: 800.ms),
          motion.MoveEffect(
            begin: const Offset(0, 50),
            duration: 800.ms,
            curve: Curves.easeOutCubic,
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: -15,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: widget.buildPostItem(post, provider, isDesktop),
          ),
        ),
      ),
    );
  }
}
