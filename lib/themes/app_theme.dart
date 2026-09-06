import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:oasis/themes/app_colors.dart';

class AppTheme {
  // Make constructor private to prevent instantiation
  AppTheme._();

  // Helper method to get theme based on brightness
  static ThemeData getTheme(
    Brightness brightness, {
    bool isM3E = false,
    bool highContrast = false,
    bool micaEnabled = false,
    String? fontFamily,
    String? headingFontFamily,
    String? bodyFontFamily,
    ColorScheme? dynamicColorScheme,
  }) {
    if (highContrast) {
      return brightness == Brightness.dark
          ? highContrastDark(fontFamily: fontFamily ?? bodyFontFamily)
          : highContrastLight(fontFamily: fontFamily ?? bodyFontFamily);
    }
    if (isM3E) {
      return brightness == Brightness.dark
          ? m3eDark(
              headingFontFamily: headingFontFamily,
              bodyFontFamily: fontFamily ?? bodyFontFamily,
              dynamicColorScheme: dynamicColorScheme,
              micaEnabled: micaEnabled,
            )
          : m3eLight(
              headingFontFamily: headingFontFamily,
              bodyFontFamily: fontFamily ?? bodyFontFamily,
              dynamicColorScheme: dynamicColorScheme,
              micaEnabled: micaEnabled,
            );
    }
    return brightness == Brightness.dark
        ? dark(
            fontFamily: fontFamily ?? bodyFontFamily,
            dynamicColorScheme: dynamicColorScheme,
            micaEnabled: micaEnabled,
          )
        : light(
            fontFamily: fontFamily ?? bodyFontFamily,
            dynamicColorScheme: dynamicColorScheme,
            micaEnabled: micaEnabled,
          );
  }

