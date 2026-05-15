import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

/// Privacy-first application analytics.
/// Uses Sentry as a proxy to avoid third-party trackers (like Google Analytics)
/// while still providing investors with key retention and engagement metrics.
class AppAnalytics {
  static final AppAnalytics _instance = AppAnalytics._internal();
  factory AppAnalytics() => _instance;
  AppAnalytics._internal();

  /// Logs a business-critical event.
  /// Events are anonymized to protect user privacy.
  Future<void> logEvent(String name, {Map<String, dynamic>? parameters}) async {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: $name | Params: $parameters');
    }

    // We use Sentry Messages with 'info' level to track custom events
    // This allows for cohort analysis in Sentry without adding a privacy-invasive SDK.
    await Sentry.captureMessage(
      'EVENT: $name',
      level: SentryLevel.info,
      withScope: (scope) {
        if (parameters != null) {
          parameters.forEach((key, value) {
            scope.setTag(key, value.toString());
          });
        }
        scope.setTag('event_type', 'business_metric');
      },
    );
  }

  /// Specialized event for session start
  void logSessionStart() => logEvent('session_start');

  /// Specialized event for calling (proves engagement)
  void logCallStarted(String type) =>
      logEvent('call_started', parameters: {'call_type': type});

  /// Specialized event for wellness (proves differentiator usage)
  void logWellnessGoalReached(String type) =>
      logEvent('wellness_goal_reached', parameters: {'goal_type': type});

  /// Specialized event for conversion
  void logSubscriptionStarted(String planId) =>
      logEvent('subscription_started', parameters: {'plan_id': planId});
}
