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
  static bool enableCalls = false;

  /// If true, the first-party privacy-preserving contextual ad engine is active.
  /// Ads are matched locally on-device — no user data is ever sent to ad servers.
  static bool get enablePrivacyAds {
    const fromEnv = bool.fromEnvironment('ENABLE_PRIVACY_ADS', defaultValue: true);
    return fromEnv;
  }

  /// If true, the Oasis Aura cosmetic shop and Circle Boosting system is enabled.
  static bool get enableOasisAura {
    const fromEnv = bool.fromEnvironment('ENABLE_OASIS_AURA', defaultValue: true);
    return fromEnv;
  }


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

  /// LiveKit Server URL
  static String get liveKitUrl {
    const fromEnv = String.fromEnvironment('LIVEKIT_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'wss://oasis-calling.livekit.cloud'; // Default placeholder
  }

  /// Supabase project URL for function calls
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    return fromEnv;
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
