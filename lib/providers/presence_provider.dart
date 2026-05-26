import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/services/presence_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

class UserPresence {
  final String status;
  final DateTime? lastSeen;
  UserPresence({required this.status, this.lastSeen});
}

class PresenceProvider with ChangeNotifier, SafeChangeNotifier {
  final PresenceService _presenceService = PresenceService();
  final Map<String, UserPresence> _userPresence = {};

  // Polling fallback for user presence (when realtime presence sync fails)
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);
  static const Duration _heartbeatInterval = Duration(seconds: 25);
  static const Duration _offlineThreshold = Duration(seconds: 45);
  final Set<String> _trackedUserIds = {};

  // Track when the last update was received via Realtime to avoid overwriting with stale polling data
  final Map<String, DateTime> _lastRealtimeUpdate = {};

  UserPresence? getUserPresence(String userId) {
    final presence = _userPresence[userId];
    if (presence == null) return null;

    // Client-side validation: if status is online but last_seen is too old, treat as offline
    if (presence.status == 'online' && presence.lastSeen != null) {
      final now = DateTime.now().toUtc();
      if (now.difference(presence.lastSeen!) > _offlineThreshold) {
        return UserPresence(status: 'offline', lastSeen: presence.lastSeen);
      }
    }

    return presence;
  }

  bool isUserOnline(String userId) =>
      getUserPresence(userId)?.status == 'online';

  void subscribeToUserPresence(String userId) {
    if (isDisposed) return;

    // Track user ID for polling fallback
    _trackedUserIds.add(userId);

    _presenceService.subscribeToUserPresence(
      userId: userId,
      onUpdate: (status, lastSeen) {
        if (isDisposed) return;
        _userPresence[userId] = UserPresence(
          status: status,
          lastSeen: lastSeen,
        );
        _lastRealtimeUpdate[userId] = DateTime.now().toUtc();
        notifyListeners();
      },
    );

    // Start polling fallback and heartbeat if not started
    _startPollingFallback();
    _startHeartbeat();
  }

  void updateUserPresence(String userId, String status) {
    if (isDisposed) return;
    _presenceService.updateUserPresence(userId, status);
  }

  void unsubscribeFromUserPresence(String userId) {
    if (isDisposed) return;
    _presenceService.unsubscribeFromPresence(userId);
    _userPresence.remove(userId);
    _trackedUserIds.remove(userId);
    _lastRealtimeUpdate.remove(userId);
    notifyListeners();

    // Stop polling if no more users to track
    if (_trackedUserIds.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  /// Clear all presence state (used during account switching)
  void clear() {
    if (isDisposed) return;
    _userPresence.clear();
    _trackedUserIds.clear();
    _lastRealtimeUpdate.clear();
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
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
    final now = DateTime.now().toUtc();

    for (final userId in userIds) {
      if (isDisposed) return;

      // Skip polling if we got a fresh Realtime update in the last 10 seconds.
      // This prevents stale database records from flickering the UI state.
      final lastSync = _lastRealtimeUpdate[userId];
      if (lastSync != null && now.difference(lastSync).inSeconds < 10) {
        continue;
      }

      try {
        final result = await _presenceService.getUserStatus(userId);
        if (isDisposed) return;

        if (result != null) {
          final status = result['status'] as String? ?? 'offline';
          final lastSeenStr = result['last_seen'] as String?;
          final lastSeen = lastSeenStr != null
              ? DateTime.parse(lastSeenStr).toUtc()
              : null;

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
    notifyListeners();
  }
}
