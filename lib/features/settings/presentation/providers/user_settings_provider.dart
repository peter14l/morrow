import 'package:flutter/foundation.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/domain/usecases/settings_usecases.dart';
import 'package:oasis/models/feed_layout_strategy.dart';
import 'package:oasis/services/desktop_window_service.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

class UserSettingsProvider with ChangeNotifier, SafeChangeNotifier {
  final GetSettingsUseCase _getSettingsUseCase;
  final SaveSettingsUseCase _saveSettingsUseCase;

  UserSettingsEntity _settings = const UserSettingsEntity();

  UserSettingsProvider({
    required GetSettingsUseCase getSettingsUseCase,
    required SaveSettingsUseCase saveSettingsUseCase,
  }) : _getSettingsUseCase = getSettingsUseCase,
       _saveSettingsUseCase = saveSettingsUseCase;

  bool get dataSaver => _settings.dataSaver;
  double get fontSizeFactor => _settings.fontSizeFactor;
  bool get highContrast => _settings.highContrast;
  int get dailyLimitMinutes => _settings.dailyLimitMinutes;
  bool get windDownEnabled => _settings.windDownEnabled;
  bool get micaEnabled => _settings.micaEnabled;
  String get windowEffect => _settings.windowEffect;
  String get fontFamily => _settings.fontFamily;
  FeedLayoutType get feedLayout => _settings.feedLayout;
  LiquidGlassMode get liquidGlassMode => _settings.liquidGlassMode;

  Future<void> loadSettings() async {
    final result = await _getSettingsUseCase();
    result.fold(
      onSuccess: (settings) {
        _settings = settings;
        notifyListeners();
      },
      onFailure: (error) {
        debugPrint('Failed to load settings: $error');
      },
    );
  }

  Future<void> _updateAndSave(UserSettingsEntity newSettings) async {
    // Optimistic update
    _settings = newSettings;
    notifyListeners();

    final result = await _saveSettingsUseCase(_settings);
    result.fold(
      onSuccess: (_) {}, // Already updated
      onFailure: (error) {
        debugPrint('Failed to save settings: $error');
        // We could revert here, but for simple settings we might just notify error via some mechanism
        // For now, load from disk again
        loadSettings();
      },
    );
  }

  Future<void> setMicaEnabled(bool value, {bool isDark = true}) async {
    await _updateAndSave(_settings.copyWith(micaEnabled: value));

    // Apply effect immediately on Windows
    if (!kIsWeb && Platform.isWindows) {
      await DesktopWindowService.instance.setWindowEffect(
        enabled: value,
        effect: _settings.windowEffect,
        isDark: isDark,
      );
    }
  }

  Future<void> setWindowEffect(String value, {bool isDark = true}) async {
    await _updateAndSave(_settings.copyWith(windowEffect: value));

    // Apply effect immediately on Windows
    if (!kIsWeb && Platform.isWindows) {
      await DesktopWindowService.instance.setWindowEffect(
        enabled: _settings.micaEnabled,
        effect: value,
        isDark: isDark,
      );
    }
  }

  Future<void> setDailyLimit(int minutes) async {
    await _updateAndSave(_settings.copyWith(dailyLimitMinutes: minutes));
  }

  Future<void> setWindDownEnabled(bool value) async {
    await _updateAndSave(_settings.copyWith(windDownEnabled: value));
  }

  Future<void> setDataSaver(bool value) async {
    await _updateAndSave(_settings.copyWith(dataSaver: value));
  }

  Future<void> setFontSizeFactor(double value) async {
    await _updateAndSave(_settings.copyWith(fontSizeFactor: value));
  }

  Future<void> setHighContrast(bool value) async {
    await _updateAndSave(_settings.copyWith(highContrast: value));
  }

  Future<void> setFontFamily(String value) async {
    await _updateAndSave(_settings.copyWith(fontFamily: value));
  }

  Future<void> setFeedLayout(FeedLayoutType layout) async {
    await _updateAndSave(_settings.copyWith(feedLayout: layout));
  }

  Future<void> setLiquidGlassMode(LiquidGlassMode mode) async {
    await _updateAndSave(_settings.copyWith(liquidGlassMode: mode));
  }
}
