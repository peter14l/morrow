import 'package:flutter/foundation.dart';

/// Centralized application configuration.
///
/// Driven by environment variables for production readiness.
class AppConfig {
  AppConfig._();

  /// The current app version from package info
  /// This is populated at runtime from package_info_plus
  static String appVersion = '0.0.0';

  /// If false, calling features are disabled (e.g. during major platform stability fixes)
  static bool enableCalls = true;

  /// If true, the app runs in "Investor Pitch Mode"
  /// - Silences harmless debug logs
  /// - Auto-grants local Pro status for demo purposes
  /// - Pre-loads demo content triggers
  static bool get isPitchMode {
    const fromEnv = bool.fromEnvironment('PITCH_MODE', defaultValue: false);
    return fromEnv || kDebugMode; // Default to true in debug for testing
  }

  /// The base URL for the web portal/landing page.
  /// Used for deep links, auth callbacks, and checkout redirects.
  static String get webBaseUrl {
    const fromEnv = String.fromEnvironment('WEB_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    return 'https://oasis-web-red.vercel.app';
  }

  /// URL to check for app updates
  static String get updateCheckUrl {
    const fromEnv = String.fromEnvironment('UPDATE_CHECK_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kDebugMode) return 'http://localhost:3000/api/check-update';
    return '';
  }

  /// Helper to generate a full URL for specific paths.
  static String getWebUrl(String path) {
    final base = webBaseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$normalizedBase$normalizedPath';
  }
}
