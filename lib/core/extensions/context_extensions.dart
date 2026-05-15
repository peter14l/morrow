import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Common BuildContext extensions for quick access to theme, sizing, and navigation.
extension ContextX on BuildContext {
  /// Get the current ThemeData.
  ThemeData get theme => Theme.of(this);

  /// Get the current ColorScheme.
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get the current TextTheme.
  TextTheme get textTheme => theme.textTheme;

  /// Get the current MediaQueryData.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get the screen size.
  Size get screenSize => mediaQuery.size;

  /// Get the screen width.
  double get screenWidth => screenSize.width;

  /// Get the screen height.
  double get screenHeight => screenSize.height;

  /// Get the text scale factor.
  double get textScaleFactor => mediaQuery.textScaler.scale(1.0);

  /// Check if current screen is small (mobile).
  bool get isSmallScreen => screenWidth < 600;

  /// Check if current screen is tablet-sized.
  bool get isTabletScreen => screenWidth >= 600 && screenWidth < 1200;

  /// Check if current screen is desktop-sized.
  bool get isDesktopScreen => screenWidth >= 1200;

  /// Whether the current platform should use solid backgrounds for readability (Desktop/Web).
  bool get shouldUseSolidBackground {
    if (kIsWeb) return true;
    try {
      return Platform.isWindows || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Get the safe area padding.
  EdgeInsets get safePadding => mediaQuery.padding;

  /// Get the view insets (keyboard height).
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  /// Show a SnackBar with the given message.
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
    Color? textColor,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textColor != null ? TextStyle(color: textColor) : null,
        ),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Show an error SnackBar.
  void showErrorSnackBar(String message) {
    showSnackBar(
      message,
      backgroundColor: colorScheme.errorContainer,
      textColor: colorScheme.onErrorContainer,
    );
  }

  /// Show a success SnackBar.
  void showSuccessSnackBar(String message) {
    // Using tertiary for success in M3 Expressive context if available,
    // otherwise a custom success color from theme extensions or default green.
    showSnackBar(
      message,
      backgroundColor: colorScheme.tertiaryContainer,
      textColor: colorScheme.onTertiaryContainer,
    );
  }

  /// Show a modal bottom sheet.
  Future<T?> showAppBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    Color? backgroundColor,
    double? maxHeight,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: this,
      isScrollControlled: isScrollControlled,
      // On desktop/web, prioritize opaque backgrounds for readability
      backgroundColor:
          backgroundColor ??
          (shouldUseSolidBackground
              ? (isDark ? const Color(0xFF0D1F1A) : Colors.white)
              : Colors.transparent),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight)
          : null,
      builder: (context) => builder(context),
    );
  }

  /// Show a dialog.
  Future<T?> showAppDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }
}
