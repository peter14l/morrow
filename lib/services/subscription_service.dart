import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/services/revenuecat_service.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class SubscriptionService extends ChangeNotifier {
  static SubscriptionService? _instance;

  final SupabaseClient? _client;
  bool _isPro = false;
  bool _isSideloaded = false;

  SubscriptionService._internal({SupabaseClient? client}) : _client = client;

  factory SubscriptionService({SupabaseClient? client}) {
    _instance ??= SubscriptionService._internal(client: client);
    return _instance!;
  }

  /// Use for testing purposes to reset the singleton.
  @visibleForTesting
  static void reset(SubscriptionService service) {
    _instance = service;
  }

  SupabaseClient get _supabase => _client ?? SupabaseService().client;
  bool get isPro => _isPro;
  bool get isSideloaded => _isSideloaded;

  @visibleForTesting
  void setProStatus(bool status) {
    _isPro = status;
    notifyListeners();
  }

  /// Updates the user's Pro status in the database
  Future<void> updateProStatus(bool status) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase
        .from(SupabaseConfig.profilesTable)
        .update({'is_pro': status})
        .eq('id', user.id);

    _isPro = status;
    notifyListeners();
  }

  Future<void> init() async {
    await _checkInstallationSource();
    await _updateProStatus();

    // Listen to Auth changes
    _supabase.auth.onAuthStateChange.listen((data) {
      _updateProStatus();
    });

    // Listen to RevenueCat changes
    RevenueCatService().addListener(() {
      _updateProStatus();
    });
  }

  Future<void> _checkInstallationSource() async {
    if (kIsWeb) {
      _isSideloaded = true;
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final installerStore = packageInfo.installerStore;

      if (Platform.isAndroid) {
        // If installerStore is null or not 'com.android.vending', it's likely an APK
        _isSideloaded =
            installerStore == null || installerStore != 'com.android.vending';
      } else if (Platform.isIOS) {
        // iOS is rarely sideloaded in production, but we can check for TestFlight/AppStore
        _isSideloaded = installerStore == null;
      } else {
        // Desktop is always "sideloaded" in this context (no store purchase yet)
        _isSideloaded = true;
      }

      debugPrint(
        'Installation Source: $installerStore, isSideloaded: $_isSideloaded',
      );
    } catch (e) {
      debugPrint('Error checking installation source: $e');
      _isSideloaded = true; // Default to sideloaded for safety
    }
    notifyListeners();
  }

  Future<void> _updateProStatus() async {
    // 1. Check RevenueCat (Primary source of truth now)
    bool status = RevenueCatService().isPro;

    // 2. Fallback to Supabase/Legacy logic if RevenueCat says false
    if (!status) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Check Auth Metadata (Secure app_metadata updated by triggers)
        final appMetadata = user.appMetadata;
        status = appMetadata['is_pro'] as bool? ?? false;

        // 2. If metadata says false, double check the profiles table (The Source of Truth)
        if (!status) {
          try {
            final profile = await _supabase
                .from(SupabaseConfig.profilesTable)
                .select('is_pro')
                .eq('id', user.id)
                .maybeSingle();
            if (profile != null) {
              status = profile['is_pro'] as bool? ?? false;
            }
          } catch (e) {
            debugPrint('Error double-checking Pro status: $e');
          }
        }
      }
    }

    _isPro = status;

    // Pitch Mode Override: Auto-grant Pro locally for demos
    if (AppConfig.isPitchMode) {
      _isPro = true;
    }

    notifyListeners();
  }

  /// Refreshes the Pro status from the server
  Future<void> refresh() async {
    await RevenueCatService().refresh();
    await _updateProStatus();
  }
}
