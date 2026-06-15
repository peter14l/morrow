import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

class DesktopWindowService extends WindowListener with TrayListener {
  static final DesktopWindowService _instance = DesktopWindowService._();
  static DesktopWindowService get instance => _instance;

  DesktopWindowService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();
    await Window.initialize();
    await Window.makeTitlebarTransparent();
    try {
      await windowManager.setBackgroundColor(Colors.transparent);
    } catch (e) {
      debugPrint(
        'DesktopWindowService: Failed to set transparent background: $e',
      );
    }
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    // Set title
    await windowManager.setTitle('Oasis');

    // Set a reasonable minimum window size (social app minimum)
    await windowManager.setMinimumSize(const Size(800, 600));

    // Tray initialization - use absolute path for Windows
    await _setupTray();

    // Add listeners
    windowManager.addListener(this);
    trayManager.addListener(this);

    _isInitialized = true;
  }

  Future<void> _setupTray() async {
    // Get the executable path to locate assets
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final iconPath =
        '$exeDir\\data\\flutter_assets\\assets\\images\\app_icon.ico';

    // Try to set tray icon - fallback to ICO format
    try {
      final iconFile = File(iconPath);
      if (await iconFile.exists()) {
        await trayManager.setIcon(iconPath);
      } else {
        // Fallback to the runner icon
        final runnerIcon = '$exeDir\\resources\\app_icon.ico';
        final runnerFile = File(runnerIcon);
        if (await runnerFile.exists()) {
          await trayManager.setIcon(runnerIcon);
        } else {
          debugPrint('DesktopWindowService: No tray icon found at $iconPath');
        }
      }
    } catch (e) {
      debugPrint('DesktopWindowService: Failed to set tray icon: $e');
    }

    // Create context menu with async-safe approach
    await _updateTrayMenu();
  }

  Future<void> _updateTrayMenu() async {
    try {
      final Menu menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show Oasis'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Exit'),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('DesktopWindowService: Failed to set context menu: $e');
    }
  }

  bool? _lastEffectEnabled;
  String? _lastEffectType;
  bool? _lastEffectIsDark;

  Future<void> setWindowEffect({
    required bool enabled,
    String effect = 'mica',
    bool isDark = true,
  }) async {
    if (!Platform.isWindows) return;

    // Avoid redundant native calls
    if (enabled == _lastEffectEnabled &&
        effect == _lastEffectType &&
        isDark == _lastEffectIsDark) {
      return;
    }

    _lastEffectEnabled = enabled;
    _lastEffectType = effect;
    _lastEffectIsDark = isDark;

    if (!enabled) {
      await Window.setEffect(effect: WindowEffect.disabled);
      debugPrint('DesktopWindowService: Effects disabled');
      return;
    }

    WindowEffect windowEffect;
    Color? color;

    switch (effect) {
      case 'micaAlt':
        windowEffect = WindowEffect.mica; // Use mica as base
        break;
      case 'acrylic':
        windowEffect = WindowEffect.acrylic;
        color = isDark ? const Color(0x22000000) : const Color(0x22FFFFFF);
        break;
      case 'mica':
      default:
        windowEffect = WindowEffect.mica;
        color = Colors.transparent;
        break;
    }

    try {
      // Small delay to ensure window is ready for composition changes
      await Future.delayed(const Duration(milliseconds: 100));

      await Window.setEffect(
        effect: windowEffect,
        dark: isDark,
        color: color ?? Colors.transparent,
      );
      debugPrint(
        'DesktopWindowService: $effect effect enabled (dark: $isDark)',
      );
    } catch (e) {
      debugPrint(
        'DesktopWindowService: Effect $effect failed, trying alternative. Error: $e',
      );
      try {
        // Fallback to Mica Alt if Mica fails
        await Window.setEffect(
          effect: WindowEffect.mica,
          dark: isDark,
          color: Colors.transparent,
        );
      } catch (_) {
        try {
          // Final attempt with Acrylic
          await Window.setEffect(
            effect: WindowEffect.acrylic,
            color: isDark ? const Color(0x33000000) : const Color(0x33FFFFFF),
          );
        } catch (_) {
          await Window.setEffect(effect: WindowEffect.disabled);
          debugPrint('DesktopWindowService: All effects failed, disabled');
        }
      }
    }
  }

  // Track double-click for tray icon
  DateTime? _lastTrayClickTime;
  static const _doubleClickDuration = Duration(milliseconds: 500);

  // WindowManager overrides
  @override
  Future<void> onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    }
  }

  @override
  Future<void> onWindowMinimize() async {
    // Keep reference to visibility
  }

  @override
  Future<void> onWindowFocus() async {
    // OS handles focus and restoration naturally.
    // Manual manipulation here can cause native crashes on some Windows builds.
  }

  @override
  Future<void> onWindowBlur() async {
    // Optional: handle blur if needed
  }

  // TrayListener overrides - single left click to show window
  @override
  void onTrayIconMouseDown() {
    // Single click shows window - double click detection handled in mouse up
    // This is handled in onTrayIconMouseUp for better double-click detection
  }

  @override
  void onTrayIconMouseUp() {
    final now = DateTime.now();
    if (_lastTrayClickTime != null &&
        now.difference(_lastTrayClickTime!) < _doubleClickDuration) {
      // Double click - restore and focus window
      windowManager.show();
      windowManager.focus();
      windowManager.setSkipTaskbar(false);
      _lastTrayClickTime = null;
    } else {
      // Single click - show window
      windowManager.show();
      windowManager.setSkipTaskbar(false);
      _lastTrayClickTime = now;
    }
  }

  // Right click - show context menu (with error handling to prevent freezes)
  @override
  void onTrayIconRightMouseDown() {
    // Use try-catch to prevent freezes
    try {
      trayManager.popUpContextMenu();
    } catch (e) {
      debugPrint('DesktopWindowService: Right-click menu failed: $e');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
      windowManager.setSkipTaskbar(false);
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
    }
  }

  Future<void> enableCloseToTray() async {
    if (!Platform.isWindows) return;
    await windowManager.setPreventClose(true);
  }
}
