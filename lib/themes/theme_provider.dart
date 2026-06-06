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

  /// Generate a ColorScheme based on the selected palette
  ColorScheme? getPaletteColorScheme(Brightness brightness) {
    if (_colorPalette == ColorPalette.none) return null;

    final isDark = brightness == Brightness.dark;
    final baseColor = _getPaletteBaseColor(_colorPalette);

    return ColorScheme.fromSeed(seedColor: baseColor, brightness: brightness);
  }

  Color _getPaletteBaseColor(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return const Color(0xFF6750A4); // Default purple (M3 standard)
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
