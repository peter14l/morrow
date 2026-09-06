import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:oasis/services/subscription_service.dart';

/// Clean, minimal focus and screen-time wellness service
class WellnessService extends ChangeNotifier {
  static const String _zenModeKey = 'zen_mode_enabled';
  static const String _zenModeScheduleKey = 'zen_mode_schedule';
  static const String _allowCallsDuringZenKey = 'allow_calls_during_zen';
  static const String _windDownEnabledKey = 'wind_down_enabled';
  static const String _windDownTimeKey = 'wind_down_time';
  static const String _blockedFeaturesKey = 'focus_blocked_features';
  static const String _dailyGoalKey = 'daily_usage_goal';

  final SharedPreferences _prefs;
  Timer? _windDownTimer;

  // Zen Mode
  bool _zenModeEnabled = false;
  bool _allowCallsDuringZen = true;
  DateTime? _zenStartTime;
  Timer? _zenTimer;
  int _zenRemainingSeconds = 0;
  static const int _zenSessionDurationMinutes = 30;
  static const int _zenRewardXP = 50;
  static const int _zenPenaltyXP = 35;

  Map<String, bool> _zenSchedule = {};
  Set<String> _blockedFeatures = {};

  // Wind Down Mode
  bool _windDownEnabled = false;
  TimeOfDay? _windDownTime;
  bool _isWindDownActive = false;
  double _windDownDimLevel = 0;

  // Goals & XP
  int _dailyGoalMinutes = 60;
  int _totalXp = 0;

  // Focus Session (Lock-in Mode)
  bool _isFocusSessionActive = false;
  DateTime? _focusStartTime;
  int _focusTargetMinutes = 0;
  int _focusEarnedXp = 0;
  int _focusSessionsCompleted = 0;

  WellnessService(this._prefs) {
    _loadSettings();
    _startWindDownMonitor();
  }

  // Getters
  bool get zenModeEnabled => _zenModeEnabled;
  bool get isFocusSessionActive => _isFocusSessionActive;
  int get focusTargetMinutes => _focusTargetMinutes;
  int get focusSessionsCompleted => _focusSessionsCompleted;
  double get focusProgress => _focusStartTime == null
      ? 0
      : (DateTime.now().difference(_focusStartTime!).inSeconds /
                (_focusTargetMinutes * 60))
            .clamp(0.0, 1.0);

  bool get allowCallsDuringZen => _allowCallsDuringZen;
  int get zenRemainingSeconds => _zenRemainingSeconds;
  double get zenProgress => _zenStartTime == null
      ? 0
      : (1 - (_zenRemainingSeconds / (_zenSessionDurationMinutes * 60))).clamp(
          0.0,
          1.0,
        );
  Map<String, bool> get zenSchedule => _zenSchedule;
  Set<String> get blockedFeatures => _blockedFeatures;
  bool get windDownEnabled => _windDownEnabled;
  TimeOfDay? get windDownTime => _windDownTime;
  bool get isWindDownActive => _isWindDownActive;
  double get windDownDimLevel => _windDownDimLevel;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  int get totalXp => _totalXp;

  // Focus Session methods
  void startFocusSession(int minutes) {
    _isFocusSessionActive = true;
    _focusStartTime = DateTime.now();
    _focusTargetMinutes = minutes;
    _focusEarnedXp = minutes; // 1 XP per minute of focus
    notifyListeners();
  }

  Future<void> stopFocusSession({required bool completed}) async {
    if (!_isFocusSessionActive) return;

    if (completed) {
      _focusSessionsCompleted++;
      await _prefs.setInt('focus_sessions_completed', _focusSessionsCompleted);
      await _updateUserXP(_focusEarnedXp);
    } else {
      // Penalty for breaking focus intentionally
      await _updateUserXP(-(_focusEarnedXp ~/ 2));
    }

    _isFocusSessionActive = false;
    _focusStartTime = null;
    _focusTargetMinutes = 0;
    notifyListeners();
  }

  /// Penalize XP for distracting behavior (like browsing feed during focus)
  Future<void> penalizeDistraction() async {
    if (!_isFocusSessionActive) return;
    await _updateUserXP(-10); // Fixed penalty for distraction
    notifyListeners();
  }

  /// App lifecycle handling to save battery
  void onPaused() {
    _windDownTimer?.cancel();
    _windDownTimer = null;
    if (_zenTimer != null) {
      _zenTimer?.cancel();
      _zenTimer = null;
    }
    debugPrint('Wellness: Timers paused (background)');
  }

  void onResumed() {
    _startWindDownMonitor();
    if (_zenModeEnabled && _zenStartTime != null && _zenRemainingSeconds > 0) {
      _resumeZenTimer();
    }
    debugPrint('Wellness: Wind-down monitor resumed');
  }

