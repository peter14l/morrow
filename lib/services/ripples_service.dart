import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';

enum RipplesLayoutType { kineticCardStack, choiceMosaic }

class RipplesService extends ChangeNotifier {
  static const String _lockoutEndTimeKey = 'ripples_lockout_end_time';
  static const String _layoutPreferenceKey = 'ripples_layout_preference';
  static const String _remainingDurationKey = 'ripples_remaining_duration';
  static const String _lastActiveKey = 'ripples_last_active';

  final SupabaseClient _supabase;

  bool _isRipplesLocked = false;
  DateTime? _lockoutEndTime;
  Timer? _activeSessionTimer;
  Timer? _lockoutCheckTimer;
  RipplesLayoutType _currentLayout = RipplesLayoutType.kineticCardStack;
  String? _currentUserId;

  Duration? _remainingDuration;
  DateTime? _lastSessionEndTime;
  double _lockoutMultiplier = 1.0;

  List<Map<String, dynamic>> _ripples = [];
  bool _isLoading = false;

  bool get isRipplesLocked => _isRipplesLocked;
  DateTime? get lockoutEndTime => _lockoutEndTime;
  RipplesLayoutType get currentLayout => _currentLayout;
  Duration? get remainingDuration => _remainingDuration;
  List<Map<String, dynamic>> get ripples => _ripples;
  bool get isLoading => _isLoading;

  final StreamController<void> _sessionEndController =
      StreamController<void>.broadcast();
  Stream<void> get onSessionEnd => _sessionEndController.stream;

