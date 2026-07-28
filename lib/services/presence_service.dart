import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/supabase_config.dart';

class PresenceService {
  final SupabaseClient _supabase = SupabaseService().client;
  final Map<String, RealtimeChannel> _presenceChannels = {};

  // Track subscription state to prevent race conditions
  final Map<String, bool> _channelSubscribed = {};

  // Track last update time and status to prevent rapid status toggling
  final Map<String, DateTime> _lastUpdateTime = {};
  final Map<String, String> _lastStatus = {};

  // Minimum interval between presence updates to prevent spam
  static const _minUpdateInterval = Duration(seconds: 1);

  /// Fetches the current status of a user from the database (polling fallback)
  Future<Map<String, dynamic>?> getUserStatus(String userId) async {
    if (userId.isEmpty) return null;
    try {
      return await _supabase
          .from(SupabaseConfig.userStatusTable)
          .select('status, last_seen')
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('[PresenceService] Error fetching user status: $e');
      return null;
    }
  }

  // Track a user's presence in a specific conversation or globally
  RealtimeChannel subscribeToUserPresence({
    required String userId,
    required Function(String status, DateTime? lastSeen) onUpdate,
  }) {
    final channelName = 'user_presence:$userId';

    if (_presenceChannels.containsKey(channelName)) {
      return _presenceChannels[channelName]!;
    }

    final channel = _supabase.channel(channelName);

    // Use debounce to avoid false offline during initial sync
    Timer? emptyStateDebounce;

    channel
        .onPresenceSync((payload) {
          // Clear any pending empty state timer
          emptyStateDebounce?.cancel();

          final presenceState = channel.presenceState();
          if (presenceState.isEmpty) {
            // Debounce empty state - might be initial sync, wait 500ms
            emptyStateDebounce = Timer(const Duration(milliseconds: 500), () {
              onUpdate('offline', null);
            });
            return;
          }

          // Check if any session for this user is online
          bool isOnline = false;
          DateTime? latestSeen;

          for (final singlePresence in presenceState) {
            for (final presence in singlePresence.presences) {
              final status = presence.payload['status'] as String?;
              if (status == 'online') {
                isOnline = true;
              }
              final lastSeenStr = presence.payload['last_seen'] as String?;
              if (lastSeenStr != null) {
                final lastSeen = DateTime.parse(lastSeenStr);
                if (latestSeen == null || lastSeen.isAfter(latestSeen)) {
                  latestSeen = lastSeen;
                }
              }
            }
          }

          onUpdate(isOnline ? 'online' : 'offline', latestSeen);
        })
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint(
              'PresenceService: subscribeToUserPresence error: $error',
            );
          } else if (status == RealtimeSubscribeStatus.subscribed) {
            _channelSubscribed[channelName] = true;
          }
        });

    _presenceChannels[channelName] = channel;
    _channelSubscribed[channelName] = false;
    return channel;
  }

  // Update current user's presence
  Future<void> updateUserPresence(String userId, String status) async {
    if (userId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final lastUpdate = _lastUpdateTime[userId];
    final lastStatus = _lastStatus[userId];

    // Rate limit: skip if updated too recently AND status is the same
    // This allows rapid status changes (offline -> online) while still preventing spam
    if (lastUpdate != null &&
        now.difference(lastUpdate) < _minUpdateInterval &&
        lastStatus == status) {
      return;
    }

    final channelName = 'user_presence:$userId';
    RealtimeChannel channel;

    if (_presenceChannels.containsKey(channelName)) {
      channel = _presenceChannels[channelName]!;
    } else {
      channel = _supabase.channel(channelName);
      _presenceChannels[channelName] = channel;
    }

    // Check if we're already subscribed (track in our map)
    final isAlreadySubscribed = _channelSubscribed[channelName] == true;

    if (!isAlreadySubscribed) {
      try {
        channel.subscribe();
        _channelSubscribed[channelName] = true;
        // Wait for subscription confirmation (max 200ms)
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // Check if it's the "already subscribed" error - this is OK
        if (e.toString().contains('already been subscribed')) {
          _channelSubscribed[channelName] = true;
        } else {
          debugPrint('PresenceService: subscribe error - ${e.toString()}');
        }
      }
    }

    final timestamp = DateTime.now().toUtc().toIso8601String();

    try {
      await channel.track({'status': status, 'last_seen': timestamp});

      // Also upsert to user_status table for polling fallback
      unawaited(
        _supabase
            .from(SupabaseConfig.userStatusTable)
            .upsert({
              'user_id': userId,
              'status': status,
              'last_seen': timestamp,
            })
            .catchError((e) {
              debugPrint(
                'PresenceService: Table upsert error - ${e.toString()}',
              );
            }),
      );
    } catch (e) {
      // Retry once after brief delay
      debugPrint('PresenceService: Retry presence after - ${e.toString()}');
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        await channel.track({'status': status, 'last_seen': timestamp});
      } catch (e2) {
        debugPrint(
          'PresenceService: Failed to track presence - ${e2.toString()}',
        );
      }
    }

    // Only update last update time AFTER the async track completes
    // This ensures rapid state changes (background->foreground) are not rate-limited
    _lastUpdateTime[userId] = DateTime.now().toUtc();
    _lastStatus[userId] = status;
  }

  void unsubscribeFromPresence(String userId) {
    if (userId.isEmpty) return;
    final channelName = 'user_presence:$userId';
    if (_presenceChannels.containsKey(channelName)) {
      _supabase.removeChannel(_presenceChannels[channelName]!);
      _presenceChannels.remove(channelName);
      _channelSubscribed.remove(channelName);
      _lastUpdateTime.remove(userId);
      _lastStatus.remove(userId);
    }
  }
}
