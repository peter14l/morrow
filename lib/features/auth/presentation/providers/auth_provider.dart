import 'package:flutter/foundation.dart';
import 'package:oasis/features/auth/domain/models/auth_models.dart';
import 'package:oasis/features/auth/domain/repositories/auth_repository.dart';
import 'package:oasis/features/auth/presentation/providers/auth_state.dart'
    as app_auth;
import 'package:oasis/services/session_registry_service.dart';
import 'package:oasis/services/app_analytics.dart';
import 'package:oasis/services/app_initializer.dart';

export 'package:oasis/features/auth/presentation/providers/auth_state.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _repository;
  final AppAnalytics _analytics;

  app_auth.AuthState _state = const app_auth.AuthState();
  app_auth.AuthState get state => _state;

  RegisteredAccount? get currentAccount => _state.currentAccount;
  List<RegisteredAccount> get registeredAccounts => _state.registeredAccounts;
  bool get isLoading => _state.isLoading;
  bool get isAuthenticated => _state.isAuthenticated;
  String? get error => _state.error;

  AuthProvider({
    required AuthRepository repository,
    required AppAnalytics analytics,
  }) : _repository = repository,
       _analytics = analytics {
    _listenToAuthState();
  }

  void _listenToAuthState() {
    _repository.onAuthStateChange.listen((event) {
      if (event.session != null) {
        _state = _state.copyWith(isAuthenticated: true);
        final userId = event.session?.user.id;
        _analytics.setUserId(userId);
        if (userId != null) {
          _analytics.logEvent(name: 'login', parameters: {'method': event.event.name});
          // Re-subscribe to DM notifications on login/session restoration
          AppInitializer.subscribeToDmNotifications();
        }
        notifyListeners();
      } else {
        _state = _state.copyWith(isAuthenticated: false, currentAccount: null);
        _analytics.setUserId(null);
        notifyListeners();
      }
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthProvider] signInWithEmail called');
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      debugPrint('[AuthProvider] Calling repository signInWithEmail');
      final account = await _repository.signInWithEmail(
        AuthCredentials(identifier: email, password: password),
      );
      debugPrint(
        '[AuthProvider] Repository returned account: ${account.userId}',
      );
      _state = _state.copyWith(currentAccount: account, isAuthenticated: true);
      debugPrint(
        '[AuthProvider] State updated, isAuthenticated: ${_state.isAuthenticated}',
      );
      await _loadAccounts();
      debugPrint('[AuthProvider] Accounts loaded');
    } catch (e) {
      debugPrint('[AuthProvider] Sign in error: $e');
      _state = _state.copyWith(error: e.toString());
      rethrow;
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      debugPrint(
        '[AuthProvider] Done, isAuthenticated: ${_state.isAuthenticated}',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final account = await _repository.signUp(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      _state = _state.copyWith(currentAccount: account, isAuthenticated: true);
      await _loadAccounts();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[AuthProvider] Sign up error: $e');
      rethrow;
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _repository.signInWithGoogle();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      await _repository.signInWithApple();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
      _state = const app_auth.AuthState();
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resetPassword(String identifier) async {
    try {
      await _repository.resetPassword(identifier);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updatePassword(String password) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      await _repository.updatePassword(password);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[AuthProvider] Update password error: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> switchAccount(String userId) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      await _repository.switchAccount(userId);
      await _loadAccounts();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[AuthProvider] Switch account error: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> removeAccount(String userId) async {
    try {
      await _repository.removeAccount(userId);
      await _loadAccounts();
    } catch (e) {
      debugPrint('[AuthProvider] Remove account error: $e');
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _repository.getRegisteredAccounts();
      _state = _state.copyWith(registeredAccounts: accounts);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Load accounts error: $e');
    }
  }

  Future<void> restoreSession() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final account = await _repository.restoreSession();
      if (account != null) {
        _state = _state.copyWith(
          currentAccount: account,
          isAuthenticated: true,
        );
      }
      // Always load registered accounts from the registry
      await _loadAccounts();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[AuthProvider] Restore session error: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  void clear() {
    _state = const app_auth.AuthState();
    notifyListeners();
  }
}
