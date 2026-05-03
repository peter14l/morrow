// app_router.dart

import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:navigation_bar_m3e/navigation_bar_m3e.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/screens/spaces/spaces_screen.dart';
import 'package:oasis/services/app_analytics.dart';
import 'package:oasis/themes/app_colors.dart';

import 'package:oasis/features/circles/presentation/screens/circle_detail_screen.dart';
import 'package:oasis/features/circles/presentation/screens/create_circle_screen.dart';
import 'package:oasis/features/circles/presentation/screens/create_commitment_screen.dart';

import 'package:oasis/features/canvas/presentation/screens/timeline_canvas_screen.dart';
import 'package:oasis/features/canvas/presentation/screens/create_canvas_screen.dart';

import 'package:oasis/features/messages/presentation/screens/direct_messages_screen.dart'
    as messages;
import 'package:oasis/features/messages/presentation/screens/chat_screen.dart';
import 'package:oasis/features/messages/presentation/screens/new_message_screen.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/security_upgrade_banner.dart';
import 'package:oasis/widgets/security_pin_sheet.dart';
import 'package:oasis/features/calling/presentation/screens/calling_screen.dart';
import 'package:oasis/features/calling/domain/models/call_entity.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:oasis/screens/settings_screen.dart';
import 'package:oasis/features/settings/presentation/screens/subscription_screen.dart';
import 'package:oasis/features/settings/presentation/screens/account_privacy_screen.dart';
import 'package:oasis/features/settings/presentation/screens/two_factor_auth_screen.dart';
import 'package:oasis/features/settings/presentation/screens/download_data_screen.dart';
import 'package:oasis/features/settings/presentation/screens/storage_usage_screen.dart';
import 'package:oasis/features/settings/presentation/screens/font_size_screen.dart';
import 'package:oasis/features/settings/presentation/screens/help_support_screen.dart';
import 'package:oasis/features/settings/presentation/screens/about_app_screen.dart';
import 'package:oasis/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:oasis/features/settings/presentation/screens/update_settings_screen.dart';
import 'package:oasis/features/profile/presentation/screens/account_management_screen.dart';
import 'package:oasis/screens/moderation/moderation_screens.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/stories/presentation/screens/story_view_screen.dart'
    as new_story_view;
import 'package:oasis/features/stories/presentation/screens/create_story_screen.dart'
    as new_create_story;
import '../features/auth/presentation/screens/login_screen.dart'
    as login_screen;
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/feed/presentation/screens/feed_screen.dart';
import '../screens/search_screen.dart';
import '../features/feed/presentation/screens/create_post_screen.dart';
import '../features/feed/presentation/screens/comments_screen.dart';
import 'package:oasis/features/feed/presentation/screens/post_details_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/followers_screen.dart';
import '../screens/legal/privacy_policy_screen.dart';
import '../screens/legal/terms_of_service_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/onboarding/onboarding_shell.dart';
import '../features/capsules/presentation/screens/create_capsule_screen.dart';
import '../features/capsules/presentation/screens/capsule_view_screen.dart';
import '../features/circles/presentation/screens/circle_join_screen.dart';
import 'package:oasis/features/ripples/presentation/screens/ripples_screen.dart';
import 'package:oasis/features/ripples/presentation/screens/create_ripple_screen.dart';
import '../screens/oasis_pro_screen.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:flutter_animate/flutter_animate.dart' as motion;

import 'package:oasis/features/wellness/presentation/screens/wellness_center_screen.dart';
import 'package:oasis/features/settings/presentation/screens/changelog_screen.dart';
import 'package:oasis/features/auth/presentation/widgets/account_switcher_sheet.dart';
import 'package:oasis/features/settings/presentation/screens/wellness_stats_screen.dart';

class UnreadMessagesBadge extends StatelessWidget {
  final Widget child;
  final bool isSelected;

