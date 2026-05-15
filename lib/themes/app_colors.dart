import 'package:flutter/material.dart';

// Light Theme Colors
class LightColors {
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color secondary = Color(0xFF10B981); // Emerald
  static const Color tertiary = Color(0xFFF59E0B); // Amber
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF212529);
  static const Color onSurface = Color(0xFF343A40);
  static const Color hint = Color(0xFF6C757D);
  static const Color error = Color(0xFFDC3545);
  static const Color border = Color(0xFFE9ECEF);
}

// Dark Theme Colors
class DarkColors {
  static const Color primary = Color(0xFF3B82F6); // Brighter Blue
  static const Color secondary = Color(0xFF34D399); // Brighter Emerald
  static const Color tertiary = Color(0xFFFBBF24); // Brighter Amber
  static const Color background = Color(0xFF111318);
  static const Color surface = Color(0xFF1A1D24);
  static const Color onBackground = Color(0xFFE9ECEF);
  static const Color onSurface = Color(0xFFDEE2E6);
  static const Color hint = Color(0xFF9DA6B9);
  static const Color error = Color(0xFFDC3545);
  static const Color border = Color(0xFF2D343A);
}

// Oasis "Organic Luxury" Palette
class OasisColors {
  static const Color deep = Color(0xFF0D1F1A); // Background / Scaffold
  static const Color moss = Color(0xFF1E3A2F); // Primary Surface
  static const Color sage = Color(0xFF3D6B55); // Secondary Surface / Borders
  static const Color mist = Color(0xFFA8C5B5); // Muted Text
  static const Color glow = Color(0xFF7FFFD4); // Accent / Primary Action
  static const Color sand = Color(0xFFE8D9C0); // Display Headings
  static const Color white = Color(0xFFF5F5F0); // Pure Text

  // Opacity variants for Glassmorphism
  static Color glassBackground = deep.withValues(alpha: 0.6);
  static Color glassBorder = glow.withValues(alpha: 0.1);
}

// Text Styles
class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );
}

// App Theme Extension
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color success;
  final Color warning;
  final Color info;
  final Color card;
  final Color divider;

  const AppThemeExtension({
    required this.success,
    required this.warning,
    required this.info,
    required this.card,
    required this.divider,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? card,
    Color? divider,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      card: card ?? this.card,
      divider: divider ?? this.divider,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      card: Color.lerp(card, other.card, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }

  // Light Theme
  static const light = AppThemeExtension(
    success: Color(0xFF28A745),
    warning: Color(0xFFFFC107),
    info: Color(0xFF17A2B8),
    card: Colors.white,
    divider: Color(0xFFE9ECEF),
  );

  // Dark Theme
  static const dark = AppThemeExtension(
    success: Color(0xFF51CF66),
    warning: Color(0xFFFFD43B),
    info: Color(0xFF3BC9DB),
    card: Color(0xFF1A1D24),
    divider: Color(0xFF2D343A),
  );
}

// Legacy Theme Data (kept for reference, use AppTheme in themes/app_theme.dart)
class LegacyAppTheme {
  static ThemeData get lightTheme {
    // Create text theme with proper styling
    final textTheme = TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(
        color: LightColors.onBackground,
      ),
      displayMedium: AppTextStyles.displayMedium.copyWith(
        color: LightColors.onBackground,
      ),
      titleLarge: AppTextStyles.titleLarge.copyWith(
        color: LightColors.onBackground,
      ),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: LightColors.onSurface),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(
        color: LightColors.onSurface,
      ),
      labelLarge: AppTextStyles.labelLarge.copyWith(
        color: LightColors.onBackground,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: LightColors.primary,
        surface: LightColors.background, // background -> surface
        onSurface: LightColors.onBackground, // onBackground -> onSurface
        error: LightColors.error,
      ),
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[AppThemeExtension.light],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LightColors.surface,
        hintStyle: const TextStyle(color: LightColors.hint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LightColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    // Create text theme with proper styling
    final textTheme = TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(
        color: DarkColors.onBackground,
      ),
      displayMedium: AppTextStyles.displayMedium.copyWith(
        color: DarkColors.onBackground,
      ),
      titleLarge: AppTextStyles.titleLarge.copyWith(
        color: DarkColors.onBackground,
      ),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: DarkColors.onSurface),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(
        color: DarkColors.onSurface,
      ),
      labelLarge: AppTextStyles.labelLarge.copyWith(
        color: DarkColors.onBackground,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: DarkColors.primary,
        surface: DarkColors.background, // background -> surface
        onSurface: DarkColors.onBackground, // onBackground -> onSurface
        error: DarkColors.error,
      ),
      textTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[AppThemeExtension.dark],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkColors.surface,
        hintStyle: const TextStyle(color: DarkColors.hint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DarkColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
