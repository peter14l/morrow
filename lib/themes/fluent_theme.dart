import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:oasis/themes/app_colors.dart';

/// WinUI 3 corner radii used by Windows 11 controls.
const _kWin11RadiusSmall = 4.0;
const _kWin11RadiusMedium = 8.0;
const _kWin11RadiusLarge = 12.0;

/// Application-level Fluent theme that mirrors Windows 11 design principles
/// — compact density, subtle surface layering, 4px control radii, and Segoe UI
/// Variable typography.
class AppFluentTheme {
  static FluentThemeData getTheme(
    material.Brightness brightness, {
    material.ColorScheme? materialColorScheme,
    String? fontFamily,
    bool micaEnabled = false,
  }) {
    final isDark = brightness == material.Brightness.dark;

    // Derive primary accent color
    final primaryColor =
        materialColorScheme?.primary ??
        (isDark ? DarkColors.primary : LightColors.primary);

    final surfaceColor =
        materialColorScheme?.surface ??
        (isDark ? OasisColors.deep : LightColors.background);

    // Surface hierarchy — Win11 uses layered cards with subtle separation
    final cardSurfaceColor =
        isDark
            ? const Color(0xFF1E2026)
            : const Color(0xFFF3F3F5);

    final micaBase = isDark ? material.Colors.black : material.Colors.white;

    // Transparency is only valid on Windows/macOS where Mica/Acrylic are supported
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

    // Foreground text color
    final onSurface = isDark
        ? DarkColors.onBackground
        : LightColors.onBackground;

    return FluentThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      accentColor: accentColor,
      fontFamily: fontFamily,
      // Desktop apps use compact density (tighter spacing, more content)
      visualDensity: VisualDensity.compact,

      // --- Surface / Background ---
      scaffoldBackgroundColor: shouldBeTransparent
          ? material.Colors.transparent
          : surfaceColor,
      micaBackgroundColor: shouldBeTransparent
          ? micaBase.withValues(alpha: 0.01)
          : surfaceColor,
      micaAltBackgroundColor: shouldBeTransparent
          ? micaBase.withValues(alpha: 0.01)
          : cardSurfaceColor,

      // WinUI 3 "Fluid" motion
      animationCurve: standardCurve,

      // Elevation shadows matching WinUI 3 elevation system
      shadows: FluentShadows.fromBrightness(
        isDark ? Brightness.dark : Brightness.light,
      ),

      // --- Typography: Segoe UI Variable on Windows, Segoe UI elsewhere ---
      typography:
          Typography.fromBrightness(
            brightness: isDark ? Brightness.dark : Brightness.light,
            color: onSurface,
          ).apply(
            fontFamily:
                fontFamily ??
                (defaultTargetPlatform == material.TargetPlatform.windows
                    ? 'Segoe UI Variable'
                    : 'Segoe UI'),
          ),

      // --- Navigation Pane (Win11 style) ---
      // compactWidth is set on NavigationPaneSize in the NavigationPane widget
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: shouldBeTransparent
            ? Colors.transparent
            : (isDark ? const Color(0xFF1A1C21) : const Color(0xFFF0F0F2)),
        overlayBackgroundColor: shouldBeTransparent
            ? (isDark
                  ? const Color(0xFF1A1C21).withValues(alpha: 0.8)
                  : const Color(0xFFF0F0F2).withValues(alpha: 0.8))
            : (isDark ? const Color(0xFF1A1C21) : const Color(0xFFF0F0F2)),
        highlightColor: primaryColor.withValues(alpha: 0.15),
        selectedIconColor: WidgetStateProperty.all(primaryColor),
        selectedTextStyle: WidgetStateProperty.all(
          TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        unselectedIconColor: WidgetStateProperty.all(
          isDark
              ? Colors.white.withValues(alpha: 0.55)
              : Colors.black.withValues(alpha: 0.45),
        ),
        unselectedTextStyle: WidgetStateProperty.all(
          TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.65)
                : Colors.black.withValues(alpha: 0.55),
          ),
        ),
        tileColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06);
          }
          if (states.isHovered) {
            return isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
      ),

      // --- Button theme: 4px radius (Win11), proper accent fill ---
      buttonTheme: ButtonThemeData(
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isDisabled) {
              return primaryColor.withValues(alpha: 0.4);
            }
            return primaryColor;
          }),
          foregroundColor: WidgetStateProperty.all(material.Colors.white),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          ),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(_kWin11RadiusSmall)),
            ),
          ),
        ),
        hyperlinkButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(primaryColor),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(_kWin11RadiusSmall)),
            ),
          ),
        ),
      ),

      // --- Checkbox: use decorations (no shape parameter on CheckboxThemeData) ---
      checkboxTheme: CheckboxThemeData(
        checkedIconColor: WidgetStateProperty.all(material.Colors.white),
      ),

      // --- Radio button ---
      radioButtonTheme: const RadioButtonThemeData(),

      // --- ToggleSwitch ---
      toggleSwitchTheme: const ToggleSwitchThemeData(),

      // --- Divider ---
      dividerTheme: const DividerThemeData(
        thickness: 1.0,
        horizontalMargin: EdgeInsetsDirectional.zero,
        verticalMargin: EdgeInsetsDirectional.zero,
      ),

      // --- Scrollbars (Win11 thin overlay style) ---
      scrollbarTheme: ScrollbarThemeData(
        thickness: 4.0,
        radius: const Radius.circular(2.0),
        scrollbarColor: isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.15),
        scrollbarPressingColor: isDark
            ? Colors.white.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.3),
      ),

      // --- InfoBar ---
      infoBarTheme: InfoBarThemeData(
        decoration: (severity) => BoxDecoration(
          borderRadius: BorderRadius.circular(_kWin11RadiusMedium),
        ),
      ),

      // --- ContentDialog ---
      dialogTheme: ContentDialogThemeData(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kWin11RadiusLarge),
        ),
      ),
    );
  }
}
