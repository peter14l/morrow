import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:oasis/features/couples/data/home_checkin_repository.dart';

/// Service for handling home check-in flow and partner notifications.
///
/// Orchestrates the check-in process:
/// 1. User arrives home (detected via GeofenceMonitorService)
/// 2. App shows verification dialog on open
/// 3. User confirms with "Yes" or "No"
/// 4. Partner receives notification about home status
///
/// Privacy: Home location is NEVER sent to server - only "at home" state is communicated.
class HomeCheckinService {
  final HomeCheckinRepository _repository;
  final PrefsStorage _prefs;

  static const String _keyLastCheckInTime = 'last_checkin_time';
  static const String _keyPendingVerification = 'pending_verification';
  static const String _keyLastArrivalTime = 'last_arrival_time';

  /// Callback when check-in is confirmed
  void Function()? onCheckInConfirmed;

  /// Callback when check-in is denied
  void Function()? onCheckInDenied;

  HomeCheckinService(this._repository, this._prefs);

  /// Check if there's a pending verification (user arrived home but hasn't responded yet)
  Future<bool> hasPendingVerification() async {
    return _prefs.readBool(_keyPendingVerification) ?? false;
  }

  /// Mark that user has arrived home and verification is pending
  ///
  /// Called when GeofenceMonitorService triggers onHomeArrived
  Future<void> markHomeArrived() async {
    final arrivalTime = DateTime.now().millisecondsSinceEpoch;
    await _prefs.writeInt(_keyLastArrivalTime, arrivalTime);
    await _prefs.writeBool(_keyPendingVerification, true);
    debugPrint(
      '[HomeCheckinService] Marked home arrived, verification pending',
    );
  }

  /// User confirms they actually reached home ("Yes" button)
  ///
  /// Sends notification to partner and plays heartbeat haptic
  Future<bool> checkIn() async {
    try {
      // Store check-in timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      await _prefs.writeInt(_keyLastCheckInTime, now);
      await _prefs.writeBool(_keyPendingVerification, false);

      // Clear pending verification
      await _prefs.writeBool(_keyPendingVerification, false);

      // Get partner info and send notification
      final partnerId = await _repository.getCouplePartnerId();
      if (partnerId != null) {
        await _repository.sendHomeArrivedNotification(partnerId);
        debugPrint(
          '[HomeCheckinService] Sent home arrival notification to partner',
        );
      } else {
        debugPrint(
          '[HomeCheckinService] No partner found, skipping notification',
        );
      }

      // Play heartbeat haptic pattern
      await HapticUtils.heartbeatPulse();

      // Invoke callback
      onCheckInConfirmed?.call();

      return true;
    } catch (e) {
      debugPrint('[HomeCheckinService] Check-in failed: $e');
      return false;
    }
  }

  /// User denies they reached home ("No" button)
  ///
  /// Sends warning notification to partner
  Future<bool> verifyCheckIn({required bool wasAccurate}) async {
    try {
      // Clear pending verification
      await _prefs.writeBool(_keyPendingVerification, false);

      if (!wasAccurate) {
        // User says they didn't actually reach home - warn partner
        final partnerId = await _repository.getCouplePartnerId();
        if (partnerId != null) {
          await _repository.sendNotReachedHomeNotification(partnerId);
          debugPrint(
            '[HomeCheckinService] Sent "not reached home" warning to partner',
          );
        }

        // Play warning haptic pattern
        await HapticUtils.warningPulse();
      }

      // Invoke callback
      onCheckInDenied?.call();

      return true;
    } catch (e) {
      debugPrint('[HomeCheckinService] Verify check-in failed: $e');
      return false;
    }
  }

  /// Get last check-in time
  Future<DateTime?> getLastCheckInTime() async {
    final timestamp = _prefs.readInt(_keyLastCheckInTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Get time when user last arrived home (before verification)
  Future<DateTime?> getLastArrivalTime() async {
    final timestamp = _prefs.readInt(_keyLastArrivalTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Clear pending verification (e.g., after some time or manual clear)
  Future<void> clearPendingVerification() async {
    await _prefs.writeBool(_keyPendingVerification, false);
  }

  /// Check if a recent arrival event exists (within last hour)
  Future<bool> hasRecentArrival() async {
    final arrivalTime = await getLastArrivalTime();
    if (arrivalTime == null) return false;

    final now = DateTime.now();
    final diff = now.difference(arrivalTime);
    return diff.inMinutes < 60;
  }
}
