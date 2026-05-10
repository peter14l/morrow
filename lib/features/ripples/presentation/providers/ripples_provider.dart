import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart'
    show RipplesLayoutType, RippleEntity, RippleCommentEntity;
import 'package:oasis/features/ripples/domain/repositories/ripple_repository.dart';
import 'package:oasis/features/ripples/data/repositories/ripple_repository_impl.dart';
import 'package:oasis/services/ad_service.dart';
import 'package:oasis/services/subscription_service.dart';

/// Provider for ripples feature - manages UI state and session lifecycle.
/// Uses Maps internally for backward compatibility with existing screen code.
class RipplesProvider extends ChangeNotifier {
  static const String _lockoutEndTimeKey = 'ripples_lockout_end_time';
  static const String _layoutPreferenceKey = 'ripples_layout_preference';
  static const String _remainingDurationKey = 'ripples_remaining_duration';
  static const String _lastActiveKey = 'ripples_last_active';

  final RippleRepository _rippleRepository;
  final AdService _adService;
  final SubscriptionService _subscriptionService;

  List<RippleEntity> _ripples = [];
  bool _isLoading = false;
  String? _error;
  RipplesLayoutType _currentLayout = RipplesLayoutType.kineticCardStack;
  bool _isRipplesLocked = false;
  DateTime? _lockoutEndTime;
  Duration? _remainingDuration;
  String? _currentUserId;

  Timer? _activeSessionTimer;
  Timer? _lockoutCheckTimer;
  double _lockoutMultiplier = 1.0;
  DateTime? _lastSessionEndTime;

  final StreamController<void> _sessionEndController =
      StreamController<void>.broadcast();

  RipplesProvider({
    RippleRepository? rippleRepository,
    AdService? adService,
    SubscriptionService? subscriptionService,
  }) : _rippleRepository = rippleRepository ?? RippleRepositoryImpl(),
       _adService = adService ?? AdService(),
       _subscriptionService = subscriptionService ?? SubscriptionService() {
    _startLockoutTimer();
  }

  // Getters
  List<RippleEntity> get ripples => _ripples;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RipplesLayoutType get currentLayout => _currentLayout;
  bool get isRipplesLocked => _isRipplesLocked;
  DateTime? get lockoutEndTime => _lockoutEndTime;
  Duration? get remainingDuration => _remainingDuration;
  Stream<void> get onSessionEnd => _sessionEndController.stream;

  // Initialize for a user
  Future<void> initForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // Load local state
    final lockoutTimeString = prefs.getString('${_lockoutEndTimeKey}_$userId');
    if (lockoutTimeString != null) {
      _lockoutEndTime = DateTime.parse(lockoutTimeString);
    }

    final layoutString = prefs.getString('${_layoutPreferenceKey}_$userId');
    if (layoutString != null) {
      _currentLayout = RipplesLayoutType.values.firstWhere(
        (e) => e.toString() == layoutString,
        orElse: () => RipplesLayoutType.kineticCardStack,
      );
    }

    final remainingMs = prefs.getInt('${_remainingDurationKey}_$userId');
    if (remainingMs != null) {
      _remainingDuration = Duration(milliseconds: remainingMs);
    }

