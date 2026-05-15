import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/core/errors/app_exception.dart';
import 'package:oasis/models/feed_layout_strategy.dart';

class SettingsLocalDatasource {
  static const String _dataSaverKey = 'data_saver';
  static const String _fontSizeFactorKey = 'font_size_factor';
  static const String _highContrastKey = 'high_contrast';
  static const String _dailyLimitKey = 'daily_limit';
  static const String _windDownKey = 'wind_down_enabled';
  static const String _micaEnabledKey = 'mica_enabled';
  static const String _windowEffectKey = 'window_effect';
  static const String _fontFamilyKey = 'font_family';
  static const String _feedLayoutKey = 'feed_layout';

  Future<UserSettingsEntity> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final layoutName = prefs.getString(_feedLayoutKey);
      final feedLayout = FeedLayoutType.values.firstWhere(
        (e) => e.name == layoutName,
        orElse: () => FeedLayoutType.classic,
      );

      return UserSettingsEntity(
        dataSaver: prefs.getBool(_dataSaverKey) ?? false,
        fontSizeFactor: prefs.getDouble(_fontSizeFactorKey) ?? 1.0,
        highContrast: prefs.getBool(_highContrastKey) ?? false,
        dailyLimitMinutes: prefs.getInt(_dailyLimitKey) ?? 0,
        windDownEnabled: prefs.getBool(_windDownKey) ?? false,
        micaEnabled: prefs.getBool(_micaEnabledKey) ?? false,
        windowEffect: prefs.getString(_windowEffectKey) ?? 'mica',
        fontFamily: prefs.getString(_fontFamilyKey) ?? 'Comfortaa',
        feedLayout: feedLayout,
      );
    } catch (e) {
      throw StorageException('Failed to load settings', code: e.toString());
    }
  }

  Future<bool> saveSettings(UserSettingsEntity settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.setBool(_dataSaverKey, settings.dataSaver),
        prefs.setDouble(_fontSizeFactorKey, settings.fontSizeFactor),
        prefs.setBool(_highContrastKey, settings.highContrast),
        prefs.setInt(_dailyLimitKey, settings.dailyLimitMinutes),
        prefs.setBool(_windDownKey, settings.windDownEnabled),
        prefs.setBool(_micaEnabledKey, settings.micaEnabled),
        prefs.setString(_windowEffectKey, settings.windowEffect),
        prefs.setString(_fontFamilyKey, settings.fontFamily),
        prefs.setString(_feedLayoutKey, settings.feedLayout.name),
      ]);

      return true;
    } catch (e) {
      throw StorageException('Failed to save settings', code: e.toString());
    }
  }
}
