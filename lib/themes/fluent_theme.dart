import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:oasis/themes/app_colors.dart';

class AppFluentTheme {
  static FluentThemeData getTheme(
    material.Brightness brightness, {
    material.ColorScheme? materialColorScheme,
    String? fontFamily,
    bool micaEnabled = false,
  }) {
    final isDark = brightness == material.Brightness.dark;

    // Core colors synchronized with Material 3 / Oasis Palette
    final primaryColor =
        materialColorScheme?.primary ??
        (isDark ? DarkColors.primary : LightColors.primary);

    final scaffoldColor =
        materialColorScheme?.surface ??
        (isDark ? OasisColors.deep : LightColors.background);

    final micaBase = isDark ? material.Colors.black : material.Colors.white;

    // Mica/Acrylic transparency should only be applied on Windows/macOS
    final bool canUseTransparency =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final bool shouldBeTransparent = micaEnabled && canUseTransparency;

    final accentColor = AccentColor.swatch({
      'darkest': primaryColor.withValues(alpha: 0.9),
      'darker': primaryColor.withValues(alpha: 0.8),
      'dark': primaryColor.withValues(alpha: 0.7),
      'normal': primaryColor,
      'light': primaryColor.withValues(alpha: 0.7),
      'lighter': primaryColor.withValues(alpha: 0.6),
      'lightest': primaryColor.withValues(alpha: 0.5),
    });

    return FluentThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      accentColor: accentColor,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: shouldBeTransparent
          ? material.Colors.transparent
          : scaffoldColor,
      micaBackgroundColor: shouldBeTransparent
          ? micaBase.withValues(alpha: 0.01)
          : scaffoldColor,
      micaAltBackgroundColor: shouldBeTransparent
          ? micaBase.withValues(alpha: 0.01)
          : scaffoldColor,

      // Animation curves updated to WinUI 3 "Fluid" motion
      animationCurve: standardCurve,

      // Shadows standardized via FluentShadows
      shadows: FluentShadows.fromBrightness(
        isDark ? Brightness.dark : Brightness.light,
      ),

      // Typography updated to Segoe UI Variable by default
      typography:
          Typography.fromBrightness(
            brightness: isDark ? Brightness.dark : Brightness.light,
            color: isDark ? DarkColors.onBackground : LightColors.onBackground,
          ).apply(
            fontFamily:
                fontFamily ??
                (defaultTargetPlatform == material.TargetPlatform.windows
                    ? 'Segoe UI Variable'
                    : 'Segoe UI'),
          ),

      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: shouldBeTransparent
            ? Colors.transparent
            : (isDark ? DarkColors.surface : LightColors.surface),
        overlayBackgroundColor: shouldBeTransparent
            ? (isDark
                  ? DarkColors.surface.withValues(alpha: 0.8)
                  : LightColors.surface.withValues(alpha: 0.8))
            : (isDark ? DarkColors.surface : LightColors.surface),
        highlightColor: primaryColor,
        selectedIconColor: WidgetStateProperty.all(primaryColor),
        selectedTextStyle: WidgetStateProperty.all(
          TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        unselectedIconColor: WidgetStateProperty.all(
          isDark ? DarkColors.hint : LightColors.hint,
        ),
        tileColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return isDark
                ? material.Colors.white.withValues(alpha: 0.05)
                : material.Colors.black.withValues(alpha: 0.05);
          }
          if (states.isHovered) {
            return isDark
                ? material.Colors.white.withValues(alpha: 0.03)
                : material.Colors.black.withValues(alpha: 0.03);
          }
          return Colors.transparent;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        checkedIconColor: WidgetStateProperty.all(material.Colors.white),
      ),

      buttonTheme: ButtonThemeData(
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primaryColor),
          foregroundColor: WidgetStateProperty.all(material.Colors.white),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(thickness: 1),
    );
  }
}
