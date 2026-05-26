import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class IAPService extends ChangeNotifier {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  List<Package> _packages = [];
  List<Package> get packages => _packages;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    try {
      // Basic availability check
      _isAvailable = await Purchases.isConfigured;
      notifyListeners();
    } catch (e) {
      debugPrint('IAP not available on this platform: $e');
      _isAvailable = false;
    }
  }

  Future<void> fetchProducts() async {
    if (!_isAvailable) return;

    try {
      final Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        _packages = offerings.current!.availablePackages;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
    }
  }

  Future<void> buyProduct(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } catch (e) {
      debugPrint('Purchase failed: $e');
    }
  }

  Future<void> restorePurchases() async {
    try {
      await Purchases.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

}
