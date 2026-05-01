import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/session_registry_service.dart';
import 'package:oasis/features/auth/domain/models/auth_models.dart';

abstract class AuthRepository {
  Future<RegisteredAccount> signInWithEmail(AuthCredentials credentials);

  Future<RegisteredAccount> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> signOut();

  Future<RegisteredAccount?> restoreSession();

  Future<void> resetPassword(String identifier);

  Future<void> updatePassword(String password);

  Future<void> switchAccount(String userId);

  Future<List<RegisteredAccount>> getRegisteredAccounts();

  Future<void> removeAccount(String userId);

  Future<void> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? avatarUrl,
  });

  Stream<AuthState> get onAuthStateChange;
}
