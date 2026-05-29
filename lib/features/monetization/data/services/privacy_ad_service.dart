import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import '../models/ad_campaign.dart';

/// Brave-style on-device privacy-preserving ad matching engine.
///
/// Key privacy properties:
/// - Fetches the full ad catalog in bulk (no per-user targeting data sent to server)
/// - Matches ads LOCALLY based on current screen context only
/// - Never sends any user data, behavior, or identity to the ad server
/// - No cookies, no tracking pixels, no third-party SDKs
class PrivacyAdService extends ChangeNotifier {
  static PrivacyAdService? _instance;

  final _supabase = SupabaseService().client;
  List<AdCampaign> _cachedCampaigns = [];
  DateTime? _lastFetched;
  bool _isLoading = false;

  PrivacyAdService._internal();

  factory PrivacyAdService() {
    _instance ??= PrivacyAdService._internal();
    return _instance!;
  }

  List<AdCampaign> get cachedCampaigns => _cachedCampaigns;
  bool get isLoading => _isLoading;

  /// Fetches the ad catalog from Supabase in bulk.
  /// Only re-fetches if the cache is older than 1 hour.
  Future<void> fetchAdCatalog({bool force = false}) async {
    final now = DateTime.now();
    final cacheAge = _lastFetched != null
        ? now.difference(_lastFetched!).inMinutes
        : 999;

    if (!force && cacheAge < 60 && _cachedCampaigns.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('ad_campaigns')
          .select()
          .eq('is_active', true);

      _cachedCampaigns = (response as List)
          .map((json) => AdCampaign.fromJson(json))
          .where((ad) => ad.endDate.isAfter(now))
          .toList();

      _lastFetched = now;
      debugPrint('[PrivacyAdService] Fetched ${_cachedCampaigns.length} campaigns.');
    } catch (e) {
      debugPrint('[PrivacyAdService] Failed to fetch catalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Matches an ad LOCALLY based on the current screen's category.
  ///
  /// [screenCategory] - The current context: 'wellness', 'feed', 'chat', 'circles'
  ///
  /// No user data, device ID, or profile information is involved in this decision.
  /// The server never knows which ad was shown or to whom.
  AdCampaign? matchAdLocally({required String screenCategory}) {
    if (_cachedCampaigns.isEmpty) return null;

    final matches = _cachedCampaigns
        .where((ad) => ad.categoryTarget == screenCategory)
        .toList();

    // Fallback: show any available ad if no category match
    final pool = matches.isNotEmpty ? matches : _cachedCampaigns;
    if (pool.isEmpty) return null;

    return pool[Random().nextInt(pool.length)];
  }
}