    _currentUserId = userId;
    checkLockout();
    refreshRipples();
  }

  void _startLockoutTimer() {
    _lockoutCheckTimer?.cancel();
    _lockoutCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkLockout(),
    );
  }

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

  void checkLockout() {
    if (_lockoutEndTime != null) {
      if (DateTime.now().isAfter(_lockoutEndTime!)) {
        _isRipplesLocked = false;
        _lockoutEndTime = null;
        if (_currentUserId != null) {
          SharedPreferences.getInstance().then(
            (prefs) => prefs.remove('${_lockoutEndTimeKey}_$_currentUserId'),
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
    if (_remainingDuration != null && _currentUserId != null) {
      await prefs.setInt(
        '${_remainingDurationKey}_$_currentUserId',
        _remainingDuration!.inMilliseconds,
      );
      await prefs.setString(
        '${_lastActiveKey}_$_currentUserId',
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
      if (diff < 65) {
        _lockoutMultiplier += 0.5;
      }
    }

    const baseLockout = Duration(minutes: 30);
    final actualLockoutMinutes = (baseLockout.inMinutes * _lockoutMultiplier)
        .round();

    final lockoutEnd = DateTime.now().add(
      Duration(minutes: actualLockoutMinutes),
    );
    _lastSessionEndTime = lockoutEnd;
    _isRipplesLocked = true;
    _lockoutEndTime = lockoutEnd;

    final prefs = await SharedPreferences.getInstance();
    if (_currentUserId != null) {
      await prefs.setString(
        '${_lockoutEndTimeKey}_$_currentUserId',
        lockoutEnd.toIso8601String(),
      );
      await prefs.remove('${_remainingDurationKey}_$_currentUserId');
    }

    notifyListeners();
    _sessionEndController.add(null);
  }

  Future<void> setLayoutPreference(RipplesLayoutType type) async {
    _currentLayout = type;
    if (_currentUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_layoutPreferenceKey}_$_currentUserId',
        type.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> refreshRipples() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ripples = await _rippleRepository.getRipples();
      await _injectAds();
    } catch (e) {
      debugPrint('Error fetching ripples: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _injectAds() async {
    if (_subscriptionService.isPro) return;

    final ads = await _adService.getHouseAds();
    if (ads.isEmpty) return;

    final List<RippleEntity> result = [];
    int adIndex = 0;
    for (int i = 0; i < _ripples.length; i++) {
      result.add(_ripples[i]);
      if ((i + 1) % 5 == 0 && adIndex < ads.length) {
        final ad = ads[adIndex];
        result.add(RippleEntity(
          id: 'ad_${ad.id}',
          userId: 'ad_system',
          isAd: true,
          videoUrl: ad.imageUrl ?? '',
          thumbnailUrl: ad.imageUrl,
          caption: ad.content,
          createdAt: ad.timestamp,
          username: ad.username,
          avatarUrl: ad.userAvatar,
        ));
        adIndex++;
      }
    }
    _ripples = result;
  }

  Future<void> likeRipple(String rippleId) async {
    // Update locally first for instant feedback
    final index = _ripples.indexWhere((r) => r.id == rippleId);
    if (index != -1 && !_ripples[index].isLiked) {
      _ripples[index] = _ripples[index].copyWith(
        isLiked: true,
        likesCount: _ripples[index].likesCount + 1,
      );
      notifyListeners();
    }

    try {
      await _rippleRepository.likeRipple(rippleId);
    } catch (e) {
      debugPrint('Error liking ripple: $e');
    }
  }

  Future<void> unlikeRipple(String rippleId) async {
    // Update locally first
    final index = _ripples.indexWhere((r) => r.id == rippleId);
    if (index != -1 && _ripples[index].isLiked) {
      _ripples[index] = _ripples[index].copyWith(
        isLiked: false,
        likesCount: (_ripples[index].likesCount - 1).clamp(0, 999999),
      );
      notifyListeners();
    }

    try {
      await _rippleRepository.unlikeRipple(rippleId);
    } catch (e) {
      debugPrint('Error unliking ripple: $e');
    }
  }

  Future<void> saveRipple(String rippleId) async {
    final index = _ripples.indexWhere((r) => r.id == rippleId);
    if (index != -1 && !_ripples[index].isSaved) {
      _ripples[index] = _ripples[index].copyWith(
        isSaved: true,
        savesCount: _ripples[index].savesCount + 1,
      );
      notifyListeners();
    }

    try {
      await _rippleRepository.saveRipple(rippleId);
    } catch (e) {
      debugPrint('Error saving ripple: $e');
    }
  }

  Future<void> unsaveRipple(String rippleId) async {
    final index = _ripples.indexWhere((r) => r.id == rippleId);
    if (index != -1 && _ripples[index].isSaved) {
      _ripples[index] = _ripples[index].copyWith(
        isSaved: false,
        savesCount: (_ripples[index].savesCount - 1).clamp(0, 999999),
      );
      notifyListeners();
    }

    try {
      await _rippleRepository.unsaveRipple(rippleId);
    } catch (e) {
      debugPrint('Error unsaving ripple: $e');
    }
  }

  Future<List<RippleCommentEntity>> getComments(String rippleId) async {
    try {
      return await _rippleRepository.getComments(rippleId);
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  Future<void> commentOnRipple(String rippleId, String comment) async {
    try {
      await _rippleRepository.commentOnRipple(
        rippleId: rippleId,
        content: comment,
      );

      // Update local count
      final index = _ripples.indexWhere((r) => r.id == rippleId);
      if (index != -1) {
        _ripples[index] = _ripples[index].copyWith(
          commentsCount: _ripples[index].commentsCount + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error commenting on ripple: $e');
    }
  }

  Future<RippleEntity> uploadAndCreateRipple({
    required File videoFile,
    String? caption,
    bool isPrivate = false,
  }) async {
    final ripple = await _rippleRepository.uploadAndCreateRipple(
      videoFile: videoFile,
      caption: caption,
      isPrivate: isPrivate,
    );
    await refreshRipples();
    return ripple;
  }

  @override
  void dispose() {
    _activeSessionTimer?.cancel();
    _lockoutCheckTimer?.cancel();
    _sessionEndController.close();
    super.dispose();
  }
}
