import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:win_toast/win_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:oasis/routes/app_router.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Handles incoming call notifications on Windows, macOS, and Linux.
///
/// On Android/iOS this is handled by [FlutterCallkitIncoming].
/// On desktop/web the strategy is:
///   - **Windows**  : WinToast notification (no action buttons in v0.0.1) +
///                    bring window to front so the in-app overlay takes over.
///   - **macOS**    : flutter_local_notifications with Accept / Decline actions
///                    registered under the CALL_CATEGORY.
///   - **Linux**    : notify-send (informational only — no action buttons).
///   - **Foreground**: navigate directly to the CallingScreen via GoRouter so
///                    the in-app incoming-call UI appears immediately.
class DesktopCallNotifier {
  DesktopCallNotifier._();
  static final DesktopCallNotifier instance = DesktopCallNotifier._();

  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  bool get _isLinux => !kIsWeb && Platform.isLinux;
  bool get _supported => _isWindows || _isMacOS || _isLinux;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Call this when an incoming call is detected on a non-mobile platform.
  ///
  /// [callerName] is shown in the OS notification.
  /// [senderId] (hostId) is forwarded to the CallingScreen so it can look up
  /// the peer profile.
  Future<void> handleIncomingCall({
    required String callId,
    required String callerName,
    String? senderId,
  }) async {
    if (!_supported) return;

    // 1. Show an OS-level notification so the user is alerted even if the app
    //    window is minimised to the system tray.
    await _showOsNotification(
      callId: callId,
      callerName: callerName,
      senderId: senderId,
    );

    // 2. If the app window is already in the foreground, navigate directly to
    //    the CallingScreen so the in-app incoming-call UI appears immediately.
    //    GoRouter uses the global navigator key — no BuildContext required.
    _navigateToCallScreen(callId: callId, senderId: senderId);
  }

  /// Dismiss the incoming-call notification (e.g. call was answered / declined
  /// / missed before the user interacted with the OS notification).
  Future<void> dismissIncomingCall() async {
    if (!_supported) return;

    if (_isMacOS) {
      await NotificationManager.instance.dismissCallNotification();
    }
    // Windows / Linux: no reliable programmatic dismiss for simple toasts.
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _showOsNotification({
    required String callId,
    required String callerName,
    String? senderId,
  }) async {
    if (_isWindows) {
      await _showWindowsToast(
        callId: callId,
        callerName: callerName,
        senderId: senderId,
      );
    } else if (_isMacOS) {
      await NotificationManager.instance.showCallNotification(
        callId: callId,
        callerName: callerName,
        senderId: senderId,
      );
    } else if (_isLinux) {
      await _showLinuxNotification(callerName: callerName);
    }
  }

  Future<void> _showWindowsToast({
    required String callId,
    required String callerName,
    String? senderId,
  }) async {
    try {
      // win_toast 0.0.1 does not support custom XML or action buttons.
      // Clicking the toast brings the app window to the foreground; at that
      // point the in-app incoming-call overlay (driven by CallService) takes over.
      await WinToast.instance().showToast(
        type: ToastType.text02,
        title: '📞 Incoming Call',
        subtitle: '$callerName is calling...',
      );

      // Bring the window to the front so the user can interact with the
      // in-app Accept / Decline UI without needing to find the taskbar icon.
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('[DesktopCallNotifier] Windows toast failed: $e');
    }
  }

  Future<void> _showLinuxNotification({required String callerName}) async {
    try {
      await Process.run('notify-send', [
        '--app-name=Oasis',
        '--urgency=critical',
        '--expire-time=30000',
        '--icon=phone',
        '📞 Incoming Call',
        '$callerName is calling...',
      ]);
    } catch (e) {
      debugPrint('[DesktopCallNotifier] Linux notify-send failed: $e');
    }
  }

  void _navigateToCallScreen({required String callId, String? senderId}) {
    try {
      AppRouter.router.pushNamed(
        'active_call',
        pathParameters: {'callId': callId},
        extra: {'isIncoming': true, 'callerId': senderId},
      );
    } catch (e) {
      // Navigation may fail if the navigator is not yet mounted (e.g. the app
      // is still warming up). The OS notification still alerts the user.
      debugPrint('[DesktopCallNotifier] Navigation to call screen failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Static helpers called from NotificationManager action callbacks
  // ---------------------------------------------------------------------------

  /// Accept the call from a macOS notification action.
  static void acceptFromNotification(String callId, String? senderId) {
    try {
      AppRouter.router.pushNamed(
        'active_call',
        pathParameters: {'callId': callId},
        extra: {'isIncoming': true, 'callerId': senderId},
      );
    } catch (e) {
      debugPrint('[DesktopCallNotifier] acceptFromNotification nav failed: $e');
    }
  }

  /// Decline the call from a macOS notification action.
  static void declineFromNotification(String callId) {
    try {
      SupabaseService().client
          .from('calls')
          .update({'status': 'declined'})
          .eq('id', callId);
    } catch (e) {
      debugPrint('[DesktopCallNotifier] declineFromNotification failed: $e');
    }
  }
}