  /// Harmonize dynamic color schemes (e.g. from Material You wallpaper extraction)
  /// into a beautiful multi-tonal scale with clear contrast steps between
  /// backgrounds, cards, sheets, elevated surfaces, borders, and vivid accents.
  static ColorScheme harmonizeDynamicColorScheme(
    ColorScheme rawScheme,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final primarySeed = rawScheme.primary;
    final hsl = HSLColor.fromColor(primarySeed);
    final double h = hsl.hue;

    if (isDark) {
      // Subtle wallpaper tint saturation for dark background surfaces
      final double s = hsl.saturation.clamp(0.12, 0.40);

      // Distinct tonal elevation steps in Dark Mode:
      // Background (8%) -> Sunken (6%) -> Section (11%) -> Card (15%) -> Elevated (19%) -> High Bar/Pill (24%)
      final Color bg = HSLColor.fromAHSL(1.0, h, s, 0.08).toColor();
      final Color surface = HSLColor.fromAHSL(1.0, h, s, 0.08).toColor();
      final Color containerLowest = HSLColor.fromAHSL(1.0, h, s, 0.06).toColor();
      final Color containerLo = HSLColor.fromAHSL(1.0, h, s, 0.11).toColor();
      final Color container = HSLColor.fromAHSL(1.0, h, s, 0.15).toColor();
      final Color containerHi = HSLColor.fromAHSL(1.0, h, s, 0.19).toColor();
      final Color containerHiHi = HSLColor.fromAHSL(1.0, h, s, 0.24).toColor();

      // High-vibrancy accents for buttons, icons, and indicators
      final double accentS = hsl.saturation.clamp(0.70, 0.95);
      final double accentL = hsl.lightness < 0.5 ? 0.68 : hsl.lightness.clamp(0.60, 0.78);
      final Color primaryColor = HSLColor.fromAHSL(1.0, h, accentS, accentL).toColor();
      final Color primaryContainer = HSLColor.fromAHSL(1.0, h, s.clamp(0.25, 0.55), 0.26).toColor();
      final Color onPrimaryContainer = HSLColor.fromAHSL(1.0, h, 0.85, 0.92).toColor();

      final Color secondaryColor = HSLColor.fromAHSL(
        1.0,
        (h + 25) % 360,
        accentS * 0.85,
        (accentL - 0.08).clamp(0.50, 0.75),
      ).toColor();
      final Color secondaryContainer = HSLColor.fromAHSL(
        1.0,
        (h + 25) % 360,
        s.clamp(0.20, 0.45),
        0.22,
      ).toColor();
      final Color onSecondaryContainer = HSLColor.fromAHSL(1.0, (h + 25) % 360, 0.80, 0.90).toColor();

      final Color tertiaryColor = HSLColor.fromAHSL(
        1.0,
        (h + 55) % 360,
        accentS * 0.90,
        accentL,
      ).toColor();

      final Color outline = HSLColor.fromAHSL(1.0, h, s * 0.6, 0.35).toColor();
      final Color outlineVariant = HSLColor.fromAHSL(1.0, h, s * 0.5, 0.22).toColor();

      return rawScheme.copyWith(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: const Color(0xFF001F2A),
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        onSecondary: const Color(0xFF001F2A),
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiaryColor,
        surface: surface,
        onSurface: Colors.white,
        onSurfaceVariant: HSLColor.fromAHSL(1.0, h, 0.15, 0.80).toColor(),
        surfaceContainerLowest: containerLowest,
        surfaceContainerLow: containerLo,
        surfaceContainer: container,
        surfaceContainerHigh: containerHi,
        surfaceContainerHighest: containerHiHi,
        outline: outline,
        outlineVariant: outlineVariant,
        scrim: bg,
      );
    } else {
      // Light Mode
      final double s = hsl.saturation.clamp(0.06, 0.20);

      // Distinct tonal elevation steps in Light Mode:
      // Scaffold (98%) -> Surface (97%) -> Inset Card (100% pure white) -> Section (95%) -> Card (92%) -> Elevated (88%) -> Bar/Pill (84%)
      final Color bg = HSLColor.fromAHSL(1.0, h, s, 0.98).toColor();
      final Color surface = HSLColor.fromAHSL(1.0, h, s, 0.97).toColor();
      final Color containerLowest = Colors.white;
      final Color containerLo = HSLColor.fromAHSL(1.0, h, s, 0.95).toColor();
      final Color container = HSLColor.fromAHSL(1.0, h, s, 0.92).toColor();
      final Color containerHi = HSLColor.fromAHSL(1.0, h, s, 0.88).toColor();
      final Color containerHiHi = HSLColor.fromAHSL(1.0, h, s, 0.84).toColor();

      final double accentS = hsl.saturation.clamp(0.70, 0.95);
      final Color primaryColor = HSLColor.fromAHSL(1.0, h, accentS, 0.38).toColor();
      final Color primaryContainer = HSLColor.fromAHSL(1.0, h, s.clamp(0.15, 0.45), 0.88).toColor();
      final Color onPrimaryContainer = HSLColor.fromAHSL(1.0, h, 0.90, 0.15).toColor();

      final Color secondaryColor = HSLColor.fromAHSL(
        1.0,
        (h + 25) % 360,
        accentS * 0.80,
        0.42,
      ).toColor();
      final Color secondaryContainer = HSLColor.fromAHSL(
        1.0,
        (h + 25) % 360,
        s.clamp(0.15, 0.40),
        0.88,
      ).toColor();
      final Color onSecondaryContainer = HSLColor.fromAHSL(1.0, (h + 25) % 360, 0.85, 0.18).toColor();

      final Color tertiaryColor = HSLColor.fromAHSL(
        1.0,
        (h + 55) % 360,
        accentS * 0.85,
        0.40,
      ).toColor();

      final Color outline = HSLColor.fromAHSL(1.0, h, s * 0.8, 0.55).toColor();
      final Color outlineVariant = HSLColor.fromAHSL(1.0, h, s * 0.6, 0.78).toColor();

      return rawScheme.copyWith(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiaryColor,
        surface: surface,
        onSurface: const Color(0xFF191C1E),
        onSurfaceVariant: HSLColor.fromAHSL(1.0, h, 0.15, 0.35).toColor(),
        surfaceContainerLowest: containerLowest,
        surfaceContainerLow: containerLo,
        surfaceContainer: container,
        surfaceContainerHigh: containerHi,
        surfaceContainerHighest: containerHiHi,
        outline: outline,
        outlineVariant: outlineVariant,
        scrim: bg,
      );
    }
  }

