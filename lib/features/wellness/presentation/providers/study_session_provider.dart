import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/models/study_session.dart';
import 'package:oasis/services/study_session_service.dart';

class StudySessionProvider extends ChangeNotifier {
  final StudySessionService _service;
  final _supabase = SupabaseService().client;

  List<StudySession> _activeSessions = [];
  StudySession? _currentSession;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalDurationSeconds = 0;
  bool _isLoading = false;
  String? _error;

  StudySessionProvider(this._service);

  // Getters
  List<StudySession> get activeSessions => _activeSessions;
  StudySession? get currentSession => _currentSession;
  bool get isInSession => _currentSession != null;
  int get remainingSeconds => _remainingSeconds;
  double get progress => _totalDurationSeconds == 0
      ? 0.0
      : (elapsedSeconds / _totalDurationSeconds).clamp(0.0, 1.0);
  int get elapsedSeconds => _totalDurationSeconds - _remainingSeconds;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get xpEarned {
    if (_currentSession == null) return 0;
    // 1 XP per minute of focus completed
    return (elapsedSeconds / 60).floor();
  }

  // Load all currently active study sessions from Supabase
  Future<void> fetchActiveSessions() async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('study_sessions')
          .select()
          .eq('status', 'active')
          .order('start_time', ascending: false);

      _activeSessions = (response as List)
          .map((json) => StudySession.fromJson(json))
          .toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[StudySessionProvider] Error fetching sessions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Create a new study session
  Future<void> createSession({
    required String title,
    required int durationMinutes,
    bool isLockedIn = true,
  }) async {
    _setLoading(true);
    try {
      final session = await _service.createSession(
        title: title,
        durationMinutes: durationMinutes,
        isLockedIn: isLockedIn,
      );
      _currentSession = session;
      _remainingSeconds = durationMinutes * 60;
      _totalDurationSeconds = _remainingSeconds;
      _startTimer();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Join an existing study session
  Future<void> joinSession(StudySession session) async {
    _setLoading(true);
    try {
      await _service.joinSession(session.id);
      _currentSession = session;
      
      // Calculate remaining time based on session start time and duration
      final elapsed = DateTime.now().difference(session.startTime).inSeconds;
      final total = session.durationMinutes * 60;
      _remainingSeconds = (total - elapsed).clamp(0, total);
      _totalDurationSeconds = total;

      _startTimer();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Complete session successfully
  Future<void> completeSession() async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;
    final earned = xpEarned;

    _timer?.cancel();
    _timer = null;
    _currentSession = null;
    _remainingSeconds = 0;
    _totalDurationSeconds = 0;
    notifyListeners();

    try {
      await _service.completeSession(sessionId, earned);
      await fetchActiveSessions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Abandon session early (intentionally leaving or lockout penalty)
  Future<void> abandonSession({bool dueToPenalty = false}) async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;

    _timer?.cancel();
    _timer = null;
    _currentSession = null;
    _remainingSeconds = 0;
    _totalDurationSeconds = 0;
    notifyListeners();

    try {
      // Penalty: deduct 15 XP if abandoned early, or 25 if lock-in penalty triggered
      final penaltyAmount = dueToPenalty ? -25 : -15;
      await _supabase.rpc('increment_xp', params: {'xp_amount': penaltyAmount});
      
      // Update DB participant exit status
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('study_session_participants')
            .update({'exit_status': 'abandoned', 'xp_earned': penaltyAmount})
            .eq('session_id', sessionId)
            .eq('user_id', user.id);
      }
      await fetchActiveSessions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Detect background pause to penalize if "Lock-in" mode is enabled
  void onPaused() {
    if (_currentSession != null && _currentSession!.isLockedIn) {
      debugPrint('[StudySessionProvider] Lock-in Mode Violation! Exiting app during session.');
      abandonSession(dueToPenalty: true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        completeSession();
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
