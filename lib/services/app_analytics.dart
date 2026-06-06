import 'package:universal_io/io.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';

/// Centralized analytics service for the app.
/// Wraps Firebase Analytics to provide a clean API for logging events.
class AppAnalytics {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Navigation observer for tracking screen views.
  /// Returns null on unsupported platforms (like Windows).
  static NavigatorObserver? get observer {
    if (!_isSupported) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

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
    // Log to console in debug mode regardless of platform
    if (kDebugMode) {
      debugPrint('Analytics: Event $name with params $parameters');
    }

    if (_isSupported) {
      try {
        await _analytics.logEvent(name: name, parameters: parameters);
      } catch (e) {
        debugPrint(
          'Analytics Error: Failed to log event $name to Firebase: $e',
        );
      }
    } else if (Platform.isWindows) {
      // Fallback for Windows: Log as a Sentry breadcrumb and event
      try {
        await Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Analytics Event: $name',
            category: 'analytics',
            data: parameters,
            level: SentryLevel.info,
          ),
        );
        // Optionally log as a captured message for high-visibility events
        // Sentry.captureMessage('Event: $name', level: SentryLevel.info);
      } catch (e) {
        debugPrint('Analytics Error: Failed to log event $name to Sentry: $e');
      }
    }
  }

  /// Logs an app open event.
  Future<void> logAppOpen() async {
    if (kDebugMode) debugPrint('Analytics: logAppOpen');

    if (_isSupported) {
      try {
        await _analytics.logAppOpen();
      } catch (e) {
        debugPrint('Analytics Error: Failed to log app open to Firebase: $e');
      }
    } else if (Platform.isWindows) {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'App Opened',
          category: 'analytics',
          level: SentryLevel.info,
        ),
      );
    }
  }

  /// Sets the user ID for analytics.
  Future<void> setUserId(String? userId) async {
    if (_isSupported) {
      try {
        await _analytics.setUserId(id: userId);
      } catch (e) {
        debugPrint('Analytics Error: Failed to set user ID in Firebase: $e');
      }
    }

    // Always set user in Sentry for all platforms
    try {
      Sentry.configureScope((scope) {
        scope.setUser(userId != null ? SentryUser(id: userId) : null);
      });
    } catch (e) {
      debugPrint('Analytics Error: Failed to set user ID in Sentry: $e');
    }
  }

  /// Sets a user property.
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (_isSupported) {
      try {
        await _analytics.setUserProperty(name: name, value: value);
      } catch (e) {
        debugPrint(
          'Analytics Error: Failed to set user property $name in Firebase: $e',
        );
      }
    }

    if (Platform.isWindows) {
      Sentry.configureScope((scope) {
        scope.setContexts('user_properties', {name: value});
      });
    }
  }

  /// Logs a screen view.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (kDebugMode) debugPrint('Analytics: ScreenView $screenName');

    if (_isSupported) {
      try {
        await _analytics.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? 'Flutter',
        );
      } catch (e) {
        debugPrint(
          'Analytics Error: Failed to log screen view $screenName in Firebase: $e',
        );
      }
    } else if (Platform.isWindows) {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Screen View: $screenName',
          category: 'navigation',
          level: SentryLevel.info,
        ),
      );
    }
  }
}
