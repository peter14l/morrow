import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared preferences wrapper for non-sensitive app settings and cache.
///
/// Use this for: theme preferences, onboarding state, cached data,
/// feature flags, and other non-sensitive persistent settings.
///
/// For sensitive data (tokens, passwords), use [SecureStorage] instead.
class PrefsStorage {
  static PrefsStorage? _instance;
  SharedPreferences? _prefs;

  PrefsStorage._internal();

  /// Initialize the storage. Must be called before first use.
  static Future<PrefsStorage> init() async {
    _instance ??= PrefsStorage._internal();
    try {
      _instance!._prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('CRITICAL: SharedPreferences corruption detected: $e');
      if (e is FormatException) {
        debugPrint('Attempting to recover from corrupted preferences...');
        // On Windows, if the file is corrupted, getInstance() often fails.
        // We can't easily delete the file while the plugin is active,
        // but we can ensure the app doesn't crash by providing a mock/empty fallback
        // or re-attempting a clear if possible.
      }
      // Re-throw or handle based on app requirements.
      // For now, we allow the app to throw so the UI Safety Net can catch it.
      rethrow;
    }
    return _instance!;
  }

  factory PrefsStorage() {
    final instance = _instance;
    if (instance == null || instance._prefs == null) {
      throw StateError(
        'PrefsStorage not initialized. Call PrefsStorage.init() first.',
      );
    }
    return instance;
  }

  SharedPreferences get _prefsInstance => _prefs!;

  /// Read a string value. Returns null if not found.
  String? readString(String key) => _prefsInstance.getString(key);

  /// Read an int value. Returns null if not found.
  int? readInt(String key) => _prefsInstance.getInt(key);

  /// Read a double value. Returns null if not found.
  double? readDouble(String key) => _prefsInstance.getDouble(key);

  /// Read a bool value. Returns null if not found.
  bool? readBool(String key) => _prefsInstance.getBool(key);

  /// Read a list of strings. Returns null if not found.
  List<String>? readStringList(String key) => _prefsInstance.getStringList(key);

  /// Write a string value.
  Future<bool> writeString(String key, String value) =>
      _prefsInstance.setString(key, value);

  /// Write an int value.
  Future<bool> writeInt(String key, int value) =>
      _prefsInstance.setInt(key, value);

  /// Write a double value.
  Future<bool> writeDouble(String key, double value) =>
      _prefsInstance.setDouble(key, value);

  /// Write a bool value.
  Future<bool> writeBool(String key, bool value) =>
      _prefsInstance.setBool(key, value);

  /// Write a list of strings.
  Future<bool> writeStringList(String key, List<String> value) =>
      _prefsInstance.setStringList(key, value);

  /// Delete a value by key.
  Future<bool> delete(String key) => _prefsInstance.remove(key);

  /// Check if a key exists.
  bool contains(String key) => _prefsInstance.containsKey(key);

  /// Clear all stored values.
  Future<bool> clear() => _prefsInstance.clear();

  /// Get all keys.
  Set<String> get keys => _prefsInstance.getKeys();
}
