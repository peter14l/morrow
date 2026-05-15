import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';

class FocusedFlowLayout extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget mobileHeader;
  final Widget Function(
    dynamic post,
    FeedProvider provider,
    bool isDesktopPadding,
  )
  buildPostItem;

  const FocusedFlowLayout({
    super.key,
    required this.onRefresh,
    required this.mobileHeader,
    required this.buildPostItem,
  });

  @override
  State<FocusedFlowLayout> createState() => _FocusedFlowLayoutState();
}

class _FocusedFlowLayoutState extends State<FocusedFlowLayout> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Consumer<FeedProvider>(
      builder: (context, provider, _) {
        final posts = provider.posts;
        if (provider.isLoading && posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (posts.isEmpty) {
          return const Center(child: Text('No posts found.'));
        }

        // Get dominant color or image for background of current page
        final int currentIndex = _currentPage.round().clamp(
          0,
          posts.length - 1,
        );
        final currentPost = posts[currentIndex];

        Color bgBaseColor = theme.scaffoldBackgroundColor;
        if (currentPost.dominantColor != null) {
          try {
            final colorStr = currentPost.dominantColor!.replaceAll('#', '');
            bgBaseColor = Color(
              int.parse('FF$colorStr', radix: 16),
            ).withValues(alpha: 0.3);
          } catch (_) {}
        }

        return Stack(
          children: [
            // Ambient Backdrop
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgBaseColor, theme.scaffoldBackgroundColor],
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),
            ),

            // PageView for posts
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: posts.length,
              onPageChanged: (index) {
                if (index >= posts.length - 2) {
                  // Trigger load more
                }
              },
              itemBuilder: (context, index) {
                final post = posts[index];

                // Calculate scale and opacity based on distance from current page
                double relativePosition = index - _currentPage;
                double scale = (1 - (relativePosition.abs() * 0.2)).clamp(
                  0.8,
                  1.0,
                );
                double opacity = (1 - (relativePosition.abs() * 0.5)).clamp(
                  0.4,
                  1.0,
                );

                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 600 : double.infinity,
                          maxHeight: MediaQuery.of(context).size.height * 0.75,
                        ),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: widget.buildPostItem(
                            post,
                            provider,
                            isDesktop,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Header for mobile
            if (!isDesktop)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: widget.mobileHeader,
                    ),
                    _buildFeedInfoBanner(context, colorScheme),
                  ],
                ),
              ),

            // Helpful hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: motion.Animate(
                  onPlay: (c) => c.repeat(),
                  effects: [
                    motion.FadeEffect(duration: Duration(seconds: 2)),
                    motion.MoveEffect(
                      begin: Offset(0, 0),
                      end: Offset(0, -10),
                      duration: Duration(seconds: 2),
                    ),
                  ],
                  child: const Column(
                    children: [
                      Icon(Icons.keyboard_arrow_up, color: Colors.white54),
                      Text(
                        'Swipe for more',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedInfoBanner(BuildContext context, ColorScheme colorScheme) {
    final wellbeing = context.watch<DigitalWellbeingService>();
    final threshold = wellbeing.lockoutThresholdMinutes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Limit: ${wellbeing.totalMinutes}m / $threshold\m',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
