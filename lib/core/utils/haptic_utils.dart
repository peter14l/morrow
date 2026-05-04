import 'package:flutter/services.dart';

/// Utility class for providing consistent haptic feedback throughout the app
class HapticUtils {
  HapticUtils._();

  /// Light impact - for subtle UI interactions like tab selection
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - for confirmations like likes, bookmarks
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for significant actions like deleting, sending
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click - for picker selections, toggles
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate - for error states or warnings
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// Success feedback - medium impact for successful actions
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }

  /// Error feedback - vibrate for error states
  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }

  /// Like/reaction feedback - light impact for social interactions
  static Future<void> reaction() async {
    await HapticFeedback.lightImpact();
  }

  /// Navigation feedback - selection click for navigation changes
  static Future<void> navigation() async {
    await HapticFeedback.selectionClick();
  }

  /// Pull to refresh feedback
  static Future<void> pullToRefresh() async {
    await HapticFeedback.mediumImpact();
  }

  /// Message sent feedback
  static Future<void> messageSent() async {
    await HapticFeedback.lightImpact();
  }

  /// Heartbeat pulse pattern - 3 short pulses like a heartbeat (60 BPM feel)
  ///
  /// Used when user confirms "Yes, I reached home"
  static Future<void> heartbeatPulse() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Home arrived vibration - longer, celebratory pattern
  ///
  /// Escalating: light → medium → heavy → medium → light
  static Future<void> homeArrivedVibration() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Warning pulse - for "did not reach home" scenario
  ///
  /// Heavy impact × 2 with short delay
  static Future<void> warningPulse() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }
}