  void _resumeZenTimer() {
    _zenTimer?.cancel();
    _zenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_zenRemainingSeconds > 0) {
        _zenRemainingSeconds--;
        notifyListeners();
      } else {
        _stopZenSession(manual: false);
      }
    });
  }

  static Future<WellnessService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return WellnessService(prefs);
  }

  void _loadSettings() {
    _zenModeEnabled = _prefs.getBool(_zenModeKey) ?? false;
    _allowCallsDuringZen = _prefs.getBool(_allowCallsDuringZenKey) ?? true;
    _totalXp = _prefs.getInt('total_xp') ?? 0;
    _focusSessionsCompleted = _prefs.getInt('focus_sessions_completed') ?? 0;

    final scheduleJson = _prefs.getString(_zenModeScheduleKey);
    if (scheduleJson != null) {
      final decoded = jsonDecode(scheduleJson) as Map<String, dynamic>;
      _zenSchedule = decoded.map((k, v) => MapEntry(k, v as bool));
    }

    final blockedJson = _prefs.getStringList(_blockedFeaturesKey);
    if (blockedJson != null) {
      _blockedFeatures = blockedJson.toSet();
    }

    _windDownEnabled = _prefs.getBool(_windDownEnabledKey) ?? false;
    final windDownStr = _prefs.getString(_windDownTimeKey);
    if (windDownStr != null) {
      final parts = windDownStr.split(':');
      _windDownTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    _dailyGoalMinutes = _prefs.getInt(_dailyGoalKey) ?? 60;
    notifyListeners();
  }

  bool _isUserPro() {
    return SubscriptionService().isPro;
  }

  // Zen Mode methods
  Future<void> setZenModeEnabled(bool enabled) async {
    if (_zenModeEnabled == enabled) return;

    _zenModeEnabled = enabled;
    await _prefs.setBool(_zenModeKey, enabled);

    if (enabled) {
      _startZenSession();
    } else {
      _stopZenSession(manual: true);
    }

    notifyListeners();
  }

  Future<void> setAllowCallsDuringZen(bool allow) async {
    _allowCallsDuringZen = allow;
    await _prefs.setBool(_allowCallsDuringZenKey, allow);
    notifyListeners();
  }

  void _startZenSession() {
    _zenStartTime = DateTime.now();
    _zenRemainingSeconds = _zenSessionDurationMinutes * 60;

    _setNotificationsPaused(true);

    _zenTimer?.cancel();
    _zenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_zenRemainingSeconds > 0) {
        _zenRemainingSeconds--;
        notifyListeners();
      } else {
        _stopZenSession(manual: false);
      }
    });
  }

  Future<void> _stopZenSession({required bool manual}) async {
    _zenTimer?.cancel();
    _zenTimer = null;

    _setNotificationsPaused(false);

    if (manual && _zenRemainingSeconds > 0) {
      // Penalty for early stop
      await _updateUserXP(-_zenPenaltyXP);
    } else if (!manual && _zenRemainingSeconds == 0) {
      // Reward for completion
      _focusSessionsCompleted++;
      await _prefs.setInt('focus_sessions_completed', _focusSessionsCompleted);
      await _updateUserXP(_zenRewardXP);
    }

    _zenStartTime = null;
    _zenRemainingSeconds = 0;
    _zenModeEnabled = false;
    await _prefs.setBool(_zenModeKey, false);
    notifyListeners();
  }

  void _setNotificationsPaused(bool paused) {
    NotificationManager.instance.setPaused(paused);
  }

  Future<void> _updateUserXP(int amount) async {
    final user = SupabaseService().client.auth.currentUser;
    if (user == null) return;

    try {
      await SupabaseService().client.rpc(
        'increment_xp',
        params: {'xp_amount': amount},
      );
      debugPrint('XP Updated via RPC: $amount');

      _totalXp = (_totalXp + amount) < 0 ? 0 : (_totalXp + amount);
      await _prefs.setInt('total_xp', _totalXp);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating XP: $e');
    }
  }

  Future<void> setBlockedFeatures(Set<String> features) async {
    if (!_isUserPro()) {
      throw Exception('Upgrade to Oasis Pro to customize Zen Mode blocklist.');
    }
    _blockedFeatures = features;
    await _prefs.setStringList(_blockedFeaturesKey, features.toList());
    notifyListeners();
  }

  bool isFeatureBlocked(String feature) {
    if (!_zenModeEnabled) return false;
    return _blockedFeatures.contains(feature);
  }

  // Available features that can be blocked
  static const List<Map<String, String>> blockableFeatures = [
    {'id': 'feed', 'name': 'Feed', 'icon': 'feed'},
    {'id': 'stories', 'name': 'Stories', 'icon': 'amp_stories'},
    {'id': 'messages', 'name': 'Messages', 'icon': 'chat'},
    {'id': 'communities', 'name': 'Communities', 'icon': 'groups'},
    {'id': 'notifications', 'name': 'Notifications', 'icon': 'notifications'},
    {'id': 'search', 'name': 'Search', 'icon': 'search'},
  ];

  // Wind Down methods
  Future<void> setWindDownEnabled(bool enabled) async {
    if (enabled && !_isUserPro()) {
      throw Exception('Upgrade to Oasis Pro to enable Wind-down mode.');
    }
    _windDownEnabled = enabled;
    await _prefs.setBool(_windDownEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setWindDownTime(TimeOfDay time) async {
    _windDownTime = time;
    await _prefs.setString(_windDownTimeKey, '${time.hour}:${time.minute}');
    notifyListeners();
  }

  void _startWindDownMonitor() {
    _windDownTimer?.cancel();
    _windDownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkWindDown();
    });
  }

  void _checkWindDown() {
    if (!_windDownEnabled || _windDownTime == null) {
      if (_isWindDownActive) {
        _isWindDownActive = false;
        _windDownDimLevel = 0;
        notifyListeners();
      }
      return;
    }

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final windDownMinutes = _windDownTime!.hour * 60 + _windDownTime!.minute;

    if (nowMinutes >= windDownMinutes) {
      final minutesPast = nowMinutes - windDownMinutes;
      _windDownDimLevel = (minutesPast / 120).clamp(0.0, 0.3);
      _isWindDownActive = true;
    } else {
      _isWindDownActive = false;
      _windDownDimLevel = 0;
    }

    notifyListeners();
  }

  // Daily goal methods
  Future<void> setDailyGoal(int minutes) async {
    _dailyGoalMinutes = minutes;
    await _prefs.setInt(_dailyGoalKey, minutes);
    notifyListeners();
  }

  @override
  void dispose() {
    _windDownTimer?.cancel();
    _zenTimer?.cancel();
    super.dispose();
  }
}

