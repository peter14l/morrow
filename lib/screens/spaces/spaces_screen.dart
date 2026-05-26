import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/presentation/screens/circles_list_screen.dart';
import 'package:oasis/features/canvas/presentation/screens/canvas_list_screen.dart';
import 'package:oasis/widgets/desktop_header.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';

/// The Spaces hub replaces the old Communities tab.
/// It contains two sub-tabs: Circles & Canvas.
class SpacesScreen extends StatefulWidget {
  final int initialIndex;
  const SpacesScreen({super.key, this.initialIndex = 0});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent && isDesktop) {
      return AdaptiveScaffold(
        title: const Text('Spaces'),
        actions: [_buildDesktopTabSwitcher(theme.colorScheme, isM3E)],
        body: Row(
          children: [
            // Left sidebar for navigation
            Container(
              width: 240,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSidebarItem(
                    icon: FluentIcons.people_team_24_regular,
                    selectedIcon: FluentIcons.people_team_24_filled,
                    label: 'Circles',
                    index: 0,
                    isM3E: isM3E,
                  ),
                  const SizedBox(height: 8),
                  _buildSidebarItem(
                    icon: FluentIcons.whiteboard_24_regular,
                    selectedIcon: FluentIcons.whiteboard_24_filled,
                    label: 'Canvas',
                    index: 1,
                    isM3E: isM3E,
                  ),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [CirclesListScreen(), CanvasListScreen()],
              ),
            ),
          ],
        ),
      );
    }

    return AdaptiveScaffold(
      body: Column(
        children: [
          if (isDesktop) ...[
            DesktopHeader(
              title: 'Spaces',
              subtitle: 'Communities & Creative Hub',
              actions: [_buildDesktopTabSwitcher(theme.colorScheme, isM3E)],
            ),
            const Divider(height: 1),
          ],
          // ── Custom top tab bar for mobile/generic desktop ─────────────────
          if (!isDesktop)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _SpacesTabBar(controller: _tabController, isM3E: isM3E),
              ),
            ),

          // ── Tab views ────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                if (isDesktop)
                  Container(
                    width: 240,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSidebarItem(
                          icon: FluentIcons.people_team_24_regular,
                          selectedIcon: FluentIcons.people_team_24_filled,
                          label: 'Circles',
                          index: 0,
                          isM3E: isM3E,
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarItem(
                          icon: FluentIcons.whiteboard_24_regular,
                          selectedIcon: FluentIcons.whiteboard_24_filled,
                          label: 'Canvas',
                          index: 1,
                          isM3E: isM3E,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [CirclesListScreen(), CanvasListScreen()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(ThemeData theme, bool isM3E) {
    return Column(
      children: [
        DesktopHeader(
          title: 'Spaces',
          subtitle: 'Communities & Creative Hub',
          actions: [_buildDesktopTabSwitcher(theme.colorScheme, isM3E)],
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              // Left sidebar for navigation
              Container(
                width: 240,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSidebarItem(
                      icon: FluentIcons.people_team_24_regular,
                      selectedIcon: FluentIcons.people_team_24_filled,
                      label: 'Circles',
                      index: 0,
                      isM3E: isM3E,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: FluentIcons.whiteboard_24_regular,
                      selectedIcon: FluentIcons.whiteboard_24_filled,
                      label: 'Canvas',
                      index: 1,
                      isM3E: isM3E,
                    ),
                  ],
                ),
              ),
              // Main content area
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [CirclesListScreen(), CanvasListScreen()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isM3E,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _tabController.index == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _tabController.animateTo(index)),
        borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
            border: isSelected
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.2))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTabSwitcher(ColorScheme colorScheme, bool isM3E) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isM3E ? 12 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton('Circles', 0, colorScheme, isM3E),
          _buildTabButton('Canvas', 1, colorScheme, isM3E),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    int index,
    ColorScheme colorScheme,
    bool isM3E,
  ) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(isM3E ? 10 : 18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Custom pill tab bar ──────────────────────────────────────────────────────

class _SpacesTabBar extends StatelessWidget {
  final TabController controller;
  final bool isM3E;
  const _SpacesTabBar({required this.controller, this.isM3E = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isM3E ? 12 : 16),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: TabBar(
        controller: controller,
        labelColor: theme.colorScheme.onPrimary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
          letterSpacing: isM3E ? -0.5 : 0,
        ),
        unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.normal,
        ),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(isM3E ? 10 : 13),
          color: theme.colorScheme.primary,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.people_team_24_regular, size: 16),
                SizedBox(width: 6),
                Text('Circles'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(FluentIcons.whiteboard_24_regular, size: 16),
                SizedBox(width: 6),
                Text('Canvas'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
