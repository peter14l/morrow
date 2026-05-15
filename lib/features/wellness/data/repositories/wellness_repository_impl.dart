import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/energy_meter_entity.dart';
import '../../domain/models/wellness_entity.dart';
import '../../domain/repositories/wellness_repository.dart';
import '../datasources/wellness_local_datasource.dart';

/// Implementation of WellnessRepository combining:
/// - WellnessService (focus mode, wind down, achievements)
/// - ScreenTimeService (screen time tracking)
/// - EnergyMeterService (interaction energy)
class WellnessRepositoryImpl implements WellnessRepository {
  final WellnessLocalDatasource _datasource;

  // Energy Meter state
  EnergyMeterEntity _energyState = EnergyMeterEntity.initial();
  Timer? _recoveryTimer;

  // Screen Time state
  DateTime? _sessionStartTime;
  int _currentSessionElapsedSeconds = 0;
  Timer? _autoSaveTimer;
  Timer? _wellbeingTicker;
  String? _currentCategory;
  Map<String, int> _categoryMinutes = {};
  int _cachedWellnessStreak = 0;

  // Focus Mode state
  Timer? _focusTimer;
  DateTime? _focusStartTime;
  int _focusRemainingSeconds = 0;
  static const int _focusSessionDurationMinutes = 30;
  static const int _focusRewardXP = 50;
  static const int _focusPenaltyXP = 35;

  // Wind Down state
  bool _isWindDownActive = false;
  double _windDownDimLevel = 0;
  Timer? _windDownTimer;

  // Achievements
  List<WellnessAchievementEntity> _achievements = [];

  WellnessRepositoryImpl(this._datasource) {
    _loadState();
  }

  void _loadState() {
    _loadEnergyState();
    _loadScreenTimeState();
    _loadWellnessState();
    _startTimers();
  }

  void _loadEnergyState() async {
    _energyState = await _datasource.getEnergyMeterState();
    // Apply passive recovery for time elapsed while app was closed
    _energyState = _energyState.withRecovery();
    await _datasource.saveEnergyMeterState(_energyState);
  }

  void _loadScreenTimeState() {
    final data = _datasource.getCategoryMinutes(DateTime.now());
    _categoryMinutes = data;
  }

  void _loadWellnessState() {
    _achievements = _datasource.achievements;
  }

  void _startTimers() {
    _startRecoveryTimer();
    _startWindDownMonitor();
  }

