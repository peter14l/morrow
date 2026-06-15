import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';

/// Standard Windows 11 title bar height (matches native caption button area).
const double kWin11TitleBarHeight = 32.0;

/// Native Windows 11 caption button dimensions.
const double kWin11CaptionButtonWidth = 48.0;
const double kWin11CaptionButtonHeight = 32.0;

/// A native-feeling Windows 11 title bar with DragToMoveArea and caption
/// buttons that match Win11 sizing, hover effects, and behavior exactly.
///
/// On non-Windows platforms this widget shrinks to zero.
class WindowsTitleBar extends StatelessWidget {
  final double height;

  const WindowsTitleBar({super.key, this.height = kWin11TitleBarHeight});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          // Draggable area + app branding (fills remaining space)
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/app_icon.png',
                      width: 16,
                      height: 16,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.blur_on,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Win11TitleText(),
                  ],
                ),
              ),
            ),
          ),
          // Caption buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Win11CaptionButton(
                icon: FluentIcons.subtract_24_regular,
                onPressed: _minimizeWindow,
              ),
              _Win11CaptionButton(
                icon: FluentIcons.maximize_24_regular,
                onPressed: _toggleMaximize,
              ),
              _Win11CaptionButton(
                icon: FluentIcons.dismiss_24_regular,
                isClose: true,
                onPressed: _closeWindow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Window action helpers
// ---------------------------------------------------------------------------

void _minimizeWindow() => windowManager.minimize();

Future<void> _toggleMaximize() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

void _closeWindow() => windowManager.close();

// ---------------------------------------------------------------------------
// Helper: title text that adapts to Fluent / Material theme
// ---------------------------------------------------------------------------

class _Win11TitleText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Try Fluent theme first
    try {
      final ft = fluent.FluentTheme.of(context);
      final isDark = ft.brightness == fluent.Brightness.dark;
      return Text(
        'Oasis',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.9),
          letterSpacing: 0.3,
        ),
      );
    } catch (_) {
      // Fall back to Material theme
      final theme = Theme.of(context);
      return Text(
        'Oasis',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// _Win11CaptionButton — matches Windows 11 caption button spec exactly
// ---------------------------------------------------------------------------

class _Win11CaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _Win11CaptionButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_Win11CaptionButton> createState() => _Win11CaptionButtonState();
}

class _Win11CaptionButtonState extends State<_Win11CaptionButton> {
  bool _isHovered = false;

  Brightness _resolveBrightness(BuildContext context) {
    try {
      final ft = fluent.FluentTheme.of(context);
      return ft.brightness == fluent.Brightness.dark
          ? Brightness.dark
          : Brightness.light;
    } catch (_) {
      return Theme.of(context).brightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _resolveBrightness(context) == Brightness.dark;

    // Windows 11 caption button colors per UX spec
    const Color idleBackground = Colors.transparent;
    final Color hoverBackground = widget.isClose
        ? const Color(0xFFC42B1C) // Win11 close-button red
        : isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04);

    final Color idleIconColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.65);

    final Color hoverIconColor = widget.isClose
        ? Colors.white
        : isDark
            ? Colors.white
            : Colors.black.withValues(alpha: 0.9);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          width: kWin11CaptionButtonWidth,
          height: kWin11CaptionButtonHeight,
          color: _isHovered ? hoverBackground : idleBackground,
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 80),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            child: Icon(
              widget.icon,
              key: ValueKey('${widget.icon.hashCode}_$_isHovered'),
              size: 14,
              color: _isHovered ? hoverIconColor : idleIconColor,
            ),
          ),
        ),
      ),
    );
  }
}

