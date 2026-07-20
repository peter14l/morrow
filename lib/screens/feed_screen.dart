import 'package:oasis/core/extensions/context_extensions.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/stories_service.dart';
import 'package:oasis/features/feed/presentation/widgets/post/post_card_v2.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/feed/presentation/widgets/stories_bar.dart';
import 'package:oasis/widgets/capsules/capsule_carousel.dart';
import 'package:oasis/models/feed_layout_strategy.dart';
import 'package:oasis/features/feed/presentation/widgets/feed_layout_switcher.dart';
import 'package:oasis/screens/ripples_screen.dart';
import 'package:oasis/screens/pulse_feed_screen.dart';
import 'package:oasis/widgets/comments_modal.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/widgets/wellbeing/lockout_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final StoriesService _storiesService = StoriesService();
  List<StoryGroupEntity> _storyGroups = [];
  List<StoryEntity> _myStories = [];
  FeedLayoutType _currentLayout = FeedLayoutType.standard;
  bool _isScrolled = false;
  bool _isStoriesLoading = true;
  bool _showRipplesOverlay = false;

  // Desktop Comment Pane State
  String? _selectedPostId;
  bool _showCommentPane = false;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll);

    // Load initial feed and layout preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFeed();
      _loadStories();
      _loadLayoutPreference();
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        context.read<ProfileProvider>().loadFollowing(userId);
        context.read<RipplesProvider>().initForUser(userId);
      }

      // Start session tracking
      context.read<DigitalWellbeingService>().startTracking('feed');

      // Check if focus session is active and penalize if so
      final wellness = context.read<WellnessService>();
      if (wellness.isFocusSessionActive) {
        wellness.penalizeDistraction();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Focus Session: Browsing Feed during focus costs XP! 🌿',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wellbeing = context.read<DigitalWellbeingService>();
    if (state == AppLifecycleState.paused) {
      wellbeing.stopTracking();
    } else if (state == AppLifecycleState.resumed) {
      wellbeing.startTracking('feed');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _scrollController.dispose();
    if (mounted) {
      context.read<DigitalWellbeingService>().stopTracking();
    }
    super.dispose();
  }

  Future<void> _loadLayoutPreference() async {
    final layout = await FeedLayoutSwitcher.loadLayoutPreference();
    setState(() {
      _currentLayout = layout;
    });
  }

  void _loadFeed() {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    final provider = context.read<FeedProvider>();
    if (_tabController.index == 0) {
      provider.switchFeedType(FeedType.following, userId: userId);
    } else {
      provider.switchFeedType(FeedType.forYou, userId: userId);
    }
  }

  void _loadStories() async {
    setState(() => _isStoriesLoading = true);
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      final groups = await _storiesService.getFollowingStories();
      final myStories = await _storiesService.getMyStories();
      if (mounted) {
        setState(() {
          _storyGroups = groups;
          _myStories = myStories;
          _isStoriesLoading = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      await context.read<FeedProvider>().refresh(userId: userId);
      _loadStories();
    }
  }

  void _handleRipplesTap(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final service = context.read<RipplesProvider>();
    if (service.isRipplesLocked) {
      final end = service.lockoutEndTime;
      final diff = end != null ? end.difference(DateTime.now()).inMinutes : 30;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ripples is locked for $diff more minutes to maintain well-being.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.showResponsiveSheet(
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.waves_rounded, size: 48, color: colorScheme.primary)
                  .animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  )
                  .scale(duration: 1.seconds, curve: Curves.easeInOut),
              const SizedBox(height: 24),
              Text(
                'Enter Ripples',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your intentional focus duration',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    hintText: '00',
                    suffixText: 'min',
                    suffixStyle: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (val) {
                    final mins = int.tryParse(val);
                    if (mins != null && mins > 0) {
                      service.startSession(Duration(minutes: mins));
                      Navigator.pop(context);
                      if (ResponsiveLayout.isDesktop(context)) {
                        setState(() => _showRipplesOverlay = true);
                      } else {
                        context.push('/ripples');
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ripples limits distractions to help you stay present.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final wellbeing = context.watch<DigitalWellbeingService>();

    if (_currentLayout == FeedLayoutType.pulseMap) {
      return PulseFeedScreen(
        onLayoutChanged: (layout) => setState(() => _currentLayout = layout),
      );
    }

    final feedContent = RefreshIndicator(
      onRefresh: _refreshFeed,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!isDesktop)
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              elevation: 0,
              backgroundColor: _isScrolled
                  ? Colors.black.withValues(alpha: 0.8)
                  : Colors.transparent,
              toolbarHeight: 70,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: _buildMobileHeader(colorScheme, isM3E),
              actions: [
                FeedLayoutSwitcher(
                  currentLayout: _currentLayout,
                  onLayoutChanged: (layout) =>
                      setState(() => _currentLayout = layout),
                ),
                const SizedBox(width: 16),
              ],
            ),

          SliverToBoxAdapter(
            child: StoriesBar(
              storyGroups: _storyGroups,
              currentUserStories: _myStories,
              isLoading: _isStoriesLoading,
              onRefresh: _loadStories,
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
              return SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = posts[index];
                    return PostCard(
                      post: post,
                      onLike: () async {
                        final userId = _authService.currentUser?.id;
                        if (userId == null) return;

                        if (post.isLiked) {
                          provider.unlikePost(userId: userId, postId: post.id);
                        } else {
                          try {
                            await provider.likePost(
                              userId: userId,
                              postId: post.id,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to like post: ${e.toString()}',
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                      onComment: () {
                        if (isDesktop) {
                          setState(() {
                            if (_selectedPostId == post.id) {
                              _showCommentPane = !_showCommentPane;
                            } else {
                              _selectedPostId = post.id;
                              _showCommentPane = true;
                            }
                          });
                        } else {
                          context.push('/post/${post.id}/comments');
                        }
                      },
                      onBookmark: () {
                        final userId = _authService.currentUser?.id;
                        if (userId == null) return;

                        if (post.isBookmarked) {
                          provider.unbookmarkPost(
                            userId: userId,
                            postId: post.id,
                          );
                        } else {
                          provider.bookmarkPost(
                            userId: userId,
                            postId: post.id,
                          );
                        }
                      },
                      onShare: () {
                        final deepLink =
                            'https://oasis-web-red.vercel.app/post/${post.id}';
                        Share.share('Check out this post on Oasis! $deepLink');
                      },
                    );
                  }, childCount: posts.length),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );

    // Apply UI Decay (Saturation and Blur)
    final filteredFeed = ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: wellbeing.blurSigma,
        sigmaY: wellbeing.blurSigma,
      ),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix([
          wellbeing.saturationFactor,
          0,
          0,
          0,
          0,
          0,
          wellbeing.saturationFactor,
          0,
          0,
          0,
          0,
          0,
          wellbeing.saturationFactor,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: feedContent,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          isDesktop
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: disableTransparency
                                ? colorScheme.surfaceContainer
                                : colorScheme.surface.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(
                              isM3E ? 28 : 12,
                            ),
                            border: isM3E
                                ? Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Column(
                            children: [
                              _buildDesktopHeader(colorScheme, isM3E),
                              const Divider(height: 1, thickness: 0.5),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(isM3E ? 28 : 12),
                                  ),
                                  child: disableTransparency
                                      ? MaxWidthContainer(
                                          maxWidth: 600,
                                          child: filteredFeed,
                                        )
                                      : BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 10,
                                            sigmaY: 10,
                                          ),
                                          child: MaxWidthContainer(
                                            maxWidth: 600,
                                            child: filteredFeed,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showCommentPane && _selectedPostId != null) ...[
                        const SizedBox(width: 12),
                        _buildDesktopCommentPane(theme, colorScheme, isM3E),
                      ],
                    ],
                  ),
                )
              : (ResponsiveLayout.isMobile(context)
                    ? filteredFeed
                    : MaxWidthContainer(
                        maxWidth: ResponsiveLayout.maxFeedWidth,
                        child: filteredFeed,
                      )),

          if (_showRipplesOverlay && isDesktop)
            Positioned.fill(
              child: motion.Animate(
                effects: const [motion.FadeEffect()],
                child: RipplesScreen(
                  onExit: () => setState(() => _showRipplesOverlay = false),
                ),
              ),
            ),

          const LockoutOverlay(pageName: 'Feed'),
        ],
      ),
    );
  }

  Widget _buildDesktopCommentPane(
    ThemeData theme,
    ColorScheme colorScheme, [
    bool isM3E = false,
  ]) {
    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: isM3E
            ? colorScheme.surfaceContainer
            : colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
        border: isM3E
            ? Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              )
            : Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                height: 80,
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _showCommentPane = false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CommentsModal(
                  postId: _selectedPostId!,
                  isSidePane: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(ColorScheme colorScheme, [bool isM3E = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTabSwitcher(colorScheme, isM3E),
        const SizedBox(width: 16),
        _buildRipplesButton(colorScheme, isM3E),
      ],
    );
  }

  Widget _buildDesktopHeader(ColorScheme colorScheme, [bool isM3E = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      height: 80,
      child: Row(
        children: [
          Text(
            'Feed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          _buildTabSwitcher(colorScheme),
          const SizedBox(width: 24),
          _buildRipplesButton(colorScheme),
          const SizedBox(width: 24),
          FeedLayoutSwitcher(
            currentLayout: _currentLayout,
            onLayoutChanged: (layout) =>
                setState(() => _currentLayout = layout),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(ColorScheme colorScheme, [bool isM3E = false]) {
    return PopupMenuButton<int>(
      onSelected: (index) => _tabController.animateTo(index),
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isM3E ? 16 : 20),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          child: Text(
            'FOLLOWING',
            style: TextStyle(
              fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
            ),
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Text(
            'EXPLORE',
            style: TextStyle(
              fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isM3E
              ? colorScheme.surfaceContainer
              : colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(isM3E ? 20 : 32),
          border: isM3E
              ? Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1,
                )
              : Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _tabController.index == 0 ? 'FOLLOWING' : 'EXPLORE',
              style: TextStyle(
                fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRipplesButton(ColorScheme colorScheme, [bool isM3E = false]) {
    return GestureDetector(
      onTap: () => _handleRipplesTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isM3E
              ? colorScheme.tertiaryContainer
              : colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isM3E ? 20 : 32),
          border: isM3E
              ? Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                )
              : Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.waves_rounded,
              size: 18,
              color: isM3E
                  ? colorScheme.onTertiaryContainer
                  : colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Ripples',
              style: TextStyle(
                color: isM3E
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.secondary,
                fontWeight: isM3E ? FontWeight.w600 : FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _loadFeed();
      setState(() {});
    }
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 10;
    if (scrolled != _isScrolled) {
      setState(() => _isScrolled = scrolled);
    }
  }
}