  const UnreadMessagesBadge({
    super.key,
    required this.child,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(context).useFluentUI;

    return Consumer<ConversationProvider>(
      builder: (context, provider, _) {
        final count = provider.totalUnreadCount;
        if (useFluent) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: fluent.InfoBadge(
                    source: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        }
        return Badge(
          isLabelVisible: count > 0,
          label: Text(count.toString()),
          child: child,
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  /// Routes that are locked when the collaboration kill-switch or focus mode is active.
  static const _restrictedRoutes = {'/feed', '/search'};
  bool _isRailExtended = false;
  bool _isPrivacyBlurActive = false;
  EncryptionStatus? _encryptionStatus;

  // Panel state for Desktop
  String? _activePanel; // 'search', 'notifications', or null
  final fluent.FlyoutController _fluentCreateFlyoutController = fluent.FlyoutController();

  @override
  void initState() {
    super.initState();
    _checkEncryption();
  }

  @override
  void dispose() {
    _fluentCreateFlyoutController.dispose();
    super.dispose();
  }

  Future<void> _checkEncryption() async {
    final encryption = context.read<EncryptionService>();
    final status = await encryption.init();

    if (mounted) {
      setState(() {
        _encryptionStatus = status;
      });

      if (status == EncryptionStatus.needsRestore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SecurityPinSheet.show(context, status).then((success) {
              if (success == true) {
                _checkEncryption(); // Re-check to clear banner
              }
            });
          }
        });
      }
    }
  }

  int _getCurrentIndex() {
    final location = GoRouterState.of(context).uri.path;
    final screenTimeService = context.read<ScreenTimeService>();

    if (location.startsWith('/feed')) {
      screenTimeService.setCurrentCategory('Feed');
      return 0;
    }
    if (location.startsWith('/search')) {
      screenTimeService.setCurrentCategory('Feed'); // Search is discovery
      return 1;
    }
    if (location.startsWith('/spaces') ||
        location.startsWith('/circles') ||
        location.startsWith('/communities')) {
      screenTimeService.setCurrentCategory('Communities');
      return 2;
    }
    if (location.startsWith('/messages')) {
      screenTimeService.setCurrentCategory('Messages');
      return 3;
    }
    if (location.startsWith('/notifications')) {
      screenTimeService.setCurrentCategory(null);
      return 4;
    }
    if (location.startsWith('/profile')) {
      screenTimeService.setCurrentCategory('Profile');
      return 5;
    }
    return 0;
  }

  Widget _buildMainContentWithPanels({
    required Widget mainContent,
    required bool isDesktop,
    required String? activePanel,
    required Color slidingPanelColor,
  }) {
    return Stack(
      children: [
        mainContent,
        if (isDesktop && activePanel != null) ...[
          // Backdrop to close panel
          GestureDetector(
            onTap: () => setState(() => _activePanel = null),
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.black.withValues(alpha: 0.01),
            ),
          ),
          // Sliding panel
          motion.Animate(
            effects: const [
              motion.SlideEffect(
                begin: Offset(-1, 0),
                end: Offset(0, 0),
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              motion.FadeEffect(duration: Duration(milliseconds: 300)),
            ],
            child: Container(
              width: 400,
              decoration: BoxDecoration(
                color: slidingPanelColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child:
                  activePanel == 'search'
                      ? const SearchScreen(isPanel: true)
                      : const NotificationsScreen(isPanel: true),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency =
        isM3E && themeProvider.isM3ETransparencyDisabled;
    final currentIndex = _getCurrentIndex();
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Consumer3<ScreenTimeService, WellnessService, UserSettingsProvider>(
      builder: (context, svc, wellness, userSettings, _) {
        final useFluent = themeProvider.useFluentUI;
        final killSwitchActive = wellness.zenModeEnabled;
        final isMica = userSettings.micaEnabled && Platform.isWindows;

        final panelColor =
            isMica
                ? Colors.black.withValues(alpha: 0.1)
                : (isM3E
                    ? theme.colorScheme.surfaceContainer
                    : const Color(0xFF0C0F14).withValues(alpha: 0.8));

        final slidingPanelColor =
            isMica
                ? Colors.black.withValues(alpha: 0.8)
                : (isM3E
                    ? theme.colorScheme.surfaceContainerHigh
                    : const Color(0xFF0C0F14));

        if (killSwitchActive) {
          final location = GoRouterState.of(context).uri.path;
          final isRestricted = _restrictedRoutes.any(
            (r) => location.startsWith(r),
          );
          if (isRestricted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/messages');
            });
          }
        }

        Widget mainContent = widget.child;
        final contentWithPanels = _buildMainContentWithPanels(
          mainContent: mainContent,
          isDesktop: isDesktop,
          activePanel: _activePanel,
          slidingPanelColor: slidingPanelColor,
        );

        if (useFluent && isDesktop) {
          return fluent.NavigationView(
            pane: fluent.NavigationPane(
              header: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: _buildFluentCreateButton(context),
              ),
              selected: currentIndex,
              size: const fluent.NavigationPaneSize(
                compactWidth: 54,
              ),
              onChanged:
                  (index) => _onDestinationSelected(
                    index,
                    killSwitchActive: killSwitchActive,
                  ),
              displayMode:
                  _isRailExtended
                      ? fluent.PaneDisplayMode.expanded
                      : fluent.PaneDisplayMode.compact,
              items: [
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.home_24_regular),
                  title: const Text('Feed'),
                  body: contentWithPanels,
                ),
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.search_24_regular),
                  title: const Text('Search'),
                  body: contentWithPanels,
                ),
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.channel_24_regular),
                  title: const Text('Spaces'),
                  body: contentWithPanels,
                ),
                fluent.PaneItem(
                  icon: UnreadMessagesBadge(
                    child: const Icon(FluentIcons.chat_24_regular),
                  ),
                  title: const Text('Messages'),
                  body: contentWithPanels,
                ),
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.alert_24_regular),
                  title: const Text('Notifications'),
                  body: contentWithPanels,
                ),
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.person_24_regular),
                  title: const Text('Profile'),
                  body: contentWithPanels,
                ),
              ],
              footerItems: [
                fluent.PaneItemSeparator(),
                fluent.PaneItem(
                  icon: const Icon(FluentIcons.settings_24_regular),
                  title: const Text('Settings'),
                  body: contentWithPanels,
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          extendBody: true,
          body: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _TwoFingerLongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                _TwoFingerLongPressGestureRecognizer
              >(
                () => _TwoFingerLongPressGestureRecognizer(
                  onTwoFingerLongPress: () {
                    setState(
                      () => _isPrivacyBlurActive = !_isPrivacyBlurActive,
                    );
                    if (_isPrivacyBlurActive) {
                      HapticFeedback.heavyImpact();
                    } else {
                      HapticFeedback.mediumImpact();
                    }
                  },
                ),
                (instance) {},
              ),
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    if (_encryptionStatus == EncryptionStatus.needsRestore)
                      const SecurityUpgradeBanner(),
                    Expanded(
                      child: Row(
                        children: [
                          if (isDesktop)
                            _buildNavigationRail(
                              context,
                              currentIndex,
                              theme,
                              killSwitchActive: killSwitchActive,
                              isMica: isMica,
                              disableTransparency: disableTransparency,
                            ),
                          Expanded(child: contentWithPanels),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Privacy Blur Overlay
                if (_isPrivacyBlurActive)
                  Positioned.fill(
                    child: motion.Animate(
                      effects: const [motion.FadeEffect(duration: Duration(milliseconds: 300))],
                      child: GestureDetector(
                        onTap: () => setState(() => _isPrivacyBlurActive = false),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                          child: Container(
                            color: OasisColors.deep.withValues(alpha: 0.7),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.spa_rounded, color: OasisColors.glow, size: 80),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Privacy Mode Active',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: OasisColors.white,
                                      fontFamily: 'Cormorant Garamond',
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to resume your Oasis',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: OasisColors.mist,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar:
              !isDesktop
                  ? _buildBottomNavigationBar(
                    context,
                    currentIndex,
                    theme,
                    killSwitchActive: killSwitchActive,
                  )
                  : null,
          floatingActionButton: _buildFloatingActionButton(
            context,
            currentIndex,
            theme,
            killSwitchActive: killSwitchActive,
          ),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(
    BuildContext context,
    int currentIndex,
    ThemeData theme, {
    required bool killSwitchActive,
  }) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    if (isDesktop) return null;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    if (currentIndex == 2) {
      // Spaces tab — no FAB needed, circles/canvas have their own buttons
      return null;
    } else if (currentIndex == 0 && !killSwitchActive) {
      // Feed tab FAB — hidden when kill-switch is active
      return FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder:
                (context) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.post_add, size: 28),
                        title: const Text('New Post'),
                        subtitle: const Text(
                          'Share a moment with your community',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('create_post');
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(
                          FluentIcons.video_24_regular,
                          size: 28,
                        ),
                        title: const Text('New Ripple'),
                        subtitle: const Text('Share a short video ripple'),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('create_ripple');
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.lock_clock, size: 28),
                        title: const Text('Time Capsule'),
                        subtitle: const Text('Seal a message for the future'),
                        onTap: () {
                          Navigator.pop(context);
                          context.pushNamed('create_capsule');
                        },
                      ),
                    ],
                  ),
                ),
          );
        },
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        elevation: isM3E ? 3 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isM3E ? 16 : 28),
        ),
        child: Icon(
          Icons.add_rounded,
          color: theme.colorScheme.onPrimaryContainer,
          size: 28,
        ),
      );
    }
    return null;
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    ThemeData theme, {
    required bool killSwitchActive,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency =
        themeProvider.isM3EEnabled && themeProvider.isM3ETransparencyDisabled;

    // Indices 0 (Feed) and 1 (Search) are restricted when kill-switch is on.
    Widget restrictedIcon(Widget icon) =>
        killSwitchActive ? Opacity(opacity: 0.3, child: icon) : icon;

    final navBar = NavigationBarM3E(
      backgroundColor:
          disableTransparency
              ? theme.colorScheme.surfaceContainer
              : Colors.transparent,
      elevation: disableTransparency ? 3 : 0,
      selectedIndex: currentIndex,
      onDestinationSelected:
          (i) => _onDestinationSelected(i, killSwitchActive: killSwitchActive),
      labelBehavior: NavBarM3ELabelBehavior.alwaysShow,
      destinations: [
        NavigationDestinationM3E(
          icon: restrictedIcon(const Icon(FluentIcons.home_24_regular)),
          selectedIcon: restrictedIcon(const Icon(FluentIcons.home_24_filled)),
          label: 'Feed',
        ),
        NavigationDestinationM3E(
          icon: restrictedIcon(const Icon(FluentIcons.search_24_regular)),
          selectedIcon: restrictedIcon(
            const Icon(FluentIcons.search_24_filled),
          ),
          label: 'Search',
        ),
        const NavigationDestinationM3E(
          icon: Icon(FluentIcons.channel_24_regular),
          selectedIcon: Icon(FluentIcons.channel_24_filled),
          label: 'Spaces',
        ),
        const NavigationDestinationM3E(
          icon: UnreadMessagesBadge(child: Icon(FluentIcons.chat_24_regular)),
          selectedIcon: UnreadMessagesBadge(
            child: Icon(FluentIcons.chat_24_filled),
          ),
          label: 'Messages',
        ),
        const NavigationDestinationM3E(
          icon: Icon(FluentIcons.alert_24_regular),
          selectedIcon: Icon(FluentIcons.alert_24_filled),
          label: 'Alerts',
        ),
        NavigationDestinationM3E(
          icon: GestureDetector(
            onLongPress: () => AccountSwitcherSheet.show(context),
            child: const Icon(FluentIcons.person_24_regular),
          ),
          selectedIcon: GestureDetector(
            onLongPress: () => AccountSwitcherSheet.show(context),
            child: const Icon(FluentIcons.person_24_filled),
          ),
          label: 'Profile',
        ),
      ],
    );

    if (disableTransparency) {
      return navBar;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: 0.7,
        ), // Semi-transparent tint
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: navBar,
        ),
      ),
    );
  }

  Widget _buildNavigationRail(
    BuildContext context,
    int currentIndex,
    ThemeData theme, {
    required bool killSwitchActive,
    bool isMica = false,
    bool disableTransparency = false,
  }) {
    final colorScheme = theme.colorScheme;

    Widget restrictedIcon(Widget icon) =>
        killSwitchActive ? Opacity(opacity: 0.3, child: icon) : icon;

    return NavigationRail(
      extended: _isRailExtended,
      selectedIndex: currentIndex,
      onDestinationSelected:
          (i) => _onDestinationSelected(i, killSwitchActive: killSwitchActive),
      labelType:
          _isRailExtended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
      backgroundColor:
          disableTransparency
              ? theme.colorScheme.surface
              : (isMica ? Colors.transparent : const Color(0xFF0C0F14)),
      leading: Column(
        children: [
          const SizedBox(height: 8),
          IconButton(
            icon: Icon(_isRailExtended ? Icons.menu_open : Icons.menu),
            onPressed: () => setState(() => _isRailExtended = !_isRailExtended),
            color: colorScheme.onSurfaceVariant,
          ),
          if (_isRailExtended)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: _buildDesktopCreateButton(context, theme),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTapDown:
                    (details) =>
                        _showCreateMenu(context, details.globalPosition, theme),
                child: IconButton.filled(
                  onPressed: () {}, // Handled by onTapDown for position
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(56, 56),
                  ),
                ),
              ),
            ),
        ],
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () => context.go('/profile'),
              onLongPress: () => AccountSwitcherSheet.show(context),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: restrictedIcon(const Icon(FluentIcons.home_24_regular)),
          selectedIcon: restrictedIcon(const Icon(FluentIcons.home_24_filled)),
          label:
              killSwitchActive
                  ? const Text('Feed', style: TextStyle(color: Colors.grey))
                  : const Text('Feed'),
        ),
        NavigationRailDestination(
          icon: restrictedIcon(const Icon(FluentIcons.search_24_regular)),
          selectedIcon: restrictedIcon(
            const Icon(FluentIcons.search_24_filled),
          ),
          label:
              killSwitchActive
                  ? const Text('Search', style: TextStyle(color: Colors.grey))
                  : const Text('Search'),
        ),
        const NavigationRailDestination(
          icon: Icon(FluentIcons.channel_24_regular),
          selectedIcon: Icon(FluentIcons.channel_24_filled),
          label: Text('Spaces'),
        ),
        const NavigationRailDestination(
          icon: UnreadMessagesBadge(child: Icon(FluentIcons.chat_24_regular)),
          selectedIcon: UnreadMessagesBadge(
            child: Icon(FluentIcons.chat_24_filled),
          ),
          label: Text('Messages'),
        ),
        const NavigationRailDestination(
          icon: Icon(FluentIcons.alert_24_regular),
          selectedIcon: Icon(FluentIcons.alert_24_filled),
          label: Text('Notifications'),
        ),
        NavigationRailDestination(
          icon: GestureDetector(
            onLongPress: () => AccountSwitcherSheet.show(context),
            child: const Icon(FluentIcons.person_24_regular),
          ),
          selectedIcon: GestureDetector(
            onLongPress: () => AccountSwitcherSheet.show(context),
            child: const Icon(FluentIcons.person_24_filled),
          ),
          label: const Text('Profile'),
        ),
      ],
    );
  }

  Widget _buildDesktopCreateButton(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTapDown:
          (details) => _showCreateMenu(context, details.globalPosition, theme),
      child: InkWell(
        onTap: () {}, // Handled by onTapDown
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'CREATE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateMenu(BuildContext context, Offset position, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      color:
          theme.brightness == Brightness.dark
              ? const Color(0xFF1A1D24)
              : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      items: [
        PopupMenuItem(
          onTap: () {
            // Delay slightly to allow menu to close
            Future.delayed(const Duration(milliseconds: 10), () {
              if (context.mounted) context.pushNamed('create_post');
            });
          },
          child: Row(
            children: [
              Icon(
                Icons.post_add,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('New Post'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 10), () {
              if (context.mounted) context.pushNamed('create_ripple');
            });
          },
          child: Row(
            children: [
              Icon(
                FluentIcons.video_24_regular,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('New Ripple'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 10), () {
              if (context.mounted) context.pushNamed('create_capsule');
            });
          },
          child: Row(
            children: [
              Icon(
                Icons.lock_clock,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('Time Capsule'),
            ],
          ),
        ),
      ],
    );
  }

  void _onDestinationSelected(int index, {bool killSwitchActive = false}) {
    // Block interaction with Feed (0) and Search (1) when kill-switch is active.
    if (killSwitchActive && (index == 0 || index == 1)) return;

    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      if (index == 1) {
        // Search
        setState(() {
          _activePanel = _activePanel == 'search' ? null : 'search';
        });
        return;
      }
      if (index == 4) {
        // Notifications
        setState(() {
          _activePanel =
              _activePanel == 'notifications' ? null : 'notifications';
        });
        return;
      }

      // Close active panel if navigating to other destinations
      if (_activePanel != null) {
        setState(() {
          _activePanel = null;
        });
      }
    }

    // Normal navigation for non-panel items or non-desktop
    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/spaces');
        break;
      case 3:
        context.go('/messages');
        break;
      case 4:
        context.go('/notifications');
        break;
      case 5:
        context.go('/profile');
        break;
    }
  }

  Widget _buildFluentCreateButton(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.FlyoutTarget(
      controller: _fluentCreateFlyoutController,
      child: fluent.SizedBox(
        width: double.infinity,
        child: fluent.Button(
          onPressed: () => _showFluentCreateMenu(context),
          style: fluent.ButtonStyle(
            backgroundColor: fluent.WidgetStateProperty.resolveWith((states) {
              if (states.contains(fluent.WidgetState.hovered)) {
                return theme.accentColor.light;
              }
              return theme.accentColor;
            }),
            padding: fluent.WidgetStateProperty.all(
              EdgeInsets.symmetric(
                horizontal: _isRailExtended ? 16 : 10,
                vertical: 10,
              ),
            ),
            shape: fluent.WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(fluent.FluentIcons.add, color: Colors.white, size: 20),
              if (_isRailExtended) ...[
                const SizedBox(width: 12),
                const Text(
                  'CREATE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFluentCreateMenu(BuildContext context) {
    _fluentCreateFlyoutController.showFlyout(
      autoModeConfiguration: fluent.FlyoutAutoConfiguration(
        preferredMode: fluent.FlyoutPlacementMode.bottomCenter,
      ),
      builder: (flyoutContext) {
        return fluent.MenuFlyout(
          items: [
            fluent.MenuFlyoutItem(
              leading: const Icon(fluent.FluentIcons.post_update),
              text: const Text('New Post'),
              onPressed: () {
                _fluentCreateFlyoutController.close();
                if (mounted) context.pushNamed('create_post');
              },
            ),
            fluent.MenuFlyoutItem(
              leading: const Icon(fluent.FluentIcons.video),
              text: const Text('New Ripple'),
              onPressed: () {
                _fluentCreateFlyoutController.close();
                if (mounted) context.pushNamed('create_ripple');
              },
            ),
            fluent.MenuFlyoutItem(
              leading: const Icon(fluent.FluentIcons.history),
              text: const Text('Time Capsule'),
              onPressed: () {
                _fluentCreateFlyoutController.close();
                if (mounted) context.pushNamed('create_capsule');
              },
            ),
          ],
        );
      },
    );
  }
}

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  /// Routes that do NOT require authentication — unauthenticated users can visit
  /// them freely (the login wall doesn't apply).
  static bool _isPublicRoute(String path) {
    return path == '/login' ||
        path == '/register' ||
        path == '/splash' ||
        path == '/reset-password' || // accessible with a recovery session
        path ==
            '/set-password'; // accessible with a recovery session (for Google users)
  }

  /// Routes that a fully-authenticated user should be bounced away from
  /// (e.g. they are already logged in, so login/register are irrelevant).
  /// NOTE: /reset-password is intentionally excluded — a user with a
  /// password-recovery session must be allowed to reach this screen.
  static bool _isLoginOnlyRoute(String path) {
    return path == '/login' || path == '/register';
  }

  static GoRouter? _router;

  static GoRouter get router {
    _router ??= GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/feed',
      refreshListenable: AuthService(),
      observers: [
        if (AppAnalytics.observer != null) AppAnalytics.observer!,
      ],
      debugLogDiagnostics: false,
      redirect: (context, state) async {
        // Password-reset screen is always reachable once Supabase sets the
        // recovery session — never redirect away from it automatically.
        if (state.uri.path == '/reset-password') return null;
        // Same for set-password screen
        if (state.uri.path == '/set-password') return null;

        // Check onboarding status
        final hasSeenOnboarding = await OnboardingScreen.hasSeenOnboarding();
        if (!hasSeenOnboarding && state.uri.path != '/onboarding') {
          return '/onboarding';
        }

        final authService = Provider.of<AuthService>(context, listen: false);
        final isLoggedIn = authService.currentUser != null;

        // Unauthenticated users trying to reach a protected route → login
        if (!isLoggedIn &&
            !_isPublicRoute(state.uri.path) &&
            state.uri.path != '/onboarding') {
          return '/login';
        }

        // Authenticated users trying to reach login/register → feed
        if (isLoggedIn && _isLoginOnlyRoute(state.uri.path)) {
          // Allow if specifically adding a new account
          if (state.uri.queryParameters['add_account'] == 'true') {
            return null;
          }
          return '/feed';
        }

        return null;
      },
      routes: [
        // Auth Routes
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const login_screen.LoginScreen(),
              ),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const RegisterScreen(),
              ),
        ),
        GoRoute(
          path: '/reset-password',
          name: 'reset_password',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const ResetPasswordScreen(),
              ),
        ),

        // Set Password (for Google users who want to set a password)
        GoRoute(
          path: '/set-password',
          name: 'set_password',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const ResetPasswordScreen(),
              ),
        ),

        // Main App Shell (Tab Navigation)
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            // Feed Screen
            GoRoute(
              path: '/feed',
              name: 'feed',
              pageBuilder:
                  (context, state) =>
                      const NoTransitionPage(child: FeedScreen()),
            ),

            // Search Screen
            GoRoute(
              path: '/search',
              name: 'search',
              pageBuilder:
                  (context, state) =>
                      const NoTransitionPage(child: SearchScreen()),
            ),

            // Communities Screen
            GoRoute(
              path: '/spaces',
              name: 'spaces',
              pageBuilder:
                  (context, state) =>
                      const NoTransitionPage(child: SpacesScreen()),
              routes: [
                GoRoute(
                  path: 'circles/create',
                  name: 'create_circle',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder:
                      (context, state) => const MaterialPage(
                        fullscreenDialog: true,
                        child: CreateCircleScreen(),
                      ),
                ),
                GoRoute(
                  path: 'canvas/create',
                  name: 'create_canvas',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder:
                      (context, state) => const MaterialPage(
                        fullscreenDialog: true,
                        child: CreateCanvasScreen(),
                      ),
                ),
                GoRoute(
                  path: 'circles/:circleId',
                  name: 'circle_detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['circleId']!;
                    return CircleDetailScreen(circleId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'add-commitment',
                      name: 'create_commitment',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (context, state) {
                        final id = state.pathParameters['circleId']!;
                        return CreateCommitmentScreen(circleId: id);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'canvas/:canvasId',
                  name: 'canvas_detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['canvasId']!;
                    return TimelineCanvasScreen(canvasId: id);
                  },
                ),
              ],
            ),

            // Direct Messages Screen
            GoRoute(
              path: '/messages',
              name: 'messages',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: messages.DirectMessagesScreen(
                    initialConversationId: extra?['initialConversationId'],
                    initialConversationData: extra,
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: ':conversationId',
                  name: 'chat_nested',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) {
                    final conversationId =
                        state.pathParameters['conversationId']!;
                    final extra = state.extra as Map<String, dynamic>?;

                    final isDesktop = ResponsiveLayout.isDesktop(context);

                    if (isDesktop) {
                      // On Desktop, navigate to messages with the conversation selected
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          context.go(
                            '/messages',
                            extra: {
                              'initialConversationId': conversationId,
                              ...?extra,
                            },
                          );
                        }
                      });
                      return const NoTransitionPage(
                        child: messages.DirectMessagesScreen(),
                      );
                    } else {
                      // On Mobile, push the dedicated ChatScreen with full height (no navbar)
                      return MaterialPage(
                        child: ChatScreen(
                          conversationId: conversationId,
                          otherUserName: extra?['otherUserName'],
                          otherUserAvatar: extra?['otherUserAvatar'],
                          otherUserId: extra?['otherUserId'],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            // Notifications Screen
            GoRoute(
              path: '/notifications',
              name: 'notifications',
              pageBuilder:
                  (context, state) =>
                      const NoTransitionPage(child: NotificationsScreen()),
            ),

            // Profile Screen
            GoRoute(
              path: '/profile',
              name: 'profile',
              pageBuilder:
                  (context, state) =>
                      const NoTransitionPage(child: ProfileScreen()),
            ),
          ],
        ),

        // Ripples Screen (Full screen, no bottom nav)
        GoRoute(
          path: '/ripples',
          name: 'ripples',
          pageBuilder:
              (context, state) => const MaterialPage(
                key: ValueKey('ripples_screen'),
                fullscreenDialog: true,
                child: RipplesScreen(),
              ),
          routes: [
            GoRoute(
              path: ':rippleId',
              name: 'ripple_details',
              builder: (context, state) {
                final id = state.pathParameters['rippleId'];
                return RipplesScreen(initialRippleId: id);
              },
            ),
          ],
        ),

        // Create Ripple Screen
        GoRoute(
          path: '/create-ripple',
          name: 'create_ripple',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) {
            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const CreateRippleScreen(),
            );
          },
        ),

        // Oasis Pro Screen (now pointing to SubscriptionScreen)
        GoRoute(
          path: '/oasis-pro',
          name: 'oasis_pro',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) {
            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const SubscriptionScreen(),
            );
          },
        ),

        // Auth Callback Route (Handled by Supabase SDK, but needs a route in GoRouter)
        GoRoute(
          path: '/auth/callback',
          builder: (context, state) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: '/auth/apple/callback',
          builder: (context, state) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),

        // Integrated Call Screen
        GoRoute(
          path: '/call/:callId',
          name: 'active_call',
          pageBuilder: (context, state) {
            final callId = state.pathParameters['callId'];
            final extra = state.extra as Map<String, dynamic>?;
            final isIncoming = extra?['isIncoming'] == true;

            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: CallingScreen(
                callId: callId,
                isIncoming: isIncoming,
              ),
            );
          },
        ),

        // Create Post Modal
        GoRoute(
          path: '/create-post',
          name: 'create_post',
          pageBuilder: (context, state) {
            final communityId = state.extra as String?;
            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: CreatePostScreen(communityId: communityId),
            );
          },
        ),

        // Create Time Capsule Modal
        GoRoute(
          path: '/create-capsule',
          name: 'create_capsule',
          pageBuilder: (context, state) {
            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const CreateCapsuleScreen(),
            );
          },
        ),

        // View Time Capsule (Deep Link)
        GoRoute(
          path: '/capsule/:capsuleId',
          name: 'view_capsule',
          builder: (context, state) {
            final id = state.pathParameters['capsuleId']!;
            return CapsuleViewScreen(capsuleId: id);
          },
        ),

        // Join Circle (Deep Link)
        GoRoute(
          path: '/circle/join/:circleId',
          name: 'join_circle',
          builder: (context, state) {
            final id = state.pathParameters['circleId']!;
            return CircleJoinScreen(circleId: id);
          },
        ),

        // Create Story Screen
        GoRoute(
          path: '/stories/create',
          name: 'create_story',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (context, state) {
            return MaterialPage(
              key: state.pageKey,
              fullscreenDialog: true,
              child: const new_create_story.CreateStoryScreen(),
            );
          },
        ),

        // Post Details Screen (Feed View)
        GoRoute(
          path: '/post/:postId',
          name: 'post_details',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return MaterialPage(
              key: state.pageKey,
              child: PostDetailsScreen(postId: postId),
            );
          },
        ),

        // Comments Screen
        GoRoute(
          path: '/post/:postId/comments',
          name: 'comments',
          pageBuilder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return MaterialPage(
              key: state.pageKey,
              child: CommentsScreen(postId: postId),
            );
          },
        ),

        // Edit Profile Screen
        GoRoute(
          path: '/edit-profile',
          name: 'edit_profile',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const EditProfileScreen(),
              ),
        ),

        // Settings Screen
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const SettingsScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/account',
          name: 'account_management',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const AccountManagementScreen(),
              ),
        ),

        // Subscription Screen
        GoRoute(
          path: '/subscription',
          name: 'subscription',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const SubscriptionScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/account-privacy',
          name: 'account_privacy',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const AccountPrivacyScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/blocked-users',
          name: 'blocked_users',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const BlockedUsersScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/two-factor-auth',
          name: 'two_factor_auth',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const TwoFactorAuthScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/download-data',
          name: 'download_data',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const DownloadDataScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/storage-usage',
          name: 'storage_usage',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const StorageUsageScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/font-size',
          name: 'font_size',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const FontSizeScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/help-support',
          name: 'help_support',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const HelpSupportScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/update',
          name: 'software_update',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const UpdateSettingsScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/delete-account',
          name: 'delete_account',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const DeleteAccountScreen(),
              ),
        ),
        GoRoute(
          path: '/settings/about',
          name: 'about',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const AboutAppScreen(),
              ),
          routes: [
            GoRoute(
              path: 'privacy-policy',
              name: 'privacy_policy_sub',
              pageBuilder:
                  (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const PrivacyPolicyScreen(),
                  ),
            ),
            GoRoute(
              path: 'terms-of-service',
              name: 'terms_of_service_sub',
              pageBuilder:
                  (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const TermsOfServiceScreen(),
                  ),
            ),
            GoRoute(
              path: 'changelog',
              name: 'changelog',
              pageBuilder:
                  (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const ChangelogScreen(),
                  ),
            ),
          ],
        ),

        // Legal Screens
        GoRoute(
          path: '/story/:storyId',
          name: 'story_view',
          pageBuilder: (context, state) {
            final storyId = state.pathParameters['storyId']!;
            final stories = state.extra as List<StoryEntity>;
            return CustomTransitionPage(
              key: state.pageKey,
              child: new_story_view.StoryViewScreen(
                initialStoryId: storyId,
                stories: stories,
              ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          },
        ),

        GoRoute(
          path: '/wellness-stats',
          name: 'wellness_stats',
          pageBuilder:
              (context, state) =>
                  const MaterialPage(child: WellnessStatsScreen()),
        ),
        // User Profile Screen (for viewing others)
        GoRoute(
          path: '/profile/:userId',
          name: 'user_profile',
          pageBuilder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return MaterialPage(
              key: state.pageKey,
              child: ProfileScreen(userId: userId),
            );
          },
        ),

        // Followers/Following Screen
        GoRoute(
          path: '/profile/:userId/followers',
          name: 'followers',
          pageBuilder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return MaterialPage(
              key: state.pageKey,
              child: FollowersScreen(userId: userId, initialTab: 0),
            );
          },
        ),
        GoRoute(
          path: '/profile/:userId/following',
          name: 'following',
          pageBuilder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return MaterialPage(
              key: state.pageKey,
              child: FollowersScreen(userId: userId, initialTab: 1),
            );
          },
        ), // New Message Screen
        GoRoute(
          path: '/new-message',
          name: 'new_message',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const NewMessageScreen(),
              ),
        ),

        // Legal Screens
        GoRoute(
          path: '/privacy-policy',
          name: 'privacy_policy',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const PrivacyPolicyScreen(),
              ),
        ),
        GoRoute(
          path: '/terms-of-service',
          name: 'terms_of_service',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const TermsOfServiceScreen(),
              ),
        ),

        // Onboarding Screen
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          pageBuilder:
              (context, state) => MaterialPage(
                key: state.pageKey,
                child: const OnboardingShell(),
              ),
        ),
      ],
    );
    return _router!;
  }
}

class _TwoFingerLongPressGestureRecognizer extends MultiTapGestureRecognizer {
  final VoidCallback onTwoFingerLongPress;
  final Map<int, Offset> _pointers = {};
  Timer? _longPressTimer;

  _TwoFingerLongPressGestureRecognizer({required this.onTwoFingerLongPress});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointers.length < 2) {
      _pointers[event.pointer] = event.position;
      if (_pointers.length == 2) {
        _startTimer();
      }
    }
    super.addAllowedPointer(event);
  }

  void _startTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 800), () {
      if (_pointers.length == 2) {
        onTwoFingerLongPress();
      }
    });
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2) {
      _longPressTimer?.cancel();
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (_pointers.length < 2) {
        _longPressTimer?.cancel();
      }
    }
  }

  @override
  String get debugDescription => 'twoFingerLongPress';
}
