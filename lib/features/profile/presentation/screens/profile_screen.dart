import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/post_service.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oasis/features/wellness/presentation/widgets/wellness_badge.dart';
import 'package:oasis/features/auth/presentation/widgets/account_switcher_sheet.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/widgets/desktop_header.dart';
import 'package:oasis/widgets/moderation_dialogs.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/features/wellness/presentation/widgets/session_dial.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final PostService _postService = PostService();
  late TabController _tabController;
  List<Post> _userPosts = [];
  final List<Post> _savedPosts = [];
  bool _isLoadingPosts = false;
  final ScrollController _scrollController = ScrollController();
  int _pivotIndex = 0;

  bool get isOwnProfile {
    final currentUserId = _authService.currentUser?.id;
    return widget.userId == null || widget.userId == currentUserId;
  }

  String get targetUserId =>
      widget.userId ?? _authService.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isOwnProfile ? 2 : 1, vsync: this);
    _loadProfile();
    _loadUserPosts();
  }

  void _loadProfile() {
    final currentUserId = _authService.currentUser?.id;
    final targetId = targetUserId;
    if (targetId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isOwnProfile) {
          context.read<ProfileProvider>().loadCurrentProfile(targetId);
        } else if (currentUserId != null) {
          context.read<ProfileProvider>().loadProfile(targetId, currentUserId);
          context.read<ProfileProvider>().checkFollowRequestStatus(
                followerId: currentUserId,
                followingId: targetId,
              );
        }
      });
    }
  }

  Future<void> _loadUserPosts() async {
    final currentUserId = _authService.currentUser?.id;
    final targetId = targetUserId;
    if (targetId.isEmpty) return;

    setState(() => _isLoadingPosts = true);

    try {
      final posts = await _postService.getUserPosts(
        userId: targetId,
        currentUserId: currentUserId ?? '',
      );
      if (mounted) {
        setState(() {
          _userPosts = posts;
          _isLoadingPosts = false;
        });

        // Load saved posts only for own profile
        if (isOwnProfile) {
          final savedPosts = await context
              .read<ProfileProvider>()
              .loadSavedPosts(targetId);
          setState(() {
            _savedPosts.clear();
            _savedPosts.addAll(savedPosts);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _handleMessage(String currentUserId, String targetId, UserProfileEntity? profile) async {
    try {
      final conversationId = await context
          .read<ProfileProvider>()
          .getOrCreateConversation(user1Id: currentUserId, user2Id: targetId);
      if (mounted) {
        context.push('/messages/$conversationId', extra: {
          'otherUserId': targetId,
          'otherUserName': profile?.username,
          'otherUserAvatar': profile?.avatarUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting conversation: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;
    final userId = _authService.currentUser?.id;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final useFluent = themeProvider.useFluentUI;

    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = isOwnProfile
            ? profileProvider.currentProfile
            : profileProvider.viewedProfile;

        if (profileProvider.isLoading && profile == null) {
          if (useFluent) {
            return const fluent.ScaffoldPage(
              content: Center(child: fluent.ProgressRing()),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profile not found')));
        }

        if (useFluent) {
          final isPrivateAndNotFollowing = !isOwnProfile && 
                                          profile.isPrivate && 
                                          !profileProvider.isFollowing;
          return Material(
            color: Colors.transparent,
            child: _buildFluentProfile(
              profile,
              themeProvider,
              colorScheme,
              profileProvider,
              userId,
              isPrivateAndNotFollowing,
            ),
          );
        }

        final isPrivateAndNotFollowing = !isOwnProfile && 
                                        profile.isPrivate && 
                                        !profileProvider.isFollowing;

        if (isDesktop) {
          return Material(
            type: MaterialType.transparency,
            child: _buildDesktopLayout(
              profile,
              theme,
              colorScheme,
              profileProvider,
              userId,
              isM3E,
              disableTransparency,
              isPrivateAndNotFollowing,
            ),
          );
        }

        return _buildMobileLayout(
          profile,
          theme,
          colorScheme,
          isM3E,
          disableTransparency,
          userId,
          isPrivateAndNotFollowing,
        );
      },
    );
  }

  Widget _buildFluentProfile(
    UserProfileEntity profile,
    ThemeProvider themeProvider,
    ColorScheme colorScheme,
    ProfileProvider profileProvider,
    String? userId,
    bool isPrivateAndNotFollowing,
  ) {
    return fluent.ScaffoldPage(
      header: fluent.PageHeader(
        title: fluent.HoverButton(
          onPressed: isOwnProfile ? () => AccountSwitcherSheet.show(context) : null,
          builder: (context, states) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.username,
                  style: fluent.FluentTheme.of(context).typography.title,
                ),
                if (isOwnProfile) ...[
                  const SizedBox(width: 8),
                  Icon(
                    fluent.FluentIcons.chevron_down,
                    size: 12,
                    color: states.contains(WidgetState.hovered) 
                      ? fluent.FluentTheme.of(context).accentColor 
                      : null,
                  ),
                ],
              ],
            );
          },
        ),
        commandBar: fluent.CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            if (isOwnProfile)
              fluent.CommandBarButton(
                icon: const Icon(fluent.FluentIcons.settings),
                label: const Text('Settings'),
                onPressed: () => context.push('/settings'),
              ),
            fluent.CommandBarButton(
              icon: const Icon(fluent.FluentIcons.share),
              label: const Text('Share'),
              onPressed: () {
                final shareText = isOwnProfile
                    ? 'Check out my profile on Oasis!'
                    : 'Check out ${profile.username} on Oasis!';
                final profileUrl = AppConfig.getWebUrl('/profile/${profile.id}');
                Share.share('$shareText\n$profileUrl');
              },
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Section
                  _buildFluentHeroHeader(profile, themeProvider, colorScheme, profileProvider, userId),
                  const SizedBox(height: 48),
                  
                  // Content Pivot
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildFluentTabItem('Posts', 0),
                          if (isOwnProfile) ...[
                            const SizedBox(width: 32),
                            _buildFluentTabItem('Saved', 1),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      const fluent.Divider(),
                      const SizedBox(height: 16),
                      if (isPrivateAndNotFollowing)
                        _buildPrivateAccountNotice(isFluent: true)
                      else
                        _pivotIndex == 0
                            ? _buildFluentPostsGrid(_userPosts, userId, themeProvider.isM3EEnabled)
                            : _buildFluentPostsGrid(_savedPosts, userId, themeProvider.isM3EEnabled),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateAccountNotice({bool isFluent = false}) {
    if (isFluent) {
      final theme = fluent.FluentTheme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(fluent.FluentIcons.lock, size: 48, color: theme.typography.body?.color?.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                'This account is private',
                style: theme.typography.subtitle?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow this account to see their posts',
                style: theme.typography.body?.copyWith(color: theme.typography.body?.color?.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'This account is private',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this account to see their posts',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFluentTabItem(String label, int index) {
    final isSelected = _pivotIndex == index;
    final theme = fluent.FluentTheme.of(context);
    
    return fluent.HoverButton(
      onPressed: () => setState(() => _pivotIndex = index),
      builder: (context, states) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text(
                label,
                style: theme.typography.body?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected 
                    ? theme.accentColor 
                    : theme.typography.body?.color?.withValues(alpha: 0.6),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: 40,
              decoration: BoxDecoration(
                color: isSelected ? theme.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFluentHeroHeader(
    UserProfileEntity profile,
    ThemeProvider themeProvider,
    ColorScheme colorScheme,
    ProfileProvider profileProvider,
    String? userId,
  ) {
    final isM3E = themeProvider.isM3EEnabled;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Large Avatar with Fluent Styling
        _buildFluentAvatar(profile, colorScheme, isM3E),
        const SizedBox(width: 48),
        
        // Profile Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName ?? profile.username,
                style: fluent.FluentTheme.of(context).typography.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: fluent.FluentTheme.of(context).typography.body?.copyWith(
                  color: fluent.FluentTheme.of(context).accentColor.lighter,
                ),
              ),
              const SizedBox(height: 16),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                Text(
                  profile.bio!,
                  style: fluent.FluentTheme.of(context).typography.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],
              
              // Stats
              Row(
                children: [
                  _buildFluentStatItem('${profile.postsCount}', 'posts'),
                  const SizedBox(width: 32),
                  _buildFluentStatItem(
                    '${profile.safeFollowersCount}',
                    'followers',
                    onTap: () => context.push('/profile/${profile.id}/followers'),
                  ),
                  const SizedBox(width: 32),
                  _buildFluentStatItem(
                    '${profile.followingCount}',
                    'following',
                    onTap: () => context.push('/profile/${profile.id}/following'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              _buildFluentActionButtons(
                profile,
                profileProvider,
                colorScheme,
                userId,
                isM3E,
              ),
            ],
          ),
        ),
        
        // Optional Wellness Summary on the right
        if (isOwnProfile) ...[
          const SizedBox(width: 48),
          _buildFluentWellnessSummary(profile),
        ],
      ],
    );
  }

  Widget _buildFluentAvatar(
    UserProfileEntity profile,
    ColorScheme colorScheme,
    bool isM3E,
  ) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isM3E ? BorderRadius.circular(32) : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: isM3E ? BorderRadius.circular(32) : BorderRadius.circular(90),
        child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: profile.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const fluent.ProgressRing(),
              )
            : Container(
                color: colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    profile.username[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFluentStatItem(String value, String label, {VoidCallback? onTap}) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        return Column(
          children: [
            Text(
              value,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
                color: states.contains(WidgetState.hovered) ? theme.accentColor : null,
              ),
            ),
            Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFluentActionButtons(
    UserProfileEntity profile,
    ProfileProvider profileProvider,
    ColorScheme colorScheme,
    String? currentUserId,
    bool isM3E,
  ) {
    if (isOwnProfile) {
      return fluent.Button(
        onPressed: () => context.push('/edit-profile'),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fluent.FluentIcons.edit, size: 16),
              SizedBox(width: 8),
              Text('Edit Profile'),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        fluent.FilledButton(
          onPressed: () {
            if (currentUserId != null) {
              if (profileProvider.isFollowing) {
                profileProvider.unfollowUser(followerId: currentUserId, followingId: profile.id);
              } else {
                profileProvider.followUser(followerId: currentUserId, followingId: profile.id);
              }
            }
          },
          style: fluent.ButtonStyle(
            backgroundColor: profileProvider.isFollowing
                ? fluent.WidgetStateProperty.all(fluent.FluentTheme.of(context).cardColor)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(profileProvider.isFollowing ? 'Following' : 'Follow'),
          ),
        ),
        const SizedBox(width: 12),
        if (currentUserId != null)
          fluent.Button(
            onPressed: () => _handleMessage(currentUserId, profile.id, profile),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Icon(fluent.FluentIcons.chat, size: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildFluentWellnessSummary(UserProfileEntity profile) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: fluent.FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fluent.FluentTheme.of(context).resources.dividerStrokeColorDefault),
      ),
      child: Column(
        children: [
          Text(
            'WELLNESS',
            style: fluent.FluentTheme.of(context).typography.caption?.copyWith(
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          WellnessBadge(xp: profile.safeXp),
          const SizedBox(height: 16),
          Text(
            'Level ${profile.level}',
            style: fluent.FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluentPostsGrid(List<Post> posts, String? userId, bool isM3E) {
    if (_isLoadingPosts) {
      return const Center(child: fluent.ProgressRing());
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(fluent.FluentIcons.photo_collection, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: fluent.FluentTheme.of(context).typography.body,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final borderRadius = isM3E ? BorderRadius.circular(16) : BorderRadius.circular(8);

        return fluent.HoverButton(
          onPressed: () => context.push('/post/${post.id}'),
          builder: (context, states) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: states.contains(WidgetState.hovered) ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: borderRadius,
                border: states.contains(WidgetState.hovered) 
                  ? Border.all(color: fluent.FluentTheme.of(context).accentColor, width: 2)
                  : null,
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: post.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Center(child: Icon(fluent.FluentIcons.text_document, size: 20)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    ProfileProvider profileProvider,
    String? userId,
    bool isM3E,
    bool disableTransparency,
    bool isPrivateAndNotFollowing,
  ) {
    final desktopBgColor = disableTransparency
        ? colorScheme.surface
        : colorScheme.surface.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: desktopBgColor,
          borderRadius: BorderRadius.circular(isM3E ? 32 : 12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isM3E ? 32 : 12),
          child: disableTransparency
              ? _buildDesktopContent(
                  profile,
                  theme,
                  colorScheme,
                  profileProvider,
                  userId,
                  isM3E,
                  disableTransparency,
                  isPrivateAndNotFollowing,
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: _buildDesktopContent(
                    profile,
                    theme,
                    colorScheme,
                    profileProvider,
                    userId,
                    isM3E,
                    disableTransparency,
                    isPrivateAndNotFollowing,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    ProfileProvider profileProvider,
    String? userId,
    bool isM3E,
    bool disableTransparency,
    bool isPrivateAndNotFollowing,
  ) {
    return Column(
      children: [
        DesktopHeader(
          title: profile.username,
          subtitle: profile.fullName ?? 'Oasis Member',
          showBackButton: true,
          onBack: () => context.pop(),
          actions: [
            if (isOwnProfile)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
                tooltip: 'Settings',
              ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Profile Info
              Container(
                width: 350,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.onSurface.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDesktopAvatar(profile, colorScheme, isM3E),
                      const SizedBox(height: 32),
                      _buildDesktopInfoSection(
                        profile,
                        theme,
                        colorScheme,
                        profileProvider,
                        userId,
                        isM3E,
                      ),
                      const SizedBox(height: 40),
                      _buildDesktopInfoCard(
                        profile,
                        theme,
                        colorScheme,
                        isM3E,
                        disableTransparency,
                      ),
                    ],
                  ),
                ),
              ),
              // Right Pane: Tabs & Grid
              Expanded(
                child: Column(
                  children: [
                    _buildTabBar(colorScheme),
                    const Divider(height: 1),
                    Expanded(
                      child: isPrivateAndNotFollowing
                          ? _buildPrivateAccountNotice()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildPostsTab(userId, true, isM3E),
                                if (isOwnProfile) _buildSavedTab(userId, true, isM3E),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopAvatar(
    UserProfileEntity profile,
    ColorScheme colorScheme,
    bool isM3E,
  ) {
    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(32) : null,
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
            ),
            child: ClipRRect(
              borderRadius: isM3E
                  ? BorderRadius.circular(28)
                  : BorderRadius.circular(60),
              child: Container(
                width: 120,
                height: 120,
                color: colorScheme.surface,
                child:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          profile.username[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (profile.isPro)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(isM3E ? 8 : 12),
                  border: Border.all(color: colorScheme.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Text(
                  'PRO MEMBER',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopInfoSection(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    ProfileProvider profileProvider,
    String? currentUserId,
    bool isM3E,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile.username,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDesktopActionButtons(
          profile,
          profileProvider,
          theme,
          colorScheme,
          currentUserId,
          isM3E,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDesktopStatItem('${profile.postsCount}', 'posts'),
            _buildDesktopStatItem(
              '${profile.safeFollowersCount}',
              'followers',
              onTap: () => context.push('/profile/${profile.id}/followers'),
            ),
            _buildDesktopStatItem(
              '${profile.followingCount}',
              'following',
              onTap: () => context.push('/profile/${profile.id}/following'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          profile.fullName ?? profile.username,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (profile.bio != null)
          Text(
            profile.bio!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        const SizedBox(height: 16),
        WellnessBadge(xp: profile.safeXp),
      ],
    );
  }

  Widget _buildMobileLayout(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isM3E,
    bool disableTransparency,
    String? userId,
    bool isPrivateAndNotFollowing,
  ) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildModernAppBar(
            profile,
            theme,
            colorScheme,
            false,
            isM3E,
            disableTransparency,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                children: [
                  _buildProfileHeader(profile, theme, colorScheme, isM3E),
                  const SizedBox(height: 32),
                  _buildStatsBar(
                    profile,
                    theme,
                    colorScheme,
                    isM3E,
                    disableTransparency,
                  ),
                  const SizedBox(height: 24),
                  _buildActionButtons(
                    profile,
                    context.read<ProfileProvider>(),
                    theme,
                    colorScheme,
                    userId,
                    isM3E,
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: ClipRRect(
                  child: disableTransparency
                      ? Container(
                          color: colorScheme.surface,
                          child: _buildTabBar(colorScheme),
                        )
                      : BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: colorScheme.surface.withValues(alpha: 0.7),
                            child: _buildTabBar(colorScheme),
                          ),
                        ),
                ),
              ),
              colorScheme.surface,
            ),
          ),
          SliverFillRemaining(
            child: isPrivateAndNotFollowing
                ? _buildPrivateAccountNotice()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsTab(userId, false, isM3E),
                      if (isOwnProfile) _buildSavedTab(userId, false, isM3E),
                    ],
                  ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme colorScheme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.4),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 3, color: colorScheme.primary),
            borderRadius: BorderRadius.circular(3),
          ),
          tabs: [
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('POSTS'),
                ],
              ),
            ),
            if (isOwnProfile)
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('SAVED'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStatItem(
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopActionButtons(
    UserProfileEntity profile,
    ProfileProvider profileProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    String? currentUserId,
    bool isM3E,
  ) {
    final radius = isM3E ? 16.0 : 10.0;
    if (isOwnProfile) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => context.push('/edit-profile'),
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Edit Profile'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {
              if (currentUserId != null) {
                if (profileProvider.isFollowing) {
                  profileProvider.unfollowUser(
                    followerId: currentUserId,
                    followingId: profile.id,
                  );
                } else {
                  profileProvider.followUser(
                    followerId: currentUserId,
                    followingId: profile.id,
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: profileProvider.isFollowing
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.primary,
              foregroundColor: profileProvider.isFollowing
                  ? colorScheme.onSurface
                  : colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: Text(
              profileProvider.isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (currentUserId != null) ...[
          IconButton.filledTonal(
            onPressed: () => _handleMessage(currentUserId, profile.id, profile),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton.filledTonal(
          onPressed: () {
            final shareText = isOwnProfile
                ? 'Check out my profile on Oasis!'
                : 'Check out ${profile.username} on Oasis!';
            final profileUrl = AppConfig.getWebUrl('/profile/${profile.id}');
            Share.share('$shareText\n$profileUrl');
          },
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopInfoCard(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isM3E,
    bool disableTransparency,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: disableTransparency
            ? colorScheme.surfaceContainerLow
            : colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(isM3E ? 24 : 12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMUNITY STATUS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.calendar_today_outlined, 'Joined March 2024'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.verified_user_outlined, 'Identity Verified'),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.favorite_outline_rounded, 'Top 5% Contributor'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildProfileHeader(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isM3E,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isM3E ? BorderRadius.circular(24) : null,
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.tertiary],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: isM3E
                        ? BorderRadius.circular(21)
                        : BorderRadius.circular(45),
                    child: Container(
                      width: 90,
                      height: 90,
                      color: colorScheme.surface,
                      child:
                          profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profile.avatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                profile.username[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                    ),
                  ),
                ),
                if (profile.isPro)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(isM3E ? 8 : 12),
                        border: Border.all(color: colorScheme.surface, width: 2),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName ?? profile.username,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${profile.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  WellnessBadge(xp: profile.safeXp),
                ],
              ),
            ),
          ],
        ),
        if (isOwnProfile) ...[
          const SizedBox(height: 40),
          // Wellness Dashboard Dial
          Consumer<ScreenTimeService>(
            builder: (context, screenTime, _) {
              return FutureBuilder<Duration>(
                future: screenTime.getTodayTotalUsage(),
                builder: (context, snapshot) {
                  final usage = snapshot.data ?? Duration.zero;
                  final settings = context.read<UserSettingsProvider>();
                  final dailyLimit = settings.dailyLimitMinutes > 0 ? settings.dailyLimitMinutes : 60;
                  final progress = (usage.inMinutes / dailyLimit).clamp(0.0, 1.0);
                  
                  return SessionDial(
                    progress: progress,
                    label: '${usage.inMinutes}m',
                    subLabel: 'TODAY\'S FLOW',
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStatsBar(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isM3E,
    bool disableTransparency,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: disableTransparency
            ? colorScheme.surfaceContainerHighest
            : colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isM3E ? 24 : 12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Posts', '${profile.postsCount}', theme),
          _buildStatDivider(colorScheme),
          GestureDetector(
            onTap: () => context.push('/profile/${profile.id}/followers'),
            child: _buildStatItem(
              'Followers',
              '${profile.safeFollowersCount}',
              theme,
            ),
          ),
          _buildStatDivider(colorScheme),
          GestureDetector(
            onTap: () => context.push('/profile/${profile.id}/following'),
            child: _buildStatItem(
              'Following',
              '${profile.followingCount}',
              theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(ColorScheme colorScheme) {
    return Container(
      height: 24,
      width: 1,
      color: colorScheme.onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _buildActionButtons(
    UserProfileEntity profile,
    ProfileProvider profileProvider,
    ThemeData theme,
    ColorScheme colorScheme,
    String? currentUserId,
    bool isM3E,
  ) {
    final radius = isM3E ? 24.0 : 18.0;
    return Row(
      children: [
        Expanded(
          child: isOwnProfile
              ? FilledButton.icon(
                  onPressed: () => context.push('/edit-profile'),
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('Edit Profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                )
              : profileProvider.isFollowing
                    ? OutlinedButton(
                        onPressed: () {
                          if (currentUserId != null) {
                            profileProvider.unfollowUser(
                              followerId: currentUserId,
                              followingId: profile.id,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                        child: const Text('Following'),
                      )
                    : profileProvider.state.hasSentRequest
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                        child: const Text('Requested'),
                      )
                    : FilledButton(
                        onPressed: () {
                          if (currentUserId != null) {
                            profileProvider.followUser(
                              followerId: currentUserId,
                              followingId: profile.id,
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                        child: const Text('Follow'),
                      ),
        ),
        const SizedBox(width: 12),
        if (!isOwnProfile && currentUserId != null) ...[
          IconButton.filledTonal(
            onPressed: () => _handleMessage(currentUserId, profile.id, profile),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        IconButton.filledTonal(
          onPressed: () {
            final shareText = isOwnProfile
                ? 'Check out my profile on Oasis!'
                : 'Check out ${profile.username} on Oasis!';
            final profileUrl = AppConfig.getWebUrl('/profile/${profile.id}');
            Share.share('$shareText\n$profileUrl');
          },
          icon: const Icon(Icons.ios_share_rounded),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab(String? userId, bool isDesktop, bool isM3E) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 20 : 2),
          sliver: _buildPostsGrid(_userPosts, userId, isDesktop, isM3E),
        ),
      ],
    );
  }

  Widget _buildSavedTab(String? userId, bool isDesktop, bool isM3E) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 20 : 2),
          sliver: _buildPostsGrid(_savedPosts, userId, isDesktop, isM3E),
        ),
      ],
    );
  }

  Widget _buildModernAppBar(
    UserProfileEntity profile,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isM3E,
    bool disableTransparency,
  ) {
    final appBarBgColor = disableTransparency
        ? theme.colorScheme.surface
        : theme.colorScheme.surface.withValues(alpha: 0.4);

    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: !isDesktop,
      title: InkWell(
        onTap: isOwnProfile ? () => AccountSwitcherSheet.show(context) : null,
        borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
          child: disableTransparency
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: appBarBgColor,
                  child: _buildAppBarTitle(profile, colorScheme),
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: appBarBgColor,
                    child: _buildAppBarTitle(profile, colorScheme),
                  ),
                ),
        ),
      ),
      actions: [
        if (!isDesktop && isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => context.push('/settings'),
            ),
          ),
        if (!isDesktop && !isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.flag_outlined,
                            color: Colors.red,
                          ),
                          title: const Text(
                            'Report Profile',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ReportDialog.show(context, userId: widget.userId);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAppBarTitle(UserProfileEntity profile, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          profile.username,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        if (isOwnProfile) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ],
      ],
    );
  }

  Widget _buildPostsGrid(
    List<Post> posts,
    String? userId,
    bool isDesktop,
    bool isM3E,
  ) {
    if (_isLoadingPosts) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_off_rounded,
                size: 48,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 3,
        crossAxisSpacing: isDesktop ? 12 : 2,
        mainAxisSpacing: isDesktop ? 12 : 2,
        childAspectRatio: 1.0,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = posts[index];
        final borderRadius = isM3E
            ? BorderRadius.circular(16)
            : (isDesktop ? BorderRadius.circular(12) : BorderRadius.zero);

        return GestureDetector(
          onTap: () => context.push('/post/${post.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: borderRadius,
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: post.imageUrl != null
                  ? Hero(
                      tag: 'post_${post.id}',
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(child: Icon(Icons.text_fields, size: 20)),
            ),
          ),
        );
      }, childCount: posts.length),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._widget, this.backgroundColor);

  final PreferredSizeWidget _widget;
  final Color backgroundColor;

  @override
  double get minExtent => _widget.preferredSize.height;
  @override
  double get maxExtent => _widget.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.transparent, child: _widget);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
