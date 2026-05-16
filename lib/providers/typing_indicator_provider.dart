import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

class TypingIndicatorProvider with ChangeNotifier, SafeChangeNotifier {
  final MessagingService _messagingService = MessagingService();

  // Map of conversationId -> isTyping status
  final Map<String, bool> _typingStatus = {};

  // Map of conversationId -> RealtimeChannel
  final Map<String, RealtimeChannel> _subscriptions = {};

  // Debounce timers for stopping typing indicator
  final Map<String, Timer> _debounceTimers = {};

  // Local throttle to avoid spamming the database while typing
  final Map<String, DateTime> _lastDatabaseUpdate = {};

  // Polling fallback for typing indicator sync (when realtime fails)
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 5);
  final Set<String> _trackedConversationIds = {};

  // Getters
  bool isUserTyping(String conversationId) {
    return _typingStatus[conversationId] ?? false;
  }

  /// Set typing status for current user in a conversation
  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    try {
      // Throttle database updates to once every 2 seconds when typing
      final lastUpdate = _lastDatabaseUpdate[conversationId];
      if (isTyping &&
          lastUpdate != null &&
          DateTime.now().difference(lastUpdate).inSeconds < 2) {
        // Reset the auto-stop timer but don't hit the DB yet
        _debounceTimers[conversationId]?.cancel();
        _debounceTimers[conversationId] = Timer(const Duration(seconds: 4), () {
          setTyping(conversationId, userId, false);
        });
        return;
      }

      // Cancel existing debounce timer
      _debounceTimers[conversationId]?.cancel();

      // Update typing status via Realtime Broadcast (Zero IOPS)
      final channel = _subscriptions[conversationId];
      if (channel != null) {
        await _messagingService.sendTypingStatus(channel, userId, isTyping);
      } else {
        // Fallback to DB if subscription isn't ready (should be rare)
        await _messagingService.updateTypingStatus(
          conversationId,
          userId,
          isTyping,
        );
      }

      _lastDatabaseUpdate[conversationId] = DateTime.now();

      // If typing, set a timer to auto-stop after 4 seconds of inactivity
      if (isTyping) {
        _debounceTimers[conversationId] = Timer(const Duration(seconds: 4), () {
          setTyping(conversationId, userId, false);
        });
      } else {
        _lastDatabaseUpdate.remove(conversationId);
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  /// Subscribe to typing status updates for a conversation
  void subscribeToTypingStatus(String conversationId, String currentUserId) {
    if (isDisposed) return;
    // Don't subscribe if already subscribed
    if (_subscriptions.containsKey(conversationId)) {
      return;
    }

    // Track conversation for polling fallback
    _trackedConversationIds.add(conversationId);

    try {
      final channel = _messagingService.subscribeToTypingStatus(
        conversationId: conversationId,
        onTypingUpdate: (userId, isTyping) {
          if (isDisposed) return;
          // Only update if it's the other user typing (not current user)
          if (userId != currentUserId) {
            _typingStatus[conversationId] = isTyping;
            notifyListeners();

            // Auto-clear typing status after 5 seconds if still showing
            if (isTyping) {
              Future.delayed(const Duration(seconds: 5), () {
                if (isDisposed) return;
                if (_typingStatus[conversationId] == true) {
                  _typingStatus[conversationId] = false;
                  notifyListeners();
                }
              });
            }
          }
        },
      );

      _subscriptions[conversationId] = channel;

      // Start polling fallback if not started
      _startPollingFallback(currentUserId);
    } catch (e) {
      debugPrint('Error subscribing to typing status: $e');
    }
  }

  /// Unsubscribe from typing status updates
  Future<void> unsubscribeFromTypingStatus(String conversationId) async {
    if (isDisposed) return;
    final channel = _subscriptions[conversationId];
    if (channel != null) {
      await _messagingService.unsubscribeFromTypingStatus(channel);
      _subscriptions.remove(conversationId);
      _typingStatus.remove(conversationId);
      _trackedConversationIds.remove(conversationId);
      _debounceTimers[conversationId]?.cancel();
      _debounceTimers.remove(conversationId);
      notifyListeners();
    }
  }

  /// Clear all subscriptions
  Future<void> clearAll({bool isDisposing = false}) async {
    for (final conversationId in _subscriptions.keys.toList()) {
      final channel = _subscriptions[conversationId];
      if (channel != null) {
        await _messagingService.unsubscribeFromTypingStatus(channel);
      }
    }
    _subscriptions.clear();
    _typingStatus.clear();
    _trackedConversationIds.clear();
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    if (!isDisposing) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // We don't await clearAll here because dispose must be sync.
    // The SafeChangeNotifier will prevent notifyListeners from crashing.
    clearAll(isDisposing: true);
    
    super.dispose();
  }

  /// Start polling fallback to sync typing status when realtime fails.
  void _startPollingFallback(String currentUserId) {
    if (_pollingTimer != null) return; // Already running

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      _pollTypingStatus(currentUserId);
    });
  }

  /// Poll typing status directly from database.
  Future<void> _pollTypingStatus(String currentUserId) async {
    final conversationIds = _trackedConversationIds.toList();
    for (final conversationId in conversationIds) {
      try {
        final result = await _messagingService.getTypingStatus(
          conversationId,
          currentUserId,
        );

        if (result != null) {
          final isTyping = result['is_typing'] as bool? ?? false;
          final userId = result['user_id'] as String?;

          if (userId != null && userId != currentUserId) {
            _typingStatus[conversationId] = isTyping;
          }
        } else {
          // No typing - clear
          if (_typingStatus[conversationId] == true) {
            _typingStatus[conversationId] = false;
          }
        }
      } catch (e) {
        debugPrint('[TypingIndicatorProvider] Polling error: $e');
      }
    }
    notifyListeners();
  }
}
