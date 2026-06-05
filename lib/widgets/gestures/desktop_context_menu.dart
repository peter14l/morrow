import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oasis/core/utils/responsive_layout.dart';

/// Menu item for use with DesktopContextMenu
class MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  const MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.enabled = true,
  });
}

/// Desktop context menu that shows a proper right-click context menu on desktop,
/// and falls back to modal bottom sheet on mobile (preserving existing behavior)
class DesktopContextMenu {
  /// Show a context menu at the specified position
  static Future<T?> show<T>({
    required BuildContext context,
    required List<MenuItem> items,
    RelativeRect? position,
  }) async {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    if (isDesktop) {
      // Desktop: Show popup menu at position
      return _showDesktopMenu<T>(
        context: context,
        items: items,
        position: position,
        size: size,
      );
    } else {
      // Mobile: Fall back to bottom sheet (preserves existing behavior)
      return _showMobileSheet<T>(context: context, items: items);
    }
  }

  static Future<T?> _showDesktopMenu<T>({
    required BuildContext context,
    required List<MenuItem> items,
    RelativeRect? position,
    Size? size,
  }) async {
    if (position == null) {
      // Default to center of the widget
      final box = context.findRenderObject() as RenderBox;
      final center = box.size.center(Offset.zero);
      position = RelativeRect.fromRect(
        Rect.fromCenter(center: center, width: 0, height: 0),
        Rect.fromLTWH(0, 0, box.size.width, box.size.height),
      );
    }

    return await showMenu<T>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      items: items.map((item) {
        return PopupMenuItem<T>(
          enabled: item.enabled,
          onTap: item.enabled
              ? () {
                  item.onTap();
                }
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: item.enabled
                    ? (item.color ?? Theme.of(context).colorScheme.onSurface)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color: item.enabled
                      ? (item.color ?? Theme.of(context).colorScheme.onSurface)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Future<T?> _showMobileSheet<T>({
    required BuildContext context,
    required List<MenuItem> items,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;

    return await context.showResponsiveSheet(
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Menu items
            ...items.map(
              (item) => ListTile(
                leading: Icon(
                  item.icon,
                  color: item.enabled
                      ? (item.color ?? colorScheme.onSurface)
                      : colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: item.enabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
                enabled: item.enabled,
                onTap: item.enabled
                    ? () {
                        HapticUtils.selectionClick();
                        Navigator.pop(context);
                        item.onTap();
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Wrap any widget to enable right-click context menu on desktop
/// while preserving long-press for mobile
class SecondaryTapHandler extends StatelessWidget {
  final Widget child;
  final List<MenuItem> menuItems;
  final VoidCallback? onMobileLongPress; // Keep for mobile fallback
  final bool showOnDesktop;
  final bool showOnMobile;

  const SecondaryTapHandler({
    super.key,
    required this.child,
    required this.menuItems,
    this.onMobileLongPress,
    this.showOnDesktop = true,
    this.showOnMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop && showOnDesktop) {
      return GestureDetector(
        onSecondaryTapDown: (details) =>
            _showMenu(context, details.globalPosition),
        onSecondaryTapUp: (_) {}, // Prevent text selection
        child: child,
      );
    } else if (showOnMobile) {
      // Keep existing long-press behavior for mobile
      return GestureDetector(
        onLongPress: () {
          HapticUtils.mediumImpact();
          onMobileLongPress?.call();
          _showMenuAtCenter(context);
        },
        child: child,
      );
    }

    return child;
  }

  void _showMenu(BuildContext context, Offset position) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final RelativeRect position2 = RelativeRect.fromRect(
      Rect.fromCenter(center: position, width: 0, height: 0),
      Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
    );

    DesktopContextMenu.show(
      context: context,
      items: menuItems,
      position: position2,
    );
  }

  void _showMenuAtCenter(BuildContext context) {
    DesktopContextMenu.show(context: context, items: menuItems);
  }
}

/// Button that shows context menu - desktop-native alternative to bottom sheet triggers
class ContextMenuButton extends StatelessWidget {
  final List<MenuItem> menuItems;
  final Widget child;
  final VoidCallback? onMobileTap;

  const ContextMenuButton({
    super.key,
    required this.menuItems,
    required this.child,
    this.onMobileTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return SecondaryTapHandler(
        menuItems: menuItems,
        showOnMobile: false,
        child: child,
      );
    } else {
      // Mobile: Show bottom sheet on tap (existing behavior)
      return GestureDetector(
        onTap: () {
          onMobileTap?.call();
          _showMenuAtCenter(context);
        },
        child: child,
      );
    }
  }

  void _showMenuAtCenter(BuildContext context) {
    DesktopContextMenu.show(context: context, items: menuItems);
  }
}

/// Haptic feedback utilities
class HapticUtils {
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  static void lightImpact() {
    HapticFeedback.lightImpact();
  }
}