  RipplesService({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseService().client {
    _startLockoutTimer();
  }

  void _startLockoutTimer() {
    _lockoutCheckTimer?.cancel();
    _lockoutCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkLockout(),
    );
  }

  /// App lifecycle handling to save battery
  void onPaused() {
    _lockoutCheckTimer?.cancel();
    _lockoutCheckTimer = null;
    debugPrint('Ripples: Lockout check timer paused (background)');
  }

  void onResumed() {
    checkLockout();
    _startLockoutTimer();
    debugPrint('Ripples: Lockout check timer resumed');
  }

  String _getUserKey(String baseKey) =>
      _currentUserId != null ? '${baseKey}_$_currentUserId' : baseKey;

  Future<void> initForUser(String userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    final prefs = await SharedPreferences.getInstance();

    // Load local state
    final lockoutTimeString = prefs.getString(_getUserKey(_lockoutEndTimeKey));
    if (lockoutTimeString != null) {
      _lockoutEndTime = DateTime.parse(lockoutTimeString);
    }

    final layoutString = prefs.getString(_getUserKey(_layoutPreferenceKey));
    if (layoutString != null) {
      _currentLayout = RipplesLayoutType.values.firstWhere(
        (e) => e.toString() == layoutString,
        orElse: () => RipplesLayoutType.kineticCardStack,
      );
    }

    final remainingMs = prefs.getInt(_getUserKey(_remainingDurationKey));
    if (remainingMs != null) {
      _remainingDuration = Duration(milliseconds: remainingMs);
    }

    final lastActiveStr = prefs.getString(_getUserKey(_lastActiveKey));
    if (lastActiveStr != null) {
      final lastActive = DateTime.parse(lastActiveStr);
      // Reset if > 30 mins passed
      if (DateTime.now().difference(lastActive).inMinutes > 30) {
        _remainingDuration = null;
        prefs.remove(_getUserKey(_remainingDurationKey));
      }
    }

    // Load from Supabase for sync/multiplier
    try {
      final data = await _supabase
          .from('profiles')
          .select(
            'ripples_lockout_multiplier, ripples_last_session_end, ripples_remaining_duration_ms',
          )
          .eq('id', userId)
          .single();

      _lockoutMultiplier =
          (data['ripples_lockout_multiplier'] as num?)?.toDouble() ?? 1.0;
      final dbLastEnd = data['ripples_last_session_end'] as String?;
      if (dbLastEnd != null) _lastSessionEndTime = DateTime.parse(dbLastEnd);

      // Decay multiplier if long time passed (e.g. 24h)
      if (_lastSessionEndTime != null) {
        final hoursSince = DateTime.now()
            .difference(_lastSessionEndTime!)
            .inHours;
        if (hoursSince > 24) {
          _lockoutMultiplier = 1.0;
          await _updateMultiplierInDb();
        }
      }
    } catch (e) {
      debugPrint('Error loading ripple profile data: $e');
    }

    checkLockout();
    refreshRipples();
    notifyListeners();
  }

  void checkLockout() {
    if (_lockoutEndTime != null) {
      if (DateTime.now().isAfter(_lockoutEndTime!)) {
        _isRipplesLocked = false;
        _lockoutEndTime = null;
        if (_currentUserId != null) {
          SharedPreferences.getInstance().then(
            (prefs) => prefs.remove(_getUserKey(_lockoutEndTimeKey)),
          );
        }
      } else {
        _isRipplesLocked = true;
      }
      notifyListeners();
    }
  }

  void startSession(Duration duration) {
    _activeSessionTimer?.cancel();
    _remainingDuration = duration;
    _activeSessionTimer = Timer(duration, endSession);
    _saveSessionState();
  }

  void pauseSession(Duration remaining) {
    _activeSessionTimer?.cancel();
    _remainingDuration = remaining;
    _saveSessionState();
    notifyListeners();
  }

  Future<void> _saveSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_remainingDuration != null) {
      await prefs.setInt(
        _getUserKey(_remainingDurationKey),
        _remainingDuration!.inMilliseconds,
      );
      await prefs.setString(
        _getUserKey(_lastActiveKey),
        DateTime.now().toIso8601String(),
      );
    }
  }

  Future<void> endSession() async {
    _activeSessionTimer?.cancel();
    _activeSessionTimer = null;
    _remainingDuration = null;

    // Adaptive Lockout Logic
    if (_lastSessionEndTime != null) {
      final diff = DateTime.now().difference(_lastSessionEndTime!).inMinutes;
      // If re-entering within 30 mins of lockout expiry (which is ~60 mins from last session end)
      // Actually the requirement is: "if a user, say, sets a duration for 15mins, gets blocked for 30mins,
      // and again immediately after that sets a duration of 30mins and so and so forth, then increase the duration of the block"

      // We check if the lockout just ended recently (e.g. within 30 mins)
      if (diff < 65) {
        // 30 min lockout + 35 min grace
        _lockoutMultiplier += 0.5;
      }
    }

    const baseLockout = Duration(minutes: 30);
    final actualLockoutMinutes = (baseLockout.inMinutes * _lockoutMultiplier)
        .round();

    _lockoutEndTime = DateTime.now().add(
      Duration(minutes: actualLockoutMinutes),
    );
    _lastSessionEndTime = _lockoutEndTime;
    _isRipplesLocked = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _getUserKey(_lockoutEndTimeKey),
      _lockoutEndTime!.toIso8601String(),
    );
    await prefs.remove(_getUserKey(_remainingDurationKey));

    await _updateMultiplierInDb();

    notifyListeners();
    _sessionEndController.add(null);
  }

  Future<void> _updateMultiplierInDb() async {
    if (_currentUserId == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({
            'ripples_lockout_multiplier': _lockoutMultiplier,
            'ripples_last_session_end': _lastSessionEndTime?.toIso8601String(),
          })
          .eq('id', _currentUserId!);
    } catch (e) {
      debugPrint('Error updating multiplier in DB: $e');
    }
  }

  void cancelSession() {
    // This is called when user exits manually
    // We should save the remaining time
    // For now we don't have a direct way to get elapsed time from Timer,
    // so the UI should pass it or we track start time.
  }

  Future<void> setLayoutPreference(RipplesLayoutType type) async {
    _currentLayout = type;
    if (_currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getUserKey(_layoutPreferenceKey), type.toString());
    }
    notifyListeners();
  }

  // Fetch real ripples from DB
  Future<void> refreshRipples() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Fetch ripples with profiles and check if current user liked/saved them
      final response = await _supabase
          .from('ripples')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_private
            ),
            ripple_likes!left (
              user_id
            ),
            ripple_saves!left (
              user_id
            )
          ''')
          .or('is_private.eq.false,user_id.eq.$userId')
          .order('created_at', ascending: false);

      final ripplesData = List<Map<String, dynamic>>.from(response);

      // Process ripples to add is_liked and is_saved fields
      for (var ripple in ripplesData) {
        final likes = ripple['ripple_likes'] as List<dynamic>?;
        ripple['is_liked'] =
            likes != null && likes.any((l) => l['user_id'] == userId);
        ripple.remove('ripple_likes');

        final saves = ripple['ripple_saves'] as List<dynamic>?;
        ripple['is_saved'] =
            saves != null && saves.any((s) => s['user_id'] == userId);
        ripple.remove('ripple_saves');
      }

      _ripples = ripplesData;
    } catch (e) {
      debugPrint('Error fetching ripples: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> likeRipple(String rippleId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Update locally first for instant feedback
    final index = _ripples.indexWhere((r) => r['id'] == rippleId);
    if (index != -1 && !(_ripples[index]['is_liked'] ?? false)) {
      _ripples[index]['is_liked'] = true;
      _ripples[index]['likes_count'] =
          (_ripples[index]['likes_count'] ?? 0) + 1;
      notifyListeners();
    }

    try {
      await _supabase.from('ripple_likes').upsert({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error liking ripple: $e');
      // Revert local change on error if needed
    }
  }

  Future<void> unlikeRipple(String rippleId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Update locally first
    final index = _ripples.indexWhere((r) => r['id'] == rippleId);
    if (index != -1 && (_ripples[index]['is_liked'] ?? false)) {
      _ripples[index]['is_liked'] = false;
      _ripples[index]['likes_count'] =
          (_ripples[index]['likes_count'] ?? 0) - 1;
      if (_ripples[index]['likes_count'] < 0) {
        _ripples[index]['likes_count'] = 0;
      }
      notifyListeners();
    }

    try {
      await _supabase.from('ripple_likes').delete().match({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error unliking ripple: $e');
    }
  }

  Future<void> commentOnRipple(String rippleId, String comment) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('ripple_comments').insert({
        'ripple_id': rippleId,
        'user_id': userId,
        'content': comment,
      });

      // Update local count
      final index = _ripples.indexWhere((r) => r['id'] == rippleId);
      if (index != -1) {
        _ripples[index]['comments_count'] =
            (_ripples[index]['comments_count'] ?? 0) + 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error commenting on ripple: $e');
    }
  }

  Future<void> saveRipple(String rippleId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final index = _ripples.indexWhere((r) => r['id'] == rippleId);
    if (index != -1) {
      _ripples[index]['is_saved'] = true;
      notifyListeners();
    }

    try {
      await _supabase.from('ripple_saves').upsert({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error saving ripple: $e');
    }
  }

  Future<void> unsaveRipple(String rippleId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final index = _ripples.indexWhere((r) => r['id'] == rippleId);
    if (index != -1) {
      _ripples[index]['is_saved'] = false;
      notifyListeners();
    }

    try {
      await _supabase.from('ripple_saves').delete().match({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error unsaving ripple: $e');
    }
  }

  @override
  void dispose() {
    _activeSessionTimer?.cancel();
    _lockoutCheckTimer?.cancel();
    _sessionEndController.close();
    super.dispose();
  }
}