  static ThemeData light({
    String? fontFamily,
    ColorScheme? dynamicColorScheme,
    bool micaEnabled = false,
  }) => _createTheme(
    Brightness.light,
    false,
    null,
    fontFamily,
    dynamicColorScheme,
    micaEnabled: micaEnabled,
  );
  static ThemeData dark({
    String? fontFamily,
    ColorScheme? dynamicColorScheme,
    bool micaEnabled = false,
  }) => _createTheme(
    Brightness.dark,
    false,
    null,
    fontFamily,
    dynamicColorScheme,
    micaEnabled: micaEnabled,
  );
  static ThemeData m3eLight({
    String? headingFontFamily,
    String? bodyFontFamily,
    ColorScheme? dynamicColorScheme,
    bool micaEnabled = false,
  }) => _createTheme(
    Brightness.light,
    true,
    headingFontFamily,
    bodyFontFamily,
    dynamicColorScheme,
    micaEnabled: micaEnabled,
  );
  static ThemeData m3eDark({
    String? headingFontFamily,
    String? bodyFontFamily,
    ColorScheme? dynamicColorScheme,
    bool micaEnabled = false,
  }) => _createTheme(
    Brightness.dark,
    true,
    headingFontFamily,
    bodyFontFamily,
    dynamicColorScheme,
    micaEnabled: micaEnabled,
  );

