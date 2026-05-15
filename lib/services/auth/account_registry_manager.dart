import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/session_registry_service.dart';

class AccountRegistryManager with ChangeNotifier {
  final SessionRegistryService _registry = SessionRegistryService();
  List<RegisteredAccount> _registeredAccounts = [];
  bool _isLoading = false;

  List<RegisteredAccount> get registeredAccounts => _registeredAccounts;
  bool get isLoading => _isLoading;

  AccountRegistryManager() {
    loadRegistry();
  }

  Future<void> loadRegistry() async {
    if (_isLoading) return;
    try {
      debugPrint('[AccountRegistryManager] loadRegistry starting...');
      _isLoading = true;
      notifyListeners();

      _registeredAccounts = await _registry.getAllAccounts();
      debugPrint(
        '[AccountRegistryManager] loadRegistry completed. Count: ${_registeredAccounts.length}',
      );
    } catch (e) {
      debugPrint('[AccountRegistryManager] CRITICAL ERROR in loadRegistry: $e');
      // If it fails, we start with empty to prevent app crash
      _registeredAccounts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncCurrentSessionToRegistry(Session session) async {
    final user = session.user;
    final metadata = user.userMetadata ?? {};

    final account = RegisteredAccount(
      userId: user.id,
      email: user.email ?? '',
      username: metadata['username'] ?? user.email?.split('@')[0] ?? 'user',
      fullName: metadata['full_name'] as String?,
      avatarUrl: metadata['avatar_url'] as String?,
      session: session,
      lastUsed: DateTime.now(),
    );

    debugPrint(
      '[AccountRegistryManager] Syncing account ${account.username} (${account.userId}) to registry',
    );
    try {
      await _registry.saveAccount(account);
      debugPrint(
        '[AccountRegistryManager] Account saved. Reloading registry...',
      );
      await loadRegistry();
    } catch (e) {
      debugPrint('[AccountRegistryManager] ERROR syncing account: $e');
    }
  }

  Future<void> removeAccount(String userId) async {
    debugPrint('[AccountRegistryManager] Removing account: $userId');
    try {
      await _registry.removeAccount(userId);
      await loadRegistry();
    } catch (e) {
      debugPrint('[AccountRegistryManager] ERROR removing account: $e');
    }
  }

  Future<void> markAsUsed(String userId) async {
    debugPrint('[AccountRegistryManager] Marking account as used: $userId');
    try {
      await _registry.markAsUsed(userId);
      await loadRegistry();
    } catch (e) {
      debugPrint('[AccountRegistryManager] ERROR marking as used: $e');
    }
  }

  RegisteredAccount getAccount(String userId) {
    return _registeredAccounts.firstWhere((a) => a.userId == userId);
  }
}
