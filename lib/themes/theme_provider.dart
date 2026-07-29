import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/subscription_service.dart';

// Predefined color palette options
enum ColorPalette {
  none, // Uses default M3E colors
  emerald, // Green (current default)
  ocean, // Blue
  sunset, // Orange/Red
  lavender, // Purple
  rose, // Pink
  teal, // Teal
  // Pro-only vibrant palettes
  aurora, // Vibrant gradient cyan-pink (Pro only)
  wildfire, // Vibrant orange-yellow (Pro only)
  neonDreams, // Vibrant purple-magenta (Pro only)
  oceanDepths, // Deep vibrant blue (Pro only)
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _highContrast = false;
  bool _isM3EEnabled = true;
  bool _isM3ETransparencyDisabled = false;
  bool _useMaterialYou = false;
  ColorPalette _colorPalette = ColorPalette.none;
  static const String _themeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast';
  static const String _m3eKey = 'm3e_enabled';
  static const String _m3eTransparencyKey = 'm3e_transparency_disabled';
  static const String _materialYouKey = 'use_material_you';
  static const String _colorPaletteKey = 'color_palette';

  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  bool get isM3EEnabled => _isM3EEnabled;
  bool get isM3ETransparencyDisabled {
    // Force solid backgrounds on Desktop and Web for better readability/performance
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isMacOS) return true;
    } catch (_) {
      // Fallback if Platform is not available
    }
    return _isM3ETransparencyDisabled;
  }

  bool get useMaterialYou => _useMaterialYou;
  ColorPalette get colorPalette => _colorPalette;

  /// Check if the current platform should use Fluent UI (Windows or macOS)
  bool get useFluentUI {
    // Force Material on mobile platforms and WEB
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return false;

    // Only use Fluent UI on desktop OSs
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return true;
    return false;
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    _highContrast = prefs.getBool(_highContrastKey) ?? false;
    _isM3EEnabled = prefs.getBool(_m3eKey) ?? true;
    _isM3ETransparencyDisabled = prefs.getBool(_m3eTransparencyKey) ?? false;
    _useMaterialYou = prefs.getBool(_materialYouKey) ?? false;
    final paletteIndex =
        prefs.getInt(_colorPaletteKey) ?? ColorPalette.none.index;
    _colorPalette = ColorPalette.values[paletteIndex];
    notifyListeners();
  }

  Future<void> _syncToSupabase() async {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client
            .from('profiles')
            .update({'high_contrast': _highContrast})
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('ThemeProvider: Failed to sync to Supabase: $e');
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, value);
    notifyListeners();
    _syncToSupabase();
  }

  Future<void> setM3EEnabled(bool value) async {
    _isM3EEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_m3eKey, value);
    notifyListeners();
  }

  Future<void> setM3ETransparencyDisabled(bool value) async {
    _isM3ETransparencyDisabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_m3eTransparencyKey, value);
    notifyListeners();
  }

  Future<void> setMaterialYou(bool value) async {
    _useMaterialYou = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_materialYouKey, value);
    notifyListeners();
  }

  /// Check if a palette is Pro-only
  bool _isProPalette(ColorPalette palette) {
    return palette == ColorPalette.aurora ||
        palette == ColorPalette.wildfire ||
        palette == ColorPalette.neonDreams ||
        palette == ColorPalette.oceanDepths;
  }

  /// Check if user can use a palette (Pro-only for vibrant themes)
  bool canUsePalette(ColorPalette palette) {
    if (!_isProPalette(palette)) return true;
    return SubscriptionService().isPro;
  }

  Future<void> setColorPalette(ColorPalette palette) async {
    // Enforce Pro-only for vibrant palettes
    if (_isProPalette(palette) && !SubscriptionService().isPro) {
      debugPrint('[ThemeProvider] Pro palette requires Oasis Pro subscription');
      return;
    }
    _colorPalette = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorPaletteKey, palette.index);
    notifyListeners();
  }

  /// Generate a ColorScheme based on the selected palette, using rich shades of the theme color instead of black.
  ColorScheme getPaletteColorScheme(Brightness brightness) {
    final baseColor = _getPaletteBaseColor(_colorPalette);
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      final hsl = HSLColor.fromColor(baseColor);
      final double h = hsl.hue;
      // Ensure meaningful saturation even for near-zero-saturation colors like #0C0F14
      final double s = hsl.saturation.clamp(0.15, 0.50);

      // Use absolute lightness levels so these are never near-black.
      // Background: 10%  |  Card/Container: 15%  |  High: 20%  |  Highest: 24%
      final Color bg          = HSLColor.fromAHSL(1.0, h, s, 0.10).toColor();
      final Color surface     = HSLColor.fromAHSL(1.0, h, s, 0.10).toColor();
      final Color container   = HSLColor.fromAHSL(1.0, h, s, 0.15).toColor();
      final Color containerHi = HSLColor.fromAHSL(1.0, h, s, 0.20).toColor();
      final Color containerLo = HSLColor.fromAHSL(1.0, h, s, 0.08).toColor();
      final Color containerHiHi = HSLColor.fromAHSL(1.0, h, s, 0.24).toColor();

      // Bright, vivid accent colors so buttons/indicators stand out
      final double accentL = hsl.lightness < 0.5
          ? 0.65   // dark seeds → lift to 65%
          : hsl.lightness.clamp(0.60, 0.75);
      final double accentS = s.clamp(0.70, 0.95);
      final Color primaryColor   = HSLColor.fromAHSL(1.0, h, accentS, accentL).toColor();
      final Color secondaryColor = HSLColor.fromAHSL(1.0, (h + 30) % 360, accentS - 0.15, accentL - 0.10).toColor();

      return ColorScheme.fromSeed(
        seedColor: primaryColor, // Use the vibrant accent as seed, not the dark base
        brightness: brightness,
      ).copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surface,
        surfaceContainer: container,
        surfaceContainerLow: containerLo,
        surfaceContainerLowest: containerLo,
        surfaceContainerHigh: containerHi,
        surfaceContainerHighest: containerHiHi,
        // Ensure scaffoldBackgroundColor respects this too
        scrim: bg,
      );
    } else {
      final hsl = HSLColor.fromColor(baseColor);
      final double h = hsl.hue;
      final double s = hsl.saturation.clamp(0.04, 0.14);
      final Color surfaceColor          = HSLColor.fromAHSL(1.0, h, s, 0.97).toColor();
      final Color surfaceContainerColor = HSLColor.fromAHSL(1.0, h, s, 0.93).toColor();

      return ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: brightness,
      ).copyWith(
        surface: surfaceColor,
        surfaceContainer: surfaceContainerColor,
      );
    }
  }

  Color _getPaletteBaseColor(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return const Color(0xFF1A2235); // Deep blue-slate: enough hue/saturation to generate visible dark surfaces
      case ColorPalette.emerald:
        return const Color(0xFF1C6758); // Green
      case ColorPalette.ocean:
        return const Color(0xFF0D47A1); // Blue
      case ColorPalette.sunset:
        return const Color(0xFFE65100); // Orange/Red
      case ColorPalette.lavender:
        return const Color(0xFF7E57C2); // Purple
      case ColorPalette.rose:
        return const Color(0xFFC2185B); // Pink
      case ColorPalette.teal:
        return const Color(0xFF00796B); // Teal
      // Pro-only vibrant palettes
      case ColorPalette.aurora:
        return const Color(0xFF00D9FF); // Vibrant cyan-pink
      case ColorPalette.wildfire:
        return const Color(0xFFFF6B35); // Vibrant orange-yellow
      case ColorPalette.neonDreams:
        return const Color(0xFFB967FF); // Vibrant purple-magenta
      case ColorPalette.oceanDepths:
        return const Color(0xFF0066FF); // Deep vibrant blue
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setTheme(_themeMode);
  }
}
