import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/services/presence_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/network/supabase_client.dart';

class UserPresence {
  final String status;
  final DateTime? lastSeen;
  UserPresence({required this.status, this.lastSeen});
}

class PresenceProvider with ChangeNotifier {
  final PresenceService _presenceService = PresenceService();
  final Map<String, UserPresence> _userPresence = {};
  bool _isDisposed = false;

  // Polling fallback for user presence (when realtime presence sync fails)
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _offlineThreshold = Duration(minutes: 1);
  final Set<String> _trackedUserIds = {};

  UserPresence? getUserPresence(String userId) {
    final presence = _userPresence[userId];
    if (presence == null) return null;

    // Client-side validation: if status is online but last_seen is too old, treat as offline
    if (presence.status == 'online' && presence.lastSeen != null) {
      final now = DateTime.now();
      if (now.difference(presence.lastSeen!) > _offlineThreshold) {
        return UserPresence(status: 'offline', lastSeen: presence.lastSeen);
      }
    }

    return presence;
  }

  bool isUserOnline(String userId) => getUserPresence(userId)?.status == 'online';

  void subscribeToUserPresence(String userId) {
    // Track user ID for polling fallback
    _trackedUserIds.add(userId);

    _presenceService.subscribeToUserPresence(
      userId: userId,
      onUpdate: (status, lastSeen) {
        _userPresence[userId] = UserPresence(
          status: status,
          lastSeen: lastSeen,
        );
        _safeNotifyListeners();
      },
    );

    // Start polling fallback and heartbeat if not started
    _startPollingFallback();
    _startHeartbeat();
  }

  void updateUserPresence(String userId, String status) {
    _presenceService.updateUserPresence(userId, status);
  }

  void unsubscribeFromUserPresence(String userId) {
    _presenceService.unsubscribeFromPresence(userId);
    _userPresence.remove(userId);
    _trackedUserIds.remove(userId);
    _safeNotifyListeners();

    // Stop polling if no more users to track
    if (_trackedUserIds.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    
    // Defer notification to avoid "widget tree locked" errors if called during build/dispose
    Future.microtask(() {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    super.dispose();
  }

  /// Start polling fallback to sync presence when realtime fails.
  void _startPollingFallback() {
    if (_pollingTimer != null) return; // Already running

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollUserPresence();
    });
  }

  /// Start heartbeat to keep current user online in the database.
  void _startHeartbeat() {
    if (_heartbeatTimer != null) return;

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final userId = AuthService().currentUser?.id;
      if (userId != null) {
        updateUserPresence(userId, 'online');
      }
    });
  }

  void pauseHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void resumeHeartbeat() {
    if (_trackedUserIds.isNotEmpty) {
      _startHeartbeat();
    }
  }

  /// Poll user presence directly from database.
  Future<void> _pollUserPresence() async {
    final userIds = _trackedUserIds.toList();
    for (final userId in userIds) {
      try {
        final result = await _presenceService.getUserStatus(userId);

        if (result != null) {
          final status = result['status'] as String? ?? 'offline';
          final lastSeenStr = result['last_seen'] as String?;
          final lastSeen =
              lastSeenStr != null ? DateTime.parse(lastSeenStr) : null;

          _userPresence[userId] = UserPresence(
            status: status,
            lastSeen: lastSeen,
          );
        } else {
          _userPresence[userId] = UserPresence(
            status: 'offline',
            lastSeen: null,
          );
        }
      } catch (e) {
        debugPrint('[PresenceProvider] Polling error for $userId: $e');
      }
    }
    _safeNotifyListeners();
  }
}
