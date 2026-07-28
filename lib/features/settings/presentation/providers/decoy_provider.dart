import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/core/storage/secure_storage.dart';
import 'package:oasis/routes/app_router.dart';

class DecoyProvider with ChangeNotifier {
  static const String _decoyEnabledKey = 'is_decoy_enabled';
  static const String _decoyPinKey = 'decoy_pin';
  static const _channel = MethodChannel('oasis/stealth_mode');

  final PrefsStorage _prefsStorage;
  final SecureStorage _secureStorage;

  bool _isDecoyEnabled = false;
  bool _isUnlocked = false;

  DecoyProvider({
    PrefsStorage? prefsStorage,
    SecureStorage? secureStorage,
  }) : _prefsStorage = prefsStorage ?? PrefsStorage(),
       _secureStorage = secureStorage ?? SecureStorage() {
    _loadSettings();
  }

  bool get isDecoyEnabled => _isDecoyEnabled;
  bool get isUnlocked => _isUnlocked;

  void _loadSettings() {
    _isDecoyEnabled = _prefsStorage.readBool(_decoyEnabledKey) ?? false;
    // On load, the app is locked by default
    _isUnlocked = false;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(key: _decoyPinKey);
    return storedPin == pin;
  }

  Future<bool> enableDecoy(String pin) async {
    try {
      await _secureStorage.write(key: _decoyPinKey, value: pin);
      await _prefsStorage.writeBool(_decoyEnabledKey, true);
      _isDecoyEnabled = true;
      _isUnlocked = true; // Unlock for the current settings session
      notifyListeners();
      AppRouter.refresh();
      
      // Notify native platform
      try {
        await _channel.invokeMethod('setStealthMode', {'enable': true});
      } catch (e) {
        debugPrint('Platform channel setStealthMode(true) failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Failed to enable decoy mode: $e');
      return false;
    }
  }

  Future<bool> disableDecoy() async {
    try {
      await _secureStorage.delete(key: _decoyPinKey);
      await _prefsStorage.writeBool(_decoyEnabledKey, false);
      _isDecoyEnabled = false;
      _isUnlocked = false;
      notifyListeners();
      AppRouter.refresh();
      
      // Notify native platform
      try {
        await _channel.invokeMethod('setStealthMode', {'enable': false});
      } catch (e) {
        debugPrint('Platform channel setStealthMode(false) failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Failed to disable decoy mode: $e');
      return false;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final isCorrect = await verifyPin(oldPin);
    if (!isCorrect) return false;
    try {
      await _secureStorage.write(key: _decoyPinKey, value: newPin);
      return true;
    } catch (e) {
      debugPrint('Failed to change decoy pin: $e');
      return false;
    }
  }

  Future<bool> unlock(String pin) async {
    final success = await verifyPin(pin);
    if (success) {
      _isUnlocked = true;
      notifyListeners();
      AppRouter.refresh();
    }
    return success;
  }

  void lock() {
    if (_isDecoyEnabled && _isUnlocked) {
      _isUnlocked = false;
      notifyListeners();
      AppRouter.refresh();
    }
  }
}
