import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import '../models/user_customization.dart';

class CustomizationService extends ChangeNotifier {
  static CustomizationService? _instance;
  final SupabaseClient _supabase;
  List<UserCustomization> _ownedItems = [];
  bool _isLoading = false;

  CustomizationService._internal({SupabaseClient? client})
      : _supabase = client ?? SupabaseService().client;

  factory CustomizationService({SupabaseClient? client}) {
    _instance ??= CustomizationService._internal(client: client);
    return _instance!;
  }

  List<UserCustomization> get ownedItems => _ownedItems;
  bool get isLoading => _isLoading;

  /// Fetch user customizations from Supabase
  Future<void> fetchOwnedCustomizations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('user_customizations')
          .select()
          .eq('user_id', user.id);

      _ownedItems = (response as List)
          .map((json) => UserCustomization.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('[CustomizationService] Error fetching items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has purchased/unlocked a specific cosmetic item
  bool hasItem(String itemId) {
    return _ownedItems.any((item) => item.itemId == itemId);
  }

  /// Check if a specific cosmetic item is currently selected/active
  bool isItemActive(String itemId) {
    return _ownedItems.any((item) => item.itemId == itemId && item.isActive);
  }

  /// Activate/select a cosmetic item
  Future<void> activateItem(String itemId, String itemType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Deactivate all other items of the same type first
      await _supabase
          .from('user_customizations')
          .update({'is_active': false})
          .eq('user_id', user.id)
          .eq('item_type', itemType);

      // Activate selected item
      await _supabase
          .from('user_customizations')
          .update({'is_active': true})
          .eq('user_id', user.id)
          .eq('item_id', itemId);

      await fetchOwnedCustomizations();
    } catch (e) {
      debugPrint('[CustomizationService] Error activating item: $e');
    }
  }

  /// Record a mock purchase (or hook into Razorpay/IAP callback)
  Future<bool> purchaseItem(String itemId, String itemType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      await _supabase.from('user_customizations').upsert({
        'user_id': user.id,
        'item_type': itemType,
        'item_id': itemId,
        'is_active': false,
      });

      await fetchOwnedCustomizations();
      return true;
    } catch (e) {
      debugPrint('[CustomizationService] Error purchasing item: $e');
      return false;
    }
  }

  /// Purchase Circle Boost consumable tokens
  Future<bool> purchaseCircleBoosts(int count) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // In a real database, this would increment a user's boost balance.
      // For this implementation, we upsert/insert the raw tokens or custom item count.
      await _supabase.rpc('increment_user_boosts', params: {
        'user_id': user.id,
        'boost_count': count,
      });
      return true;
    } catch (e) {
      debugPrint('[CustomizationService] Error purchasing boosts: $e');
      return false;
    }
  }
}
