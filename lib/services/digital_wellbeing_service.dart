import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/subscription_service.dart';

class DigitalWellbeingService extends ChangeNotifier {
  static const String _lockoutThresholdKey = 'wellbeing_lockout_threshold';
  static const String _lockoutEndTimeKey = 'wellbeing_lockout_end_time';
  static const String _lastOverspendKey = 'wellbeing_last_overspend';

  final SharedPreferences _prefs;
  final AuthService _authService;

  // Session trackers (seconds) - reset to 0 on background/close
  int _feedSeconds = 0;
  int _ripplesSeconds = 0;
  Timer? _ticker;
  int _tickCount = 0;

  // Lockout state
  DateTime? _lockoutEndTime;

  DigitalWellbeingService(this._prefs, this._authService) {
    _loadState();
  }

  void _loadState() {
    final endTimeStr = _prefs.getString(_lockoutEndTimeKey);
    if (endTimeStr != null) {
      _lockoutEndTime = DateTime.parse(endTimeStr);
      if (_lockoutEndTime!.isBefore(DateTime.now())) {
        _lockoutEndTime = null;
      }
    }
  }

  // --- Tracking ---

  void startTracking(String category) {
    _ticker?.cancel();
    _tickCount = 0;
    // Use 5-second interval (80% reduction in CPU) + batch threshold checks
    _ticker = Timer.periodic(const Duration(seconds: 5), (timer) {
      _tickCount++;
      if (category == 'feed') {
        _feedSeconds += 5;
      } else if (category == 'ripples') {
        _ripplesSeconds += 5;
      }

      // Check lockout every 5 seconds (not every second)
      _checkLockoutThreshold();
      // Only notify every 3rd tick (every 15 seconds) to reduce UI rebuilds
      if (_tickCount % 3 == 0) {
        notifyListeners();
      }
    });
  }

  void stopTracking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void resetSession() {
    _feedSeconds = 0;
    _ripplesSeconds = 0;
    stopTracking();
    notifyListeners();
    debugPrint('DigitalWellbeing: Session reset');
  }

  // --- Lockout Logic ---

  int get lockoutThresholdMinutes {
    if (!_isUserPro()) return 60;
    return _prefs.getInt(_lockoutThresholdKey) ?? 60;
  }

  Future<void> setLockoutThreshold(int minutes) async {
    if (!_isUserPro()) return;
    final capped = minutes.clamp(60, 180);
    await _prefs.setInt(_lockoutThresholdKey, capped);
    notifyListeners();
  }

  void _checkLockoutThreshold() {
    if (isLockedOut) return;

    final totalSeconds = _feedSeconds + _ripplesSeconds;
    final thresholdSeconds = lockoutThresholdMinutes * 60;

    if (totalSeconds >= thresholdSeconds) {
      _triggerLockout(totalSeconds - thresholdSeconds);
    }
  }

  void _triggerLockout(int overspendSeconds) {
    // Adapted lockout: 60 mins base + overspend
    final lockoutDuration =
        const Duration(minutes: 60) + Duration(seconds: overspendSeconds);
    _lockoutEndTime = DateTime.now().add(lockoutDuration);

    _prefs.setString(_lockoutEndTimeKey, _lockoutEndTime!.toIso8601String());
    _prefs.setInt(_lastOverspendKey, overspendSeconds);

    stopTracking();
    notifyListeners();
    debugPrint('DigitalWellbeing: Lockout triggered until $_lockoutEndTime');
  }

  bool get isLockedOut {
    if (_lockoutEndTime == null) return false;
    if (_lockoutEndTime!.isBefore(DateTime.now())) {
      _lockoutEndTime = null;
      _prefs.remove(_lockoutEndTimeKey);
      notifyListeners();
      return false;
    }
    return true;
  }

  bool get isLimitReached {
    final totalSeconds = _feedSeconds + _ripplesSeconds;
    final thresholdSeconds = lockoutThresholdMinutes * 60;
    return totalSeconds >= thresholdSeconds;
  }

  Duration get remainingLockoutTime {
    if (_lockoutEndTime == null) return Duration.zero;
    final diff = _lockoutEndTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // --- Getters ---

  int get feedMinutes => _feedSeconds ~/ 60;
  int get ripplesMinutes => _ripplesSeconds ~/ 60;
  int get totalMinutes => (_feedSeconds + _ripplesSeconds) ~/ 60;

  int get feedSeconds => _feedSeconds;
  int get ripplesSeconds => _ripplesSeconds;
  int get totalSeconds => _feedSeconds + _ripplesSeconds;

  // --- UI Decay Nudges ---

  double get saturationFactor {
    final total = totalSeconds;
    final threshold = lockoutThresholdMinutes * 60;

    // Start desaturating at 80% of threshold
    if (total < threshold * 0.8) return 1.0;

    // Linearly decrease from 1.0 to 0.2
    final progress = (total - (threshold * 0.8)) / (threshold * 0.2);
    return (1.0 - (progress * 0.8)).clamp(0.2, 1.0);
  }

  double get blurSigma {
    final total = totalSeconds;
    final threshold = lockoutThresholdMinutes * 60;

    // Start blurring at 90% of threshold
    if (total < threshold * 0.9) return 0.0;

    // Linearly increase from 0 to 3.0
    final progress = (total - (threshold * 0.9)) / (threshold * 0.1);
    return (progress * 3.0).clamp(0.0, 3.0);
  }

  bool _isUserPro() {
    return SubscriptionService().isPro;
  }

  static Future<DigitalWellbeingService> init(AuthService authService) async {
    final prefs = await SharedPreferences.getInstance();
    return DigitalWellbeingService(prefs, authService);
  }
}
