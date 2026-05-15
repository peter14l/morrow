import 'dart:ui';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

/// Navigation shell with bottom navigation bar
class NavigationShell extends material.StatelessWidget {
  final material.Widget child;
  final int currentIndex;

  const NavigationShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  material.Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final useFluent = themeProvider.useFluentUI;

    // Get unread count
    final unreadCount = context.watch<ConversationProvider>().totalUnreadCount;

    if (useFluent) {
      return _buildFluentLayout(context, themeProvider, unreadCount);
    }

    if (isDesktop) {
      return _buildDesktopLayout(context, theme, themeProvider, isM3E);
    }

    return _buildMobileLayout(
      context,
      theme,
      themeProvider,
      isM3E,
      unreadCount,
    );
  }

  material.Widget _buildFluentLayout(
    material.BuildContext context,
    ThemeProvider themeProvider,
    int unreadCount,
  ) {
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: currentIndex,
        size: const fluent.NavigationPaneSize(compactWidth: 54),
        onChanged: (index) => _onDestinationSelected(context, index),
        displayMode: fluent.PaneDisplayMode.auto,
        items: [
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.home_24_regular),
            selectedIcon: const material.Icon(FluentIcons.home_24_filled),
            title: const Text('Feed'),
            body: material.SizedBox.shrink(),
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.people_24_regular),
            selectedIcon: const material.Icon(FluentIcons.people_24_filled),
            title: const Text('Circles'),
            body: material.SizedBox.shrink(),
          ),
          fluent.PaneItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const material.Icon(FluentIcons.chat_24_regular),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: fluent.InfoBadge(
                      source: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: material.Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                const material.Icon(FluentIcons.chat_24_filled),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: fluent.InfoBadge(
                      source: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: material.Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: const Text('Messages'),
            body: material.SizedBox.shrink(),
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.alert_24_regular),
            selectedIcon: const material.Icon(FluentIcons.alert_24_filled),
            title: const Text('Alerts'),
            body: material.SizedBox.shrink(),
          ),
        ],
        footerItems: [
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.person_24_regular),
            title: const Text('Profile'),
            body: material.SizedBox.shrink(),
            onTap: () => context.go('/profile'),
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.settings_24_regular),
            title: const Text('Settings'),
            body: material.SizedBox.shrink(),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
      content: child,
    );
  }

  material.Widget _buildMobileLayout(
    material.BuildContext context,
    material.ThemeData theme,
    ThemeProvider themeProvider,
    bool isM3E,
    int unreadCount,
  ) {
    final liquidGlassMode =
        context.watch<UserSettingsProvider>().liquidGlassMode;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    final navigationBar = material.NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => _onDestinationSelected(context, index),
      destinations: [
        const material.NavigationDestination(
          icon: material.Icon(FluentIcons.home_24_regular),
          selectedIcon: material.Icon(FluentIcons.home_24_filled),
          label: 'Feed',
        ),
        const material.NavigationDestination(
          icon: material.Icon(FluentIcons.search_24_regular),
          selectedIcon: material.Icon(FluentIcons.search_24_filled),
          label: 'Search',
        ),
        const material.NavigationDestination(
          icon: material.Icon(FluentIcons.people_24_regular),
          selectedIcon: material.Icon(FluentIcons.people_24_filled),
          label: 'Circles',
        ),
        material.NavigationDestination(
          icon: material.Badge(
            isLabelVisible: unreadCount > 0,
            label: material.Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
            ),
            child: const material.Icon(FluentIcons.chat_24_regular),
          ),
          selectedIcon: material.Badge(
            isLabelVisible: unreadCount > 0,
            label: material.Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
            ),
            child: const material.Icon(FluentIcons.chat_24_filled),
          ),
          label: 'Messages',
        ),
        const material.NavigationDestination(
          icon: material.Icon(FluentIcons.alert_24_regular),
          selectedIcon: material.Icon(FluentIcons.alert_24_filled),
          label: 'Alerts',
        ),
      ],
    );

    // Always wrap to handle global transparency toggle and liquid glass
    return material.Scaffold(
      body: child,
      bottomNavigationBar: _applyLiquidGlassToBottomNav(
        navigationBar,
        liquidGlassMode,
        theme.brightness,
        context,
      ),
    );
  }

  Widget _applyLiquidGlassToBottomNav(
    Widget navBar,
    LiquidGlassMode mode,
    material.Brightness brightness,
    BuildContext context,
  ) {
    final themeProvider = material.Provider.of<ThemeProvider>(
      context,
      listen: false,
    );
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    if (disableTransparency) {
      return Container(
        color: brightness == material.Brightness.dark
            ? const material.Color(0xFF1A1D24)
            : material.Colors.white,
        child: navBar,
      );
    }

    if (mode == LiquidGlassMode.disabled) {
      return navBar;
    }

    if (mode == LiquidGlassMode.fake) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: brightness == material.Brightness.dark
                  ? material.Colors.white.withValues(alpha: 0.1)
                  : material.Colors.white.withValues(alpha: 0.3),
            ),
            child: navBar,
          ),
        ),
      );
    }
    // For real mode, fall back to fake for bottom nav (better performance)
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: brightness == material.Brightness.dark
                ? material.Colors.white.withValues(alpha: 0.15)
                : material.Colors.white.withValues(alpha: 0.4),
          ),
          child: navBar,
        ),
      ),
    );
  }

  material.Widget _buildDesktopLayout(
    material.BuildContext context,
    material.ThemeData theme,
    ThemeProvider themeProvider,
    bool isM3E,
  ) {
    return material.Scaffold(
      body: material.Row(
        children: [
          material.NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            labelType: material.NavigationRailLabelType.all,
            destinations: const [
              material.NavigationRailDestination(
                icon: material.Icon(FluentIcons.home_24_regular),
                selectedIcon: material.Icon(FluentIcons.home_24_filled),
                label: material.Text('Feed'),
              ),
              material.NavigationRailDestination(
                icon: material.Icon(FluentIcons.search_24_regular),
                selectedIcon: material.Icon(FluentIcons.search_24_filled),
                label: material.Text('Search'),
              ),
              material.NavigationRailDestination(
                icon: material.Icon(FluentIcons.people_24_regular),
                selectedIcon: material.Icon(FluentIcons.people_24_filled),
                label: material.Text('Circles'),
              ),
              material.NavigationRailDestination(
                icon: material.Icon(FluentIcons.chat_24_regular),
                selectedIcon: material.Icon(FluentIcons.chat_24_filled),
                label: material.Text('Messages'),
              ),
              material.NavigationRailDestination(
                icon: material.Icon(FluentIcons.alert_24_regular),
                selectedIcon: material.Icon(FluentIcons.alert_24_filled),
                label: material.Text('Alerts'),
              ),
            ],
          ),
          const material.VerticalDivider(thickness: 1, width: 1),
          material.Expanded(child: child),
        ],
      ),
    );
  }

  void _onDestinationSelected(material.BuildContext context, int index) {
    // Unfocus to prevent keyboard state sync issues during navigation transitions
    material.FocusManager.instance.primaryFocus?.unfocus();

    switch (index) {
      case 0:
        context.go('/feed');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/circles');
        break;
      case 3:
        context.go('/messages');
        break;
      case 4:
        context.go('/notifications');
        break;
    }
  }
}

/// Badge widget for unread messages (extracted from app_router.dart)
class UnreadMessagesBadge extends material.StatelessWidget {
  final material.Widget child;
  final bool isSelected;

  const UnreadMessagesBadge({
    super.key,
    required this.child,
    this.isSelected = false,
  });

  @override
  material.Widget build(material.BuildContext context) {
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
                      style: const TextStyle(
                        fontSize: 8,
                        color: material.Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return material.Badge(
          isLabelVisible: count > 0,
          label: material.Text(count.toString()),
          child: child,
        );
      },
    );
  }
}