  static ThemeData highContrastLight({String? fontFamily}) {
    final theme = light(fontFamily: fontFamily);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
    );
  }

  static ThemeData highContrastDark({String? fontFamily}) {
    final theme = dark(fontFamily: fontFamily);
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: Colors.white,
        onPrimary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
    );
  }

  static TextStyle _getTextStyle({
    required String? fontFamily,
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    Color? color,
    double? height,
    bool isItalic = false,
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
    );

    if (fontFamily == null || fontFamily.isEmpty || fontFamily == 'System') {
      return style;
    }

    try {
      // Mapping for names to Google Font equivalents
      String googleFontName = fontFamily;
      if (fontFamily == 'Times New Roman') googleFontName = 'Tinos';
      if (fontFamily == 'Arial') googleFontName = 'Arimo';
      if (fontFamily == 'Garamond') googleFontName = 'EB Garamond';
      if (fontFamily == 'Courier New') googleFontName = 'Courier Prime';
      if (fontFamily == 'Comic Sans') googleFontName = 'Comic Neue';
      if (fontFamily == 'Lucida Console') googleFontName = 'Inconsolata';
      if (fontFamily == 'Monaco') googleFontName = 'Cousine';

      return GoogleFonts.getFont(googleFontName, textStyle: style);
    } catch (e) {
      debugPrint('Error loading font $fontFamily: $e');
      // If Google Fonts fail (or font isn't a Google Font like Verdana/Georgia/Open Dyslexic),
      // use the fontFamily name directly for system/asset fonts.
      return style.copyWith(fontFamily: fontFamily);
    }
  }

  static ThemeData _createTheme(
    Brightness brightness,
    bool isM3E,
    String? headingFont,
    String? bodyFont,
    ColorScheme? dynamicColorScheme, {
    bool micaEnabled = false,
  }) {
    final isDark = brightness == Brightness.dark;

    // Oasis default fonts
    final defaultHeadingFont = headingFont ?? 'Cormorant Garamond';
    final defaultBodyFont = bodyFont ?? 'Inter';

    // Base colors for transparency
    final Color micaBase = isDark
        ? Colors.black
        : Colors.white;
    final Color micaTint = micaBase.withValues(alpha: isDark ? 0.3 : 0.5);
    final Color micaSurface = micaBase.withValues(alpha: 0.01);

    if (isM3E) {
      var colorScheme = isDark ? m3eDarkColorScheme : m3eLightColorScheme;
      final bool hasDynamicColor = dynamicColorScheme != null;
      if (hasDynamicColor) {
        colorScheme = dynamicColorScheme;
      }

      if (micaEnabled) {
        colorScheme = colorScheme.copyWith(
          surface: micaSurface,
          surfaceContainer: micaTint,
          surfaceContainerHigh: micaTint,
          surfaceContainerHighest: micaTint,
          surfaceContainerLow: micaTint,
          surfaceContainerLowest: micaTint,
        );
      }

      final textTheme = m3eTextTheme(
        colorScheme.onSurface,
        defaultHeadingFont,
        defaultBodyFont,
      );

      // Determine surface colors
      final Color scaffoldBackground = micaEnabled
          ? micaSurface
          : (hasDynamicColor
                ? colorScheme.surface
                : (isDark ? OasisColors.deep : _m3eLightSurface));

      final Color navigationBarBackground = micaEnabled
          ? micaTint
          : (hasDynamicColor
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
                : (isDark
                      ? OasisColors.deep.withValues(alpha: 0.6)
                      : _m3eLightSurfaceContainer));

      final Color cardColor = micaEnabled
          ? micaTint
          : (hasDynamicColor
                ? colorScheme.surfaceContainer
                : (isDark ? OasisColors.moss : _m3eLightSurfaceContainerLow));

      final Color appBarBackground = micaEnabled
          ? micaSurface
          : (hasDynamicColor
                ? colorScheme.surface.withValues(alpha: 0.85)
                : (isDark
                      ? OasisColors.deep.withValues(alpha: 0.6)
                      : _m3eLightSurface));

      final Color inputFillColor = micaEnabled
          ? micaTint
          : (hasDynamicColor
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                : (isDark
                      ? OasisColors.moss.withValues(alpha: 0.5)
                      : _m3eLightSurfaceContainerLow));

      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: colorScheme,
        textTheme: textTheme,
        scaffoldBackgroundColor: scaffoldBackground,
        canvasColor: micaEnabled ? micaSurface : scaffoldBackground,
        snackBarTheme: SnackBarThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          contentTextStyle: _getTextStyle(
            fontFamily: defaultBodyFont,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
          actionTextColor: colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: _getTextStyle(
              fontFamily: defaultBodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.primary,
            side: BorderSide(color: colorScheme.outline, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: _getTextStyle(
              fontFamily: defaultBodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: const StadiumBorder(),
            textStyle: _getTextStyle(
              fontFamily: defaultBodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: navigationBarBackground,
          indicatorColor: hasDynamicColor
              ? colorScheme.secondaryContainer
              : (isDark ? OasisColors.moss : _m3eLightSecondaryContainer),
          indicatorShape: const StadiumBorder(),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final color = states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant;
            return _getTextStyle(
              fontFamily: defaultBodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            );
          }),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0), // Oasis large radius
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          color: cardColor,
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: appBarBackground,
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: _getTextStyle(
            fontFamily: defaultHeadingFont,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
            isItalic: true,
          ),
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          // Use colorScheme.surfaceContainer — dynamically set by HSL palette,
          // guaranteed to be visible (never transparent or pitch black).
          backgroundColor: colorScheme.surfaceContainer,
          surfaceTintColor: Colors.transparent,
          modalBackgroundColor: colorScheme.surfaceContainer,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: colorScheme.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: _getTextStyle(
            fontFamily: defaultBodyFont,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          labelStyle: _getTextStyle(
            fontFamily: defaultBodyFont,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurfaceVariant,
          ),
          errorStyle: _getTextStyle(
            fontFamily: defaultBodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colorScheme.error,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          },
        ),
        extensions: [isDark ? AppThemeExtension.dark : AppThemeExtension.light],
      );
    }

    var colorScheme = isDark ? darkColorScheme : lightColorScheme;
    final bool hasDynamicColor = dynamicColorScheme != null;
    if (hasDynamicColor) {
      colorScheme = dynamicColorScheme;
    }

    if (micaEnabled) {
      colorScheme = colorScheme.copyWith(
        surface: micaSurface,
        surfaceContainer: micaTint,
        surfaceContainerHigh: micaTint,
        surfaceContainerHighest: micaTint,
        surfaceContainerLow: micaTint,
        surfaceContainerLowest: micaTint,
      );
    }

    final textTheme = standardTextTheme(
      colorScheme.onSurface,
      defaultHeadingFont,
      defaultBodyFont,
    );

    // Determine surface colors
    final Color scaffoldBackground = micaEnabled
        ? micaSurface
        : (hasDynamicColor
              ? colorScheme.surface
              : (isDark ? OasisColors.deep : _lightBackgroundColor));

    final Color appBarBackground = micaEnabled
        ? micaSurface
        : (hasDynamicColor
              ? colorScheme.surface.withValues(alpha: 0.85)
              : (isDark
                    ? OasisColors.deep.withValues(alpha: 0.6)
                    : _lightBackgroundColor));

    final Color cardColor = micaEnabled
        ? micaTint
        : (hasDynamicColor
              ? colorScheme.surfaceContainer
              : (isDark ? OasisColors.moss : _lightSurfaceColor));

    final Color inputFillColor = micaEnabled
        ? micaTint
        : (hasDynamicColor
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : ((isDark ? OasisColors.moss : _lightSurfaceColor).withValues(
                  alpha: isDark ? 0.6 : 0.3,
                )));

    final Color navigationBarBackground = micaEnabled
        ? micaTint
        : (hasDynamicColor
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
              : (isDark
                    ? OasisColors.deep.withValues(alpha: 0.6)
                    : Colors.transparent));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: micaEnabled ? micaSurface : scaffoldBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBarBackground,
        foregroundColor: hasDynamicColor
            ? colorScheme.onSurface
            : (isDark ? OasisColors.white : _lightOnSurfaceColor),
        titleTextStyle: _getTextStyle(
          fontFamily: defaultHeadingFont,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: hasDynamicColor
              ? colorScheme.onSurface
              : (isDark ? OasisColors.white : _lightOnSurfaceColor),
          isItalic: true,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainer,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? OasisColors.sage.withValues(alpha: 0.5)
                : _lightSurfaceColor,
          ),
        ),
        color: cardColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: _getTextStyle(
          fontFamily: defaultBodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        labelStyle: _getTextStyle(
          fontFamily: defaultBodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface.withValues(alpha: 0.9),
        ),
        errorStyle: _getTextStyle(
          fontFamily: defaultBodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: colorScheme.error,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: hasDynamicColor
            ? colorScheme.primaryContainer.withValues(
                alpha: isDark ? 0.2 : 0.12,
              )
            : ((isDark ? OasisColors.glow : _lightPrimaryColor).withValues(
                alpha: isDark ? 0.2 : 0.12,
              )),
        backgroundColor: navigationBarBackground,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant;
          return _getTextStyle(
            fontFamily: defaultBodyFont,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: _getTextStyle(
          fontFamily: defaultBodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      extensions: [isDark ? AppThemeExtension.dark : AppThemeExtension.light],
    );
  }

  // M3E Text Theme
  static TextTheme m3eTextTheme(
    Color color,
    String? headingFont,
    String? bodyFont,
  ) => TextTheme(
    displayLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: color,
      height: 1.12,
      isItalic: true,
    ),
    displayMedium: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.15,
      isItalic: true,
    ),
    displaySmall: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.22,
      isItalic: true,
    ),
    headlineLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color,
      height: 1.25,
      isItalic: true,
    ),
    headlineMedium: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color,
      height: 1.28,
      isItalic: true,
    ),
    headlineSmall: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color,
      height: 1.33,
      isItalic: true,
    ),
    titleLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 22,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: color,
      height: 1.27,
    ),
    titleMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: color,
      height: 1.5,
    ),
    titleSmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: color,
      height: 1.42,
    ),
    bodyLarge: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: color.withValues(alpha: 0.8),
      height: 1.5,
    ),
    bodyMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: color.withValues(alpha: 0.8),
      height: 1.42,
    ),
    bodySmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: color.withValues(alpha: 0.6),
      height: 1.33,
    ),
    labelLarge: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: color,
      height: 1.42,
    ),
    labelMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.33,
    ),
    labelSmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.45,
    ),
  );

  static TextTheme standardTextTheme(
    Color color,
    String? headingFont,
    String? bodyFont,
  ) => TextTheme(
    displayLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 57,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
      color: color,
      height: 1.12,
      isItalic: true,
    ),
    displayMedium: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 45,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.15,
      isItalic: true,
    ),
    displaySmall: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 36,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.22,
      isItalic: true,
    ),
    headlineLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 32,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.25,
      isItalic: true,
    ),
    headlineMedium: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.28,
      isItalic: true,
    ),
    headlineSmall: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.33,
      isItalic: true,
    ),
    titleLarge: _getTextStyle(
      fontFamily: headingFont,
      fontSize: 22,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: color,
      height: 1.27,
    ),
    titleMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      color: color,
      height: 1.5,
    ),
    titleSmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: color,
      height: 1.42,
    ),
    bodyLarge: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      color: color,
      height: 1.5,
    ),
    bodyMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: color,
      height: 1.42,
    ),
    bodySmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: color,
      height: 1.33,
    ),
    labelLarge: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: color,
      height: 1.42,
    ),
    labelMedium: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.33,
    ),
    labelSmall: _getTextStyle(
      fontFamily: bodyFont,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: color,
      height: 1.45,
    ),
  );

  // M3E Colors - Light
  static const Color _m3eLightPrimary = Color(0xFF6750A4);
  static const Color _m3eLightOnPrimary = Color(0xFFFFFFFF);
  static const Color _m3eLightPrimaryContainer = Color(0xFFEADDFF);
  static const Color _m3eLightOnPrimaryContainer = Color(0xFF21005D);
  static const Color _m3eLightSecondary = Color(0xFF625B71);
  static const Color _m3eLightOnSecondary = Color(0xFFFFFFFF);
  static const Color _m3eLightSecondaryContainer = Color(0xFFE8DEF8);
  static const Color _m3eLightOnSecondaryContainer = Color(0xFF1D192B);
  static const Color _m3eLightTertiary = Color(0xFF7D5260);
  static const Color _m3eLightOnTertiary = Color(0xFFFFFFFF);
  static const Color _m3eLightTertiaryContainer = Color(0xFFFFD8E4);
  static const Color _m3eLightOnTertiaryContainer = Color(0xFF31111D);
  static const Color _m3eLightError = Color(0xFFB3261E);
  static const Color _m3eLightOnError = Color(0xFFFFFFFF);
  static const Color _m3eLightErrorContainer = Color(0xFFF9DEDC);
  static const Color _m3eLightOnErrorContainer = Color(0xFF410E0B);
  static const Color _m3eLightSurface = Color(0xFFFEF7FF);
  static const Color _m3eLightOnSurface = Color(0xFF1D1B20);
  static const Color _m3eLightSurfaceDim = Color(0xFFDED8E1);
  static const Color _m3eLightSurfaceBright = Color(0xFFFEF7FF);
  static const Color _m3eLightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _m3eLightSurfaceContainerLow = Color(0xFFF7F2FA);
  static const Color _m3eLightSurfaceContainer = Color(0xFFF3EDF7);
  static const Color _m3eLightSurfaceContainerHigh = Color(0xFFECE6F0);
  static const Color _m3eLightSurfaceContainerHighest = Color(0xFFE6E0E9);
  static const Color _m3eLightOnSurfaceVariant = Color(0xFF49454F);
  static const Color _m3eLightOutline = Color(0xFF79747E);
  static const Color _m3eLightOutlineVariant = Color(0xFFCAC4D0);
  static const Color _m3eLightInverseSurface = Color(0xFF322F35);
  static const Color _m3eLightInverseOnSurface = Color(0xFFF5EFF7);
  static const Color _m3eLightInversePrimary = Color(0xFFD0BCFF);
  static const Color _m3eLightShadow = Color(0xFF000000);
  static const Color _m3eLightScrim = Color(0xFF000000);
  static const Color _m3eLightSurfaceTint = Color(0xFF6750A4);

  static const ColorScheme m3eLightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _m3eLightPrimary,
    onPrimary: _m3eLightOnPrimary,
    primaryContainer: _m3eLightPrimaryContainer,
    onPrimaryContainer: Colors
        .black, // Changed from _m3eLightOnPrimaryContainer for better readability
    secondary: _m3eLightSecondary,
    onSecondary: _m3eLightOnSecondary,
    secondaryContainer: _m3eLightSecondaryContainer,
    onSecondaryContainer:
        Colors.black, // Changed from _m3eLightOnSecondaryContainer
    tertiary: _m3eLightTertiary,
    onTertiary: _m3eLightOnTertiary,
    tertiaryContainer: _m3eLightTertiaryContainer,
    onTertiaryContainer:
        Colors.black, // Changed from _m3eLightOnTertiaryContainer
    error: _m3eLightError,
    onError: _m3eLightOnError,
    errorContainer: _m3eLightErrorContainer,
    onErrorContainer: _m3eLightOnErrorContainer,
    surface: _m3eLightSurface,
    surfaceContainerLowest: _m3eLightSurfaceContainerLowest,
    surfaceContainerLow: _m3eLightSurfaceContainerLow,
    surfaceContainer: _m3eLightSurfaceContainer,
    surfaceContainerHigh: _m3eLightSurfaceContainerHigh,
    surfaceContainerHighest: _m3eLightSurfaceContainerHighest,
    onSurface: _m3eLightOnSurface,
    outline: _m3eLightOutline,
    outlineVariant: _m3eLightOutlineVariant,
  );

  // M3E Colors - Dark (Oasis Palette)
  static const Color _m3eDarkPrimary = OasisColors.glow;
  static const Color _m3eDarkOnPrimary = OasisColors.deep;
  static const Color _m3eDarkPrimaryContainer = OasisColors.moss;
  static const Color _m3eDarkOnPrimaryContainer = OasisColors.white;
  static const Color _m3eDarkSecondary = OasisColors.sage;
  static const Color _m3eDarkOnSecondary = OasisColors.white;
  static const Color _m3eDarkSecondaryContainer = OasisColors.moss;
  static const Color _m3eDarkOnSecondaryContainer = OasisColors.sand;
  static const Color _m3eDarkTertiary = OasisColors.sand;
  static const Color _m3eDarkOnTertiary = OasisColors.deep;
  static const Color _m3eDarkTertiaryContainer = OasisColors.moss;
  static const Color _m3eDarkOnTertiaryContainer = OasisColors.sand;
  static const Color _m3eDarkError = Color(0xFFF2B8B5);
  static const Color _m3eDarkOnError = Color(0xFF601410);
  static const Color _m3eDarkErrorContainer = Color(0xFF8C1D18);
  static const Color _m3eDarkOnErrorContainer = Color(0xFFF9DEDC);
  static const Color _m3eDarkSurface = OasisColors.deep;
  static const Color _m3eDarkOnSurface = OasisColors.white;
  static const Color _m3eDarkSurfaceDim = OasisColors.deep;
  static const Color _m3eDarkSurfaceBright = OasisColors.moss;
  static const Color _m3eDarkSurfaceContainerLowest = Color(0xFF0F0D13);
  static const Color _m3eDarkSurfaceContainerLow = OasisColors.deep;
  static const Color _m3eDarkSurfaceContainer = OasisColors.moss;
  static const Color _m3eDarkSurfaceContainerHigh = OasisColors.sage;
  static const Color _m3eDarkSurfaceContainerHighest = OasisColors.sage;
  static const Color _m3eDarkOnSurfaceVariant = OasisColors.mist;
  static const Color _m3eDarkOutline = OasisColors.sage;
  static const Color _m3eDarkOutlineVariant = OasisColors.moss;
  static const Color _m3eDarkInverseSurface = OasisColors.white;
  static const Color _m3eDarkInverseOnSurface = OasisColors.deep;
  static const Color _m3eDarkInversePrimary = OasisColors.glow;
  static const Color _m3eDarkShadow = Color(0xFF000000);
  static const Color _m3eDarkScrim = Color(0xFF000000);
  static const Color _m3eDarkSurfaceTint = OasisColors.glow;

  static const ColorScheme m3eDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _m3eDarkPrimary,
    onPrimary: _m3eDarkOnPrimary,
    primaryContainer: _m3eDarkPrimaryContainer,
    onPrimaryContainer: _m3eDarkOnPrimaryContainer,
    secondary: _m3eDarkSecondary,
    onSecondary: _m3eDarkOnSecondary,
    secondaryContainer: _m3eDarkSecondaryContainer,
    onSecondaryContainer: _m3eDarkOnSecondaryContainer,
    tertiary: _m3eDarkTertiary,
    onTertiary: _m3eDarkOnTertiary,
    tertiaryContainer: _m3eDarkTertiaryContainer,
    onTertiaryContainer: _m3eDarkOnTertiaryContainer,
    error: _m3eDarkError,
    onError: _m3eDarkOnError,
    errorContainer: _m3eDarkErrorContainer,
    onErrorContainer: _m3eDarkOnErrorContainer,
    surface: _m3eDarkSurface,
    surfaceContainerLowest: _m3eDarkSurfaceContainerLowest,
    surfaceContainerLow: _m3eDarkSurfaceContainerLow,
    surfaceContainer: _m3eDarkSurfaceContainer,
    surfaceContainerHigh: _m3eDarkSurfaceContainerHigh,
    surfaceContainerHighest: _m3eDarkSurfaceContainerHighest,
    onSurface: _m3eDarkOnSurface,
    outline: _m3eDarkOutline,
    outlineVariant: _m3eDarkOutlineVariant,
  );

  // Standard Colors
  static const Color _lightPrimaryColor = Color(0xFF1C6758);
  static const Color _lightSecondaryColor = Color(0xFF3D8361);
  static const Color _lightTertiaryColor = Color(0xFFD6CDA4);
  static const Color _lightBackgroundColor = Color(0xFFEEF2E6);
  static const Color _lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color _lightOnSurfaceColor = Color(0xFF000000);
  static const Color _lightOnSurfaceVariantColor = Color(0xFF44474E);
  static const Color _lightErrorColor = Color(0xFFBA1A1A);

  static const Color _darkPrimaryColor = Color(0xFF5ED4BB);
  static const Color _darkSecondaryColor = Color(0xFF81C784);
  static const Color _darkTertiaryColor = Color(0xFFE6EE9C);
  static const Color _darkBackgroundColor = Color(0xFF0C0F14);
  static const Color _darkSurfaceColor = Color(0xFF131720);
  static const Color _darkOnSurfaceColor = Color(0xFFE2E2E6);
  static const Color _darkOnSurfaceVariantColor = Color(0xFFC4C6D0);
  static const Color _darkSurfaceVariant = Color(0xFF1D2125);
  static const Color _darkErrorColor = Color(0xFFFFB4AB);

  static const double m3eShapeExtraSmall = 4.0;
  static const double m3eShapeSmall = 8.0;
  static const double m3eShapeMedium = 12.0;
  static const double m3eShapeLarge = 16.0;
  static const double m3eShapeExtraLarge = 28.0;

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _lightPrimaryColor,
    onPrimary: Colors.white,
    secondary: _lightSecondaryColor,
    onSecondary: Colors.white,
    surface: _lightBackgroundColor,
    onSurface: _lightOnSurfaceColor,
    error: _lightErrorColor,
    onError: Colors.white,
    onPrimaryContainer: Colors.black, // Added for clarity
    onSecondaryContainer: Colors.black,
    onTertiaryContainer: Colors.black,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _darkPrimaryColor,
    onPrimary: Colors.black,
    secondary: _darkSecondaryColor,
    onSecondary: Colors.black,
    surface: _darkBackgroundColor,
    onSurface: _darkOnSurfaceColor,
    error: _darkErrorColor,
    onError: Colors.black,
  );
}
