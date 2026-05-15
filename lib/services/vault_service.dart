import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/subscription_service.dart';

import 'package:oasis/core/storage/secure_storage.dart';

/// Vault mode service for biometric protection of sensitive content
class VaultService with ChangeNotifier {
  final _storage = SecureStorage();
  final _supabase = SupabaseService().client;

  static const _vaultEnabledKey = 'vault_enabled';
  static const _vaultItemsKey = 'vault_items';
  static const _vaultPinKey = 'vault_pin';
  static const _vaultIntervalsKey = 'vault_intervals';

  final Set<String> _unlockedItemIds = {};
  final Set<String> _vaultItemIds = {};
  final Map<String, String> _itemIntervals = {};
  final Map<String, Timer?> _lockTimers = {};

  Completer<void>? _initCompleter;
  bool _isInitDone = false;

  VaultService();

  Future<void> get isReady async {
    if (_isInitDone) return;
    return _initCompleter?.future;
  }

  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    debugPrint('[VaultService] Initializing...');
    await _loadIntervals();
    await _refreshVaultItemCache();

    final enabled = await isVaultEnabled();
    debugPrint('[VaultService] Initialization complete. Enabled: $enabled');

    _isInitDone = true;
    _initCompleter!.complete();
    return _initCompleter!.future;
  }

  Future<void> _refreshVaultItemCache() async {
    final items = await _getVaultItems();
    _vaultItemIds.clear();
    _vaultItemIds.addAll(items.map((i) => i.id));
    scheduleMicrotask(() => notifyListeners());
  }

  Future<void> _loadIntervals() async {
    final intervalsJson = await _storage.read(key: _vaultIntervalsKey);
    if (intervalsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(intervalsJson);
        decoded.forEach((key, value) {
          // Ensure keys are normalized when loading from storage
          _itemIntervals[_normalizeId(key)] = value.toString();
        });
      } catch (e) {
        debugPrint('[VaultService] Error loading intervals: $e');
      }
    }
  }

  Future<void> _saveIntervals() async {
    // Keys in _itemIntervals are already normalized by setLockInterval
    await _storage.write(
      key: _vaultIntervalsKey,
      value: jsonEncode(_itemIntervals),
    );
  }

  /// Check if vault is enabled
  Future<bool> isVaultEnabled() async {
    try {
      final enabled = await _storage.read(key: _vaultEnabledKey);
      return enabled == 'true';
    } catch (e) {
      debugPrint('[VaultService] Error reading enabled status: $e');
      return false;
    }
  }

  /// Enable vault mode
  Future<void> enableVault({String? pin}) async {
    debugPrint('[VaultService] Enabling vault...');
    await _storage.write(key: _vaultEnabledKey, value: 'true');
    if (pin != null) {
      await _storage.write(key: _vaultPinKey, value: pin);
    }
    scheduleMicrotask(() => notifyListeners());
  }

  /// Disable vault mode
  Future<void> disableVault() async {
    debugPrint('[VaultService] Disabling vault...');
    await _storage.write(key: _vaultEnabledKey, value: 'false');
    await _storage.delete(key: _vaultPinKey);
    _unlockedItemIds.clear();
    _itemIntervals.clear();

    // Safety: use toList() for concurrent mod protection
    final timers = _lockTimers.values.toList();
    for (final timer in timers) {
      timer?.cancel();
    }
    _lockTimers.clear();

    await _storage.delete(key: _vaultIntervalsKey);
    scheduleMicrotask(() => notifyListeners());
  }

  /// Unlock specific item with PIN
  Future<bool> unlockItemWithPin(String itemId, String pin) async {
    final storedPin = await _storage.read(key: _vaultPinKey);
    if (storedPin == pin) {
      _unlockItem(itemId);
      return true;
    }
    return false;
  }

  /// Unlock vault globally with PIN (e.g. for settings)
  Future<bool> unlockVaultWithPin(String pin) async {
    final storedPin = await _storage.read(key: _vaultPinKey);
    return storedPin == pin;
  }

  /// Change the vault PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    final storedPin = await _storage.read(key: _vaultPinKey);

    if (storedPin != currentPin) {
      return false;
    }

    await _storage.write(key: _vaultPinKey, value: newPin);
    return true;
  }

  String _normalizeId(String id) => id.trim().toLowerCase();

  void _unlockItem(String itemId) {
    final id = _normalizeId(itemId);
    _unlockedItemIds.add(id);

    // Handle 5 mins interval
    final interval = getLockInterval(id);
    if (interval == '5mins') {
      _lockTimers[id]?.cancel();
      _lockTimers[id] = Timer(const Duration(minutes: 5), () {
        lockItem(id);
      });
    }

    scheduleMicrotask(() => notifyListeners());
  }

  /// Check if a specific item is unlocked
  bool isItemUnlocked(String itemId) =>
      _unlockedItemIds.contains(_normalizeId(itemId));

  /// Check vault lock status (deprecated or for global UI)
  bool get isUnlocked => _unlockedItemIds.isNotEmpty;

  /// Lock specific item
  void lockItem(String itemId) {
    final id = _normalizeId(itemId);
    if (!_unlockedItemIds.contains(id)) return;

    _unlockedItemIds.remove(id);
    _lockTimers[id]?.cancel();
    _lockTimers.remove(id);

    debugPrint('Vault: Locked item $id');
    scheduleMicrotask(() => notifyListeners());
  }

  /// Lock all items (e.g. on logout)
  void lockAll() {
    _unlockedItemIds.clear();
    // Safety: iterate over a copy to avoid concurrent modification
    final timers = _lockTimers.values.toList();
    for (final timer in timers) {
      timer?.cancel();
    }
    _lockTimers.clear();
    debugPrint('Vault: Locked all items');
    scheduleMicrotask(() => notifyListeners());
  }

  /// Specialized lock for chat exit
  void lockOnChatClose(String itemId) {
    final id = _normalizeId(itemId);

    // Safety check: if intervals aren't loaded yet, it's safer to lock
    // on exit if the item is known to be in the vault.
    if (!_isInitDone) {
      if (isInVaultSync(id)) {
        lockItem(id);
      }
      return;
    }

    final interval = getLockInterval(id);
    // We lock on chat close if the interval is 'chat_close' or '5mins'.
    // 'app_close' is the only one that remains unlocked after closing the chat.
    if (interval != 'app_close') {
      lockItem(id);
    }
  }

  /// Lock items with a specific interval (e.g. 'app_close')
  void lockItemsWithInterval(String interval) {
    // Collect IDs first into a new list to avoid concurrent modification
    final itemsToLock = _unlockedItemIds.where((id) {
      if (interval == 'app_close') {
        // App close (lifecycle backgrounding) should lock EVERYTHING for maximum security.
        return true;
      }

      final itemInterval = getLockInterval(id);
      return itemInterval == interval;
    }).toList();

    for (final id in itemsToLock) {
      _unlockedItemIds.remove(id);
      _lockTimers[id]?.cancel();
      _lockTimers.remove(id);
    }

    if (itemsToLock.isNotEmpty) {
      debugPrint(
        'Vault: Locked ${itemsToLock.length} items with interval $interval',
      );
      scheduleMicrotask(() => notifyListeners());
    }
  }

  /// Set lock interval for an item
  Future<void> setLockInterval(String itemId, String interval) async {
    // Ensure service is initialized before updating settings
    await isReady;

    final id = _normalizeId(itemId);
    _itemIntervals[id] = interval;
    await _saveIntervals();

    // If interval changed to something other than 5mins, cancel existing timer
    if (interval != '5mins') {
      _lockTimers[id]?.cancel();
      _lockTimers[id] = null;
    } else if (_unlockedItemIds.contains(id)) {
      // If it's already unlocked and changed to 5mins, start the timer now
      _lockTimers[id]?.cancel();
      _lockTimers[id] = Timer(const Duration(minutes: 5), () {
        lockItem(id);
      });
    }

    scheduleMicrotask(() => notifyListeners());
  }

  String getLockInterval(String itemId) =>
      _itemIntervals[_normalizeId(itemId)] ?? 'app_close';

  /// Attempt to authenticate for a specific item
  Future<bool> authenticate({
    required String itemId,
    String? pin,
    BuildContext? context,
  }) async {
    final id = _normalizeId(itemId);

    if (pin != null) {
      return unlockItemWithPin(id, pin);
    }

    // Check if PIN is required
    final hasPin = await _storage.read(key: _vaultPinKey);
    if (hasPin == null) {
      _unlockItem(id);
      return true;
    }

    // Check if user is Pro for biometric
    final isPro = SubscriptionService().isPro;
    if (isPro) {
      final localAuth = LocalAuthentication();
      try {
        final canCheckBiometrics = await localAuth.canCheckBiometrics;
        final isDeviceSupported = await localAuth.isDeviceSupported();

        if (canCheckBiometrics && isDeviceSupported) {
          final authenticated = await localAuth.authenticate(
            localizedReason: 'Please authenticate to unlock this chat',
          );
          if (authenticated) {
            _unlockItem(id);
            return true;
          }
        }
      } catch (e) {
        debugPrint('Biometric auth error: $e');
      }
    }

    // Show PIN dialog if context is provided
    if (context != null && context.mounted) {
      return await _showPinDialog(context, id);
    }

    return false;
  }

  /// Show PIN dialog for authentication
  Future<bool> _showPinDialog(BuildContext context, String itemId) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('Enter PIN'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Enter your 4-digit PIN',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) async {
                  final isValid = await unlockItemWithPin(
                    itemId,
                    controller.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context, isValid);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final isValid = await unlockItemWithPin(
                      itemId,
                      controller.text,
                    );
                    if (context.mounted) {
                      if (!isValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Incorrect PIN'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Add item to vault
  Future<void> addToVault({
    required String itemId,
    required VaultItemType type,
  }) async {
    final id = _normalizeId(itemId);
    final items = await _getVaultItems();

    // Pro check for limits
    final user = _supabase.auth.currentUser;
    final isPro = SubscriptionService().isPro;
    if (!isPro && items.length >= 10) {
      throw Exception(
        'Free tier is limited to 10 vault items. Upgrade to Oasis Pro for unlimited vault storage.',
      );
    }

    if (items.any((i) => _normalizeId(i.id) == id)) return;

    items.add(VaultItem(id: id, type: type, addedAt: DateTime.now()));
    await _saveVaultItems(items);
    _vaultItemIds.add(id);

    // Default interval
    _itemIntervals[id] = 'app_close';
    await _saveIntervals();

    // Automatically mark as unlocked when first added, since the user
    // is currently interacting with the item they just secured.
    _unlockedItemIds.add(id);

    // Sync to server (Pro Only)
    try {
      if (isPro) {
        final userId = user?.id;
        if (userId != null) {
          await _supabase.from('vault_items').upsert({
            'user_id': userId,
            'item_id': id,
            'item_type': type.value,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing vault item: $e');
    }

    scheduleMicrotask(() => notifyListeners());
  }

  /// Remove item from vault
  Future<void> removeFromVault(String itemId) async {
    final id = _normalizeId(itemId);
    final items = await _getVaultItems();
    items.removeWhere((i) => _normalizeId(i.id) == id);
    await _saveVaultItems(items);

    _vaultItemIds.remove(id);
    _unlockedItemIds.remove(id);
    _itemIntervals.remove(id);
    _lockTimers[id]?.cancel();
    _lockTimers.remove(id);
    await _saveIntervals();

    // Sync to server (Pro only)
    try {
      final user = _supabase.auth.currentUser;
      final isPro = SubscriptionService().isPro;
      if (isPro) {
        final userId = user?.id;
        if (userId != null) {
          await _supabase
              .from('vault_items')
              .delete()
              .eq('user_id', userId)
              .eq('item_id', id);
        }
      }
    } catch (e) {
      debugPrint('Error removing vault item: $e');
    }

    scheduleMicrotask(() => notifyListeners());
  }

  /// Check if item is in vault (async)
  Future<bool> isInVault(String itemId) async {
    final id = _normalizeId(itemId);
    final items = await _getVaultItems();
    return items.any((i) => _normalizeId(i.id) == id);
  }

  /// Check if item is in vault (synchronous cache)
  bool isInVaultSync(String itemId) {
    return _vaultItemIds.contains(_normalizeId(itemId));
  }

  /// Get all vault items
  Future<List<VaultItem>> getVaultItems() async {
    return _getVaultItems();
  }

  /// Get vault items by type
  Future<List<VaultItem>> getVaultItemsByType(VaultItemType type) async {
    final items = await _getVaultItems();
    return items.where((i) => i.type == type).toList();
  }

  Future<List<VaultItem>> _getVaultItems() async {
    final itemsJson = await _storage.read(key: _vaultItemsKey);
    if (itemsJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(itemsJson);
      return decoded.map((i) => VaultItem.fromJson(i)).toList();
    } catch (e) {
      debugPrint('Error decoding vault items: $e');
      return [];
    }
  }

  Future<void> _saveVaultItems(List<VaultItem> items) async {
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await _storage.write(key: _vaultItemsKey, value: encoded);
  }

  /// Sync vault items from server
  Future<void> syncFromServer() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final isPro = SubscriptionService().isPro;
      if (userId == null || !isPro) return;

      final response = await _supabase
          .from('vault_items')
          .select()
          .eq('user_id', userId);

      final items = response
          .map<VaultItem>(
            (v) => VaultItem(
              id: _normalizeId(v['item_id'].toString()),
              type: VaultItemType.fromString(v['item_type']),
              addedAt: DateTime.parse(v['created_at']),
            ),
          )
          .toList();

      await _saveVaultItems(items);
      _vaultItemIds.clear();
      _vaultItemIds.addAll(items.map((i) => i.id));
      scheduleMicrotask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error syncing vault from server: $e');
    }
  }

  @override
  void dispose() {
    final timers = _lockTimers.values.toList();
    for (final timer in timers) {
      timer?.cancel();
    }
    super.dispose();
  }
}

enum VaultItemType {
  post('post'),
  conversation('conversation'),
  collection('collection'),
  media('media');

  final String value;
  const VaultItemType(this.value);

  static VaultItemType fromString(String value) {
    return VaultItemType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => VaultItemType.post,
    );
  }
}

class VaultItem {
  final String id;
  final VaultItemType type;
  final DateTime addedAt;

  VaultItem({required String id, required this.type, required this.addedAt})
    : id = id.trim().toLowerCase();

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'].toString(),
      type: VaultItemType.fromString(json['type']),
      addedAt: DateTime.parse(json['added_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'added_at': addedAt.toIso8601String(),
    };
  }
}
