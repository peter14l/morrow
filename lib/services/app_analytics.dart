import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics service for the app.
/// Wraps Firebase Analytics to provide a clean API for logging events.
class AppAnalytics {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: _analytics);

  static bool get _isSupported {
    if (kIsWeb) return true;
    // Firebase Analytics officially supports Web, Android, iOS, and macOS.
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// Logs a custom event.
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isSupported) return;
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (kDebugMode) {
        debugPrint('Analytics: Logged event $name with params $parameters');
      }
    } catch (e) {
      debugPrint('Analytics Error: Failed to log event $name: $e');
    }
  }

  /// Logs an app open event.
  Future<void> logAppOpen() async {
    if (!_isSupported) return;
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('Analytics Error: Failed to log app open: $e');
    }
  }

  /// Sets the user ID for analytics.
  Future<void> setUserId(String? userId) async {
    if (!_isSupported) return;
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics Error: Failed to set user ID: $e');
    }
  }

  /// Sets a user property.
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_isSupported) return;
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics Error: Failed to set user property $name: $e');
    }
  }

  /// Logs a screen view.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isSupported) return;
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? 'Flutter',
      );
    } catch (e) {
      debugPrint('Analytics Error: Failed to log screen view $screenName: $e');
    }
  }
}