  void _startRecoveryTimer() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyRecovery(),
    );
  }

  void _applyRecovery() {
    _energyState = _energyState.withRecovery();
    _datasource.saveEnergyMeterState(_energyState);
  }

  void _startWindDownMonitor() {
    _windDownTimer?.cancel();
    _windDownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkWindDown(),
    );
  }

  void _checkWindDown() {
    if (!_datasource.windDownEnabled || _datasource.windDownTime == null) {
      _isWindDownActive = false;
      _windDownDimLevel = 0;
      return;
    }

    final now = TimeOfDay.now();
    final windDownTime = _datasource.windDownTime!;
    final nowMinutes = now.hour * 60 + now.minute;
    final windDownMinutes = windDownTime.hour * 60 + windDownTime.minute;

    if (nowMinutes >= windDownMinutes) {
      final minutesPast = nowMinutes - windDownMinutes;
      _windDownDimLevel = (minutesPast / 120).clamp(0.0, 0.3);
      _isWindDownActive = true;
    } else {
      _isWindDownActive = false;
      _windDownDimLevel = 0;
    }
  }

  String _getDateKey(DateTime date) {
    return 'screen_time_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ============ Energy Meter ============

  @override
  Future<EnergyMeterEntity> getEnergyMeterState() async {
    return _energyState;
  }

  @override
  Future<void> saveEnergyMeterState(EnergyMeterEntity state) async {
    _energyState = state;
    await _datasource.saveEnergyMeterState(state);
  }

  @override
  Future<bool> deductEnergy(InteractionType type) async {
    double cost;
    switch (type) {
      case InteractionType.expand:
        cost = EnergyMeterEntity.expansionCost;
        break;
      case InteractionType.view:
        cost = EnergyMeterEntity.viewCost;
        break;
      case InteractionType.like:
      case InteractionType.comment:
      case InteractionType.share:
      case InteractionType.bookmark:
        cost = EnergyMeterEntity.likeCost;
        break;
    }

    if (_energyState.currentEnergy < cost) {
      return false;
    }

    _energyState = _energyState.deductEnergy(cost);
    await _datasource.saveEnergyMeterState(_energyState);
    return true;
  }

  @override
  Future<void> forceEnergyRecovery() async {
    _energyState = _energyState.withRecovery();
    await _datasource.saveEnergyMeterState(_energyState);
  }

  @override
  Future<void> resetEnergy() async {
    _energyState = EnergyMeterEntity.initial();
    await _datasource.saveEnergyMeterState(_energyState);
  }

  // ============ Screen Time ============

  @override
  Future<ScreenTimeEntity> getScreenTimeData(DateTime date) async {
    final dateKey = _getDateKey(date);
    final hourlyUsage = _datasource.getHourlyUsage(dateKey);
    final totalMinutes = hourlyUsage.fold(0, (a, b) => a + b);
    final weeklyAvg = await getWeeklyAverage();
    final categoryData = await getCategoryUsage(totalMinutes);

    return ScreenTimeEntity(
      totalMinutesToday: totalMinutes,
      weeklyAverageMinutes: weeklyAvg,
      weeklyData: [],
      categoryUsage: categoryData,
      hourlyBreakdown: {for (int i = 0; i < 24; i++) i: hourlyUsage[i]},
      currentSessionSeconds: _currentSessionElapsedSeconds,
      wellnessStreak: await getWellnessStreak(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyData() async {
    final List<Map<String, dynamic>> data = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final usage = await getScreenTimeData(date);
      data.add({
        'day': _getDayName(date.weekday),
        'minutes': usage.totalMinutesToday,
        'date': date,
      });
    }
    return data;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Future<int> getWeeklyAverage() async {
    int totalMinutes = 0;
    int daysWithData = 0;

    for (int i = 1; i <= 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final usage = await getScreenTimeData(date);
      final minutes = usage.totalMinutesToday;

      if (minutes > 0) {
        totalMinutes += minutes;
        daysWithData++;
      }
    }

    if (daysWithData == 0) return 0;
    return (totalMinutes / 7).round();
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryUsage(int totalMinutes) async {
    if (totalMinutes == 0) {
      return [
        {'name': 'Feed', 'minutes': 0, 'icon': Icons.feed, 'color': 0xFF2196F3},
        {
          'name': 'Messages',
          'minutes': 0,
          'icon': Icons.chat,
          'color': 0xFF4CAF50,
        },
        {
          'name': 'Communities',
          'minutes': 0,
          'icon': Icons.people,
          'color': 0xFFFF9800,
        },
        {
          'name': 'Profile',
          'minutes': 0,
          'icon': Icons.person,
          'color': 0xFF9C27B0,
        },
        {
          'name': 'Other',
          'minutes': totalMinutes,
          'icon': Icons.more_horiz,
          'color': 0xFF9E9E9E,
        },
      ];
    }

    final categoryStyles = {
      'Feed': {'icon': Icons.feed, 'color': 0xFF2196F3},
      'Messages': {'icon': Icons.chat, 'color': 0xFF4CAF50},
      'Communities': {'icon': Icons.people, 'color': 0xFFFF9800},
      'Profile': {'icon': Icons.person, 'color': 0xFF9C27B0},
    };

    final List<Map<String, dynamic>> categories = [];
    int accountedMinutes = 0;

    _categoryMinutes.forEach((name, minutes) {
      final style =
          categoryStyles[name] ??
          {'icon': Icons.more_horiz, 'color': 0xFF9E9E9E};
      categories.add({
        'name': name,
        'minutes': minutes,
        'icon': style['icon'],
        'color': style['color'],
      });
      accountedMinutes += minutes;
    });

    final otherMinutes = math.max(0, totalMinutes - accountedMinutes);
    if (!categories.any((c) => c['name'] == 'Other')) {
      categories.add({
        'name': 'Other',
        'minutes': otherMinutes,
        'icon': Icons.more_horiz,
        'color': 0xFF9E9E9E,
      });
    }

    categories.sort(
      (a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int),
    );
    return categories;
  }

  @override
  Future<void> recordScreenTime(String category, int minutes) async {
    if (minutes <= 0) return;
    _categoryMinutes[category] = (_categoryMinutes[category] ?? 0) + minutes;
    await _datasource.saveCategoryMinutes(DateTime.now(), _categoryMinutes);
  }

  @override
  Future<void> startTracking() async {
    _sessionStartTime = DateTime.now();
    _startWellbeingTicker();
    _startAutoSave();
  }

  @override
  Future<void> stopTracking() async {
    _stopWellbeingTicker();
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    if (_sessionStartTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!);
    _sessionStartTime = null;

    if (duration.inSeconds < 1) return;
    await _recordUsage(endTime, duration);
  }

  void _startWellbeingTicker() {
    _wellbeingTicker?.cancel();
    _wellbeingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentSessionElapsedSeconds++;
    });
  }

  void _stopWellbeingTicker() {
    _wellbeingTicker?.cancel();
    _wellbeingTicker = null;
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_sessionStartTime != null) {
        final now = DateTime.now();
        final duration = now.difference(_sessionStartTime!);
        if (duration.inSeconds >= 60) {
          await _recordUsage(now, duration);
          _sessionStartTime = now;
        }
      }
    });
  }

  Future<void> _recordUsage(DateTime timestamp, Duration duration) async {
    final dateKey = _getDateKey(timestamp);
    final hour = timestamp.hour;
    final hourlyUsage = _datasource.getHourlyUsage(dateKey);
    hourlyUsage[hour] += duration.inMinutes;
    await _datasource.saveHourlyUsage(dateKey, hourlyUsage);

    if (_currentCategory != null && duration.inMinutes > 0) {
      _categoryMinutes[_currentCategory!] =
          (_categoryMinutes[_currentCategory!] ?? 0) + duration.inMinutes;
      await _datasource.saveCategoryMinutes(timestamp, _categoryMinutes);
    }
  }

  @override
  void setCurrentCategory(String? category) {
    _currentCategory = category;
  }

  @override
  int get currentSessionElapsedSeconds => _currentSessionElapsedSeconds;

  @override
  int get wellnessStreak => _cachedWellnessStreak;

  @override
  Future<int> getWellnessStreak() async {
    int streak = 0;
    final now = DateTime.now();
    const defaultLimit = 120;

    for (int i = 1; i <= 365; i++) {
      final date = now.subtract(Duration(days: i));
      final data = await getScreenTimeData(date);
      final minutes = data.totalMinutesToday;

      if (minutes <= defaultLimit) {
        streak++;
      } else {
        break;
      }
    }
    _cachedWellnessStreak = streak;
    return streak;
  }

  // ============ Focus Mode ============

  @override
  Future<void> setFocusModeEnabled(bool enabled) async {
    await _datasource.setFocusModeEnabled(enabled);
    if (enabled) {
      _startFocusSession();
    } else {
      _stopFocusSession(manual: true);
    }
  }

  void _startFocusSession() {
    _focusStartTime = DateTime.now();
    _focusRemainingSeconds = _focusSessionDurationMinutes * 60;
    // Pause notifications - would call NotificationManager here

    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_focusRemainingSeconds > 0) {
        _focusRemainingSeconds--;
      } else {
        _stopFocusSession(manual: false);
      }
    });
  }

  Future<void> _stopFocusSession({required bool manual}) async {
    _focusTimer?.cancel();
    _focusTimer = null;
    // Resume notifications

    if (manual && _focusRemainingSeconds > 0) {
      await _datasource.updateUserXP(-_focusPenaltyXP);
    } else if (!manual && _focusRemainingSeconds == 0) {
      await _datasource.updateUserXP(_focusRewardXP);
      _awardFocusAchievement();
    }

    _focusStartTime = null;
    _focusRemainingSeconds = 0;
    await _datasource.setFocusModeEnabled(false);
  }

  void _awardFocusAchievement() {
    final today = DateTime.now();
    final achievement = WellnessAchievementEntity(
      id: 'focus_${today.millisecondsSinceEpoch}',
      type: AchievementType.challenge,
      name: 'Focus Master',
      description: 'Completed a 30-minute focus session!',
      icon: '🧘',
      earnedAt: today,
    );
    _achievements.add(achievement);
    _datasource.saveAchievements(_achievements);
  }

  @override
  Future<void> setBlockedFeatures(Set<String> features) async {
    if (!_datasource.isUserPro) {
      throw Exception(
        'Upgrade to Oasis Pro to customize Focus Mode blocklist.',
      );
    }
    await _datasource.setBlockedFeatures(features);
  }

  @override
  bool isFeatureBlocked(String feature) {
    if (!_datasource.focusModeEnabled) return false;
    return _datasource.blockedFeatures.contains(feature);
  }

  @override
  bool get focusModeEnabled => _datasource.focusModeEnabled;

  @override
  int get focusRemainingSeconds => _focusRemainingSeconds;

  @override
  double get focusProgress => _focusStartTime == null
      ? 0.0
      : (1 - (_focusRemainingSeconds / (_focusSessionDurationMinutes * 60)))
            .clamp(0.0, 1.0);

  @override
  Map<String, bool> get focusSchedule => _datasource.focusSchedule;

  @override
  Set<String> get blockedFeatures => _datasource.blockedFeatures;

  // ============ Wind Down Mode ============

  @override
  Future<void> setWindDownEnabled(bool enabled) async {
    if (enabled && !_datasource.isUserPro) {
      throw Exception('Upgrade to Oasis Pro to enable Wind-down mode.');
    }
    await _datasource.setWindDownEnabled(enabled);
  }

  @override
  Future<void> setWindDownTime(int hour, int minute) async {
    await _datasource.setWindDownTime(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  bool get windDownEnabled => _datasource.windDownEnabled;

  @override
  bool get isWindDownActive => _isWindDownActive;

  @override
  double get windDownDimLevel => _windDownDimLevel;

  // ============ Daily Goal ============

  @override
  Future<void> setDailyGoal(int minutes) async {
    await _datasource.setDailyGoal(minutes);
  }

  @override
  int get dailyGoalMinutes => _datasource.dailyGoalMinutes;

  // ============ Wellness Stats ============

  @override
  Future<WellnessStatsEntity> getWellnessStats() async {
    final focusCount = _achievements
        .where((a) => a.id.startsWith('focus_'))
        .length;
    final streak = await getWellnessStreak();
    return WellnessStatsEntity(
      totalXp: 0, // Would fetch from user metadata
      focusSessionsCompleted: focusCount,
      currentStreak: streak,
      dailyGoalMinutes: _datasource.dailyGoalMinutes,
      achievements: _achievements,
    );
  }

  @override
  Future<void> checkAndAwardAchievements(
    int currentStreak,
    int todayMinutes,
  ) async {
    final newAchievements = <WellnessAchievementEntity>[];

    // Streak achievements (Pro feature)
    if (_datasource.isUserPro) {
      final streakMilestones = [3, 7, 14, 30, 60, 100, 365];
      for (final milestone in streakMilestones) {
        if (currentStreak >= milestone) {
          final existingIndex = _achievements.indexWhere(
            (a) => a.type == AchievementType.streak && a.value == milestone,
          );
          if (existingIndex == -1) {
            newAchievements.add(
              WellnessAchievementEntity(
                id: 'streak_$milestone',
                type: AchievementType.streak,
                name: '$milestone Day Streak',
                description:
                    'Maintained healthy screen time for $milestone days!',
                icon: '🔥',
                earnedAt: DateTime.now(),
                value: milestone,
              ),
            );
          }
        }
      }
    }

    // Under-goal achievement for today
    if (todayMinutes <= _datasource.dailyGoalMinutes && todayMinutes > 0) {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final existingIndex = _achievements.indexWhere(
        (a) => a.type == AchievementType.balance && a.id == 'balance_$todayKey',
      );
      if (existingIndex == -1) {
        newAchievements.add(
          WellnessAchievementEntity(
            id: 'balance_$todayKey',
            type: AchievementType.balance,
            name: 'Balanced Day',
            description: 'Stayed under your daily goal! Great job!',
            icon: '⚖️',
            earnedAt: DateTime.now(),
          ),
        );
      }
    }

    if (newAchievements.isNotEmpty) {
      _achievements.addAll(newAchievements);
      await _datasource.saveAchievements(_achievements);
    }
  }

  @override
  List<WellnessAchievementEntity> get achievements => _achievements;

  @override
  Future<void> updateUserXP(int amount) async {
    await _datasource.updateUserXP(amount);
  }

  // ============ Quiet Mode ============

  @override
  Future<void> setQuietMode(bool enabled) async {
    await _datasource.setQuietMode(enabled);
  }

  @override
  Future<void> setQuietModeHours(
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) async {
    await _datasource.setQuietModeHours(
      TimeOfDay(hour: startHour, minute: startMinute),
      TimeOfDay(hour: endHour, minute: endMinute),
    );
  }

  @override
  bool get isQuietModeEnabled => _datasource.quietModeEnabled;

  @override
  bool get isQuietModeActive {
    if (!_datasource.quietModeEnabled) return false;

    final start = _datasource.quietModeStart;
    final end = _datasource.quietModeEnd;
    if (start == null || end == null) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } else {
      return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
  }

  // ============ Lifecycle ============

  @override
  void onPaused() {
    _recoveryTimer?.cancel();
    _windDownTimer?.cancel();
    _focusTimer?.cancel();
  }

  @override
  void onResumed() {
    _loadEnergyState();
    _startRecoveryTimer();
    _startWindDownMonitor();
  }

  void dispose() {
    _recoveryTimer?.cancel();
    _windDownTimer?.cancel();
    _focusTimer?.cancel();
    _wellbeingTicker?.cancel();
    _autoSaveTimer?.cancel();
  }

  static Future<WellnessRepositoryImpl> init() async {
    final datasource = await WellnessLocalDatasource.init();
    return WellnessRepositoryImpl(datasource);
  }
}
