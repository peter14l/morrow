import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/widgets/wellbeing/lockout_overlay.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oasis/features/ripples/presentation/screens/ripples_screen.dart';
import 'package:oasis/widgets/comments_modal.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/models/feed_layout_strategy.dart';
import 'package:oasis/features/feed/presentation/widgets/layouts/classic_feed_layout.dart';
import 'package:oasis/features/feed/presentation/widgets/layouts/focused_flow_layout.dart';
import 'package:oasis/features/feed/presentation/widgets/layouts/spatial_glider_layout.dart';
import 'package:oasis/features/feed/presentation/widgets/layouts/living_canvas_layout.dart';

import 'package:oasis/widgets/wellbeing/grayscale_detox.dart';

import 'package:oasis/widgets/glassmorphic_fab.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:oasis/features/monetization/data/services/privacy_ad_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  Timer? _wellbeingTimer;
  bool _showWellbeingNudge = false;
  bool _showRipplesOverlay = false;

  // Desktop Comment Pane State
  String? _selectedPostId;
  bool _showCommentPane = false;

  // Cached service references for safe cleanup in dispose()
  DigitalWellbeingService? _wellbeingService;
  UserSettingsProvider? _settingsProvider;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);

    // Load initial feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFeed();
      _loadStories();
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        context.read<ProfileProvider>().loadFollowing(userId);
        context.read<RipplesProvider>().initForUser(userId);
      }
      _startWellbeingPolling();
      if (mounted) {
        _wellbeingService = context.read<DigitalWellbeingService>();
        _wellbeingService?.startTracking('feed');
        context.read<PrivacyAdService>().fetchAdCatalog();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache settings provider for async callbacks
    _settingsProvider = context.read<UserSettingsProvider>();
  }

  void _startWellbeingPolling() {
    _wellbeingTimer?.cancel();
    _wellbeingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkWellbeingLimit();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wellbeingTimer?.cancel();
      _wellbeingTimer = null;
      debugPrint('FeedScreen: Wellbeing polling paused (background)');
    } else if (state == AppLifecycleState.resumed) {
      _startWellbeingPolling();
      debugPrint('FeedScreen: Wellbeing polling resumed');
    }
  }

  Future<void> _checkWellbeingLimit() async {
    if (!mounted) return;
    final settings = _settingsProvider;
    if (settings == null || settings.dailyLimitMinutes <= 0) return;

    try {
      final screenTimeService = context.read<ScreenTimeService>();
      final todayUsage = await screenTimeService.getTodayTotalUsage();
      final usageMinutes = todayUsage.inMinutes;

      if (usageMinutes >= settings.dailyLimitMinutes && !_showWellbeingNudge) {
        if (mounted) {
          setState(() => _showWellbeingNudge = true);
        }
      }
    } catch (e) {
      debugPrint('Error checking wellbeing limit: $e');
    }
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        final feedProvider = context.read<FeedProvider>();
        if (!feedProvider.isLoadingMore && feedProvider.hasMore) {
          feedProvider.loadMore(userId: userId);
        }
      }
    }
  }

  void _loadFeed() {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    context.read<FeedProvider>().loadFeed(userId: userId);
  }

  void _loadStories() async {
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      final provider = context.read<StoriesProvider>();
      provider.loadFollowingStories();
      provider.loadMyStories();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [15, 30, 45].map((mins) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ChoiceChip(
                      label: Text('$mins min'),
                      selected: false,
                      onSelected: (_) {
                        service.startSession(Duration(minutes: mins));
                        Navigator.pop(context);
                        if (ResponsiveLayout.isDesktop(context)) {
                          setState(() => _showRipplesOverlay = true);
                        } else {
                          context.push('/ripples');
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
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
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
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

  void _showLayoutSwitcher(BuildContext context) {
    final settings = context.read<UserSettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final isSolid = context.shouldUseSolidBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    context.showResponsiveSheet(
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: isSolid
              ? (isDark ? const Color(0xFF1A1D24) : Colors.white)
              : colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Feed Layout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ...FeedLayoutType.values.map((type) {
              final isSelected = settings.feedLayout == type;
              return ListTile(
                leading: Icon(
                  type.icon,
                  color: isSelected ? colorScheme.primary : null,
                ),
                title: Text(
                  type.displayName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : null,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: colorScheme.primary)
                    : null,
                onTap: () {
                  settings.setFeedLayout(type);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
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
    final settings = context.watch<UserSettingsProvider>();
    final useFluent = themeProvider.useFluentUI;

    Widget layout;
    switch (settings.feedLayout) {
      case FeedLayoutType.classic:
        layout = ClassicFeedLayout(
          scrollController: _scrollController,
          onRefresh: _refreshFeed,
          isDesktop: isDesktop,
          isScrolled: _isScrolled,
          mobileHeader: _buildMobileHeader(colorScheme, isM3E),
          buildPostItem: _buildPostItem,
        );
        break;
      case FeedLayoutType.focused:
        layout = FocusedFlowLayout(
          onRefresh: _refreshFeed,
          mobileHeader: _buildMobileHeader(colorScheme, isM3E),
          buildPostItem: _buildPostItem,
        );
        break;
      case FeedLayoutType.spatial:
        layout = SpatialGliderLayout(
          onRefresh: _refreshFeed,
          mobileHeader: _buildMobileHeader(colorScheme, isM3E),
          buildPostItem: _buildPostItem,
        );
        break;
      case FeedLayoutType.canvas:
        layout = LivingCanvasLayout(
          onRefresh: _refreshFeed,
          mobileHeader: _buildMobileHeader(colorScheme, isM3E),
          buildPostItem: _buildPostItem,
        );
        break;
      case FeedLayoutType.standard:
      case FeedLayoutType.zenCarousel:
      case FeedLayoutType.pulseMap:
        layout = ClassicFeedLayout(
          scrollController: _scrollController,
          onRefresh: _refreshFeed,
          isDesktop: isDesktop,
          isScrolled: _isScrolled,
          mobileHeader: _buildMobileHeader(colorScheme, isM3E),
          buildPostItem: _buildPostItem,
        );
        break;
    }

    final feedContent = layout;

    final actions = [
      if (useFluent) ...[
        const SizedBox(width: 12),
        fluent.Tooltip(
          message: 'Change Layout',
          child: fluent.IconButton(
            icon: Icon(settings.feedLayout.icon, size: 20),
            onPressed: () => _showLayoutSwitcher(context),
          ),
        ),
      ] else ...[
        IconButton(
          icon: Icon(settings.feedLayout.icon),
          onPressed: () => _showLayoutSwitcher(context),
          tooltip: 'Change Layout',
        ),
      ],
      const SizedBox(width: 12),
      _buildRipplesButton(colorScheme, isM3E),
    ];

    return GrayscaleDetox(
      child: AdaptiveScaffold(
        title: isDesktop ? const Text('Feed') : null,
        actions: isDesktop ? actions : null,
        body: Stack(
          children: [
            isDesktop
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(child: feedContent),
                        const SizedBox(width: 12),
                        _showCommentPane && _selectedPostId != null
                            ? _buildDesktopCommentPane(
                                theme,
                                colorScheme,
                                isM3E,
                              )
                            : _buildDesktopSidebar(theme, colorScheme, isM3E),
                      ],
                    ),
                  )
                : feedContent,
            if (_showRipplesOverlay)
              Positioned.fill(
                child: motion.Animate(
                  effects: const [motion.FadeEffect()],
                  child: RipplesScreen(
                    onExit: () => setState(() => _showRipplesOverlay = false),
                  ),
                ),
              ),
            const LockoutOverlay(pageName: 'Feed'),
            if (_showWellbeingNudge) _buildWellbeingNudge(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostItem(
    dynamic post,
    FeedProvider provider,
    bool isDesktopPadding,
  ) {
    return PostCard(
      post: post,
      showInteractionButtons: false,
      onLike: () async {
        final userId = _authService.currentUser?.id;
        if (userId == null) return;

        if (post.isLiked) {
          provider.unlikePost(userId: userId, postId: post.id);
        } else {
          try {
            await provider.likePost(userId: userId, postId: post.id);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to like post: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      },
      onComment: () {
        if (ResponsiveLayout.isDesktop(context)) {
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
          provider.unbookmarkPost(userId: userId, postId: post.id);
        } else {
          provider.bookmarkPost(userId: userId, postId: post.id);
        }
      },
      onShare: () {
        final deepLink = AppConfig.getWebUrl('/post/${post.id}');
        Share.share('Check out this post on Oasis! $deepLink');
      },
      onVote: (optionId) async {
        final userId = _authService.currentUser?.id;
        if (userId == null) return;

        try {
          await provider.voteInPoll(
            userId: userId,
            postId: post.id,
            pollId: post.poll!.id,
            optionId: optionId,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to vote: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildDesktopCommentPane(
    ThemeData theme,
    ColorScheme colorScheme, [
    bool isM3E = false,
  ]) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;

    if (useFluent) {
      return Container(
        width: 450,
        padding: const EdgeInsets.only(right: 12, bottom: 12, top: 12),
        child: fluent.Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              fluent.CommandBar(
                primaryItems: [
                  fluent.CommandBarBuilderItem(
                    builder: (context, mode, child) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Comments',
                        style: fluent.FluentTheme.of(
                          context,
                        ).typography.subtitle,
                      ),
                    ),
                    wrappedItem: fluent.CommandBarButton(
                      onPressed: () {},
                      icon: const SizedBox.shrink(),
                    ),
                  ),
                ],
                secondaryItems: [
                  fluent.CommandBarButton(
                    icon: const Icon(fluent.FluentIcons.clear),
                    onPressed: () => setState(() => _showCommentPane = false),
                  ),
                ],
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
      );
    }

    final disableTransparency = context.read<ThemeProvider>().isM3ETransparencyDisabled;

    final content = Column(
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
                icon: const Icon(Icons.close),
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
    );

    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: isM3E
            ? colorScheme.surfaceContainer
            : disableTransparency
                ? colorScheme.surface
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
        child: disableTransparency
            ? content
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: content,
              ),
      ),
    );
  }

  Widget _buildMobileHeader(ColorScheme colorScheme, [bool isM3E = false]) {
    final settings = context.watch<UserSettingsProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final unreadCount = notificationProvider.state.unreadCount;
    final avatarUrl = profileProvider.currentProfile?.avatarUrl;

    return Row(
      children: [
        IconButton(
          icon: Icon(settings.feedLayout.icon, size: 24),
          onPressed: () => _showLayoutSwitcher(context),
          tooltip: 'Change Layout',
        ),
        const Spacer(),
        _buildRipplesButton(colorScheme, isM3E),
        const SizedBox(width: 12),
        // Search FAB
        GlassmorphicFAB(
          size: 40,
          onPressed: () => context.pushNamed('search'),
          child: Icon(
            FluentIcons.search_24_regular,
            size: 20,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        // Notifications FAB
        Badge(
          isLabelVisible: unreadCount > 0,
          label: Text(
            unreadCount.toString(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          child: GlassmorphicFAB(
            size: 40,
            onPressed: () => context.pushNamed('notifications'),
            child: Icon(
              FluentIcons.alert_24_regular,
              size: 20,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Profile FAB
        GlassmorphicFAB(
          size: 40,
          onPressed: () => context.pushNamed('profile'),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer.withValues(
              alpha: 0.5,
            ),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Icon(
                    FluentIcons.person_24_regular,
                    size: 20,
                    color: colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRipplesButton(ColorScheme colorScheme, [bool isM3E = false]) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;

    if (useFluent) {
      return fluent.Button(
        onPressed: () => _handleRipplesTap(context),
        child: const Text('Ripples'),
      );
    }

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

  Widget _buildDesktopSidebar(
    ThemeData theme,
    ColorScheme colorScheme, [
    bool isM3E = false,
  ]) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;

    if (useFluent) {
      return Container(
        width: 400,
        padding: const EdgeInsets.only(right: 12, bottom: 12, top: 12),
        child: fluent.Card(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Row(
                children: [
                  Icon(
                    fluent.FluentIcons.trending12,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'TRENDING',
                    style: fluent.FluentTheme.of(context).typography.caption
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTrendingItem('#OasisApp', '2.4k posts'),
              _buildTrendingItem('#OasisV2', '1.8k posts'),
              _buildTrendingItem('#FlutterDesktop', '942 posts'),
              _buildTrendingItem('#CyberDesign', '621 posts'),
              const SizedBox(height: 48),
              Row(
                children: [
                  Icon(
                    fluent.FluentIcons.add_friend,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SUGGESTED',
                    style: fluent.FluentTheme.of(context).typography.caption
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSuggestionItem(
                'suggested_1',
                'DesignDaily',
                '@designdaily',
              ),
              _buildSuggestionItem('suggested_2', 'TechNexus', '@technexus'),
              _buildSuggestionItem('suggested_3', 'CreativeSoul', '@creative'),
              _buildSuggestionItem('suggested_4', 'FutureVibe', '@future'),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 400,
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
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isM3E ? 28 : 12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'TRENDING',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTrendingItem('#OasisApp', '2.4k posts'),
              _buildTrendingItem('#OasisV2', '1.8k posts'),
              _buildTrendingItem('#FlutterDesktop', '942 posts'),
              _buildTrendingItem('#CyberDesign', '621 posts'),
              const SizedBox(height: 48),
              Row(
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SUGGESTED',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSuggestionItem(
                'suggested_1',
                'DesignDaily',
                '@designdaily',
              ),
              _buildSuggestionItem('suggested_2', 'TechNexus', '@technexus'),
              _buildSuggestionItem('suggested_3', 'CreativeSoul', '@creative'),
              _buildSuggestionItem('suggested_4', 'FutureVibe', '@future'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingItem(String tag, String count) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: useFluent
                ? fluent.FluentTheme.of(context).typography.bodyStrong
                : const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            count,
            style: useFluent
                ? fluent.FluentTheme.of(context).typography.caption
                : TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String id, String name, String handle) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (useFluent)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                color: fluent.FluentTheme.of(
                  context,
                ).accentColor.withValues(alpha: 0.1),
                child: Center(
                  child: Text(
                    name[0],
                    style: fluent.FluentTheme.of(context).typography.body,
                  ),
                ),
              ),
            )
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(name[0], style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: useFluent
                      ? fluent.FluentTheme.of(context).typography.bodyStrong
                      : const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                ),
                Text(
                  handle,
                  style: useFluent
                      ? fluent.FluentTheme.of(context).typography.caption
                      : TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                ),
              ],
            ),
          ),
          Consumer<ProfileProvider>(
            builder: (context, profileProvider, child) {
              final isFollowing = profileProvider.state.following.any(
                (p) => p.id == id,
              );

              if (isFollowing) {
                return useFluent
                    ? const fluent.HyperlinkButton(
                        onPressed: null,
                        child: Text('Following'),
                      )
                    : const Text(
                        'Following',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
              }

              return useFluent
                  ? fluent.Button(
                      onPressed: () => _handleFollow(id),
                      child: const Text('Follow'),
                    )
                  : TextButton(
                      onPressed: () => _handleFollow(id),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Follow'),
                    );
            },
          ),
        ],
      ),
    );
  }

  void _handleFollow(String userId) {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId != null) {
      context.read<ProfileProvider>().followUser(
        followerId: currentUserId,
        followingId: userId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Following $userId'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildWellbeingNudge() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.read<UserSettingsProvider>();

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: motion.Animate(
              effects: const [motion.FadeEffect(), motion.ScaleEffect()],
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.spa_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Time for a breather?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You\'ve been on Oasis for ${settings.dailyLimitMinutes} minutes today.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() => _showWellbeingNudge = false);
                          context.go('/spaces/circles');
                        },
                        child: const Text('CHECK ON YOUR CIRCLES'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showWellbeingNudge = false),
                      child: const Text(
                        'Stay for 5 more minutes',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
