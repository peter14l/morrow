import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevenueCatService extends ChangeNotifier {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  bool get isPro =>
      _customerInfo?.entitlements.active.containsKey('Oasis Pro') ?? false;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    String? apiKey;
    if (Platform.isAndroid) {
      apiKey = dotenv.env['REVENUECAT_GOOGLE_API_KEY'];
    } else if (Platform.isIOS || Platform.isMacOS) {
      apiKey = dotenv.env['REVENUECAT_APPLE_API_KEY'];
    }

    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('RevenueCat API Key not found for this platform.');
      return;
    }

    PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);

    // Identify user with Supabase ID if logged in
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      configuration.appUserID = currentUser.id;
    }

    try {
      await Purchases.configure(configuration);
      _isInitialized = true;

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener((info) {
        _customerInfo = info;
        notifyListeners();
      });

      // Refresh with timeout
      await refresh().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('RevenueCat refresh() timed out after 10 seconds');
        },
      );
    } catch (e) {
      debugPrint('Error configuring RevenueCat: $e');
    }
  }

  Future<void> refresh() async {
    if (!_isInitialized) return;
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing RevenueCat data: $e');
    }
  }

  /// Purchase a package
  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result.customerInfo;
      notifyListeners();
      return isPro;
    } catch (e) {
      debugPrint('Purchase failed: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      _customerInfo = await Purchases.restorePurchases();
      notifyListeners();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  /// Identify user
  Future<void> identify(String userId) async {
    try {
      final result = await Purchases.logIn(userId);
      _customerInfo = result.customerInfo;
      notifyListeners();
    } catch (e) {
      debugPrint('Identification failed: $e');
    }
  }

  /// Clean up on logout
  Future<void> logout() async {
    try {
      await Purchases.logOut();
      _customerInfo = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }
}
