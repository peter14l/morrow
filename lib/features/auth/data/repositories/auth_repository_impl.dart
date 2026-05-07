import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/auth/domain/models/auth_models.dart';
import 'package:oasis/features/auth/domain/repositories/auth_repository.dart';
import 'package:oasis/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:oasis/features/auth/data/datasources/session_local_datasource.dart';
import 'package:oasis/services/session_registry_service.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:oasis/services/auth/encryption_provisioner.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final SessionLocalDatasource _localDatasource;
  final NotificationService _notificationService = NotificationService();
  final EncryptionProvisioner _encryptionProvisioner = EncryptionProvisioner();

  AuthRepositoryImpl({
    AuthRemoteDatasource? remoteDatasource,
    SessionLocalDatasource? localDatasource,
  }) : _remoteDatasource = remoteDatasource ?? AuthRemoteDatasource(),
       _localDatasource = localDatasource ?? SessionLocalDatasource();

  @override
  Future<RegisteredAccount> signInWithEmail(AuthCredentials credentials) async {
    debugPrint('[AuthRepositoryImpl] Sign in with email');
    final account = await _remoteDatasource.signInWithEmail(credentials);
    debugPrint('[AuthRepositoryImpl] Got account: ${account.userId}');
    await _localDatasource.saveAccount(account);
    await _localDatasource.setLastActiveUserId(account.userId);
    
    // Update FCM token
    _notificationService.updateFcmToken(account.userId);
    
    // Provision encryption keys
    await _encryptionProvisioner.provisionEncryptionKeys();
    
    debugPrint('[AuthRepositoryImpl] Account saved locally');
    return account;
  }

  @override
  Future<RegisteredAccount> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    final account = await _remoteDatasource.signUp(
      email: email,
      password: password,
      username: username,
      fullName: fullName,
    );
    await _localDatasource.saveAccount(account);
    await _localDatasource.setLastActiveUserId(account.userId);
    
    // Update FCM token
    _notificationService.updateFcmToken(account.userId);
    
    // Provision encryption keys
    await _encryptionProvisioner.provisionEncryptionKeys();
    
    return account;
  }

  @override
  Future<void> signInWithGoogle() async {
    await _remoteDatasource.signInWithGoogle();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _notificationService.updateFcmToken(user.id);
      await _encryptionProvisioner.provisionEncryptionKeys();
    }
  }

  @override
  Future<void> signInWithApple() async {
    await _remoteDatasource.signInWithApple();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _notificationService.updateFcmToken(user.id);
      await _encryptionProvisioner.provisionEncryptionKeys();
    }
  }

  @override
  Future<void> signOut() async {
    await _remoteDatasource.signOut();
  }

  @override
  Future<RegisteredAccount?> restoreSession() async {
    final account = await _remoteDatasource.restoreSession();
    if (account != null) {
      _notificationService.updateFcmToken(account.userId);
    }
    return account;
  }

  @override
  Future<void> resetPassword(String identifier) async {
    await _remoteDatasource.resetPassword(identifier);
  }

  @override
  Future<void> updatePassword(String password) async {
    await _remoteDatasource.updatePassword(password);
  }

  @override
  Future<void> switchAccount(String userId) async {
    final accounts = await _localDatasource.getRegisteredAccounts();
    final account = accounts.firstWhere(
      (a) => a.userId == userId,
      orElse: () => throw Exception('Account not found'),
    );

    await _remoteDatasource.setSession(account.session.refreshToken!);
    await _localDatasource.markAsUsed(userId);
    await _localDatasource.setLastActiveUserId(userId);
    
    _notificationService.updateFcmToken(userId);
  }

  @override
  Future<List<RegisteredAccount>> getRegisteredAccounts() async {
    return _localDatasource.getRegisteredAccounts();
  }

  @override
  Future<void> removeAccount(String userId) async {
    await _localDatasource.removeAccount(userId);
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? avatarUrl,
  }) async {
    await _remoteDatasource.updateProfile(
      username: username,
      fullName: fullName,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Stream<AuthState> get onAuthStateChange =>
      _remoteDatasource.onAuthStateChange;

  @override
  Future<AuthResponse> signInWithPasskey(String email) async {
    final response = await _remoteDatasource.signInWithPasskey(email);
    if (response.user != null) {
      _notificationService.updateFcmToken(response.user!.id);
    }
    return response;
  }

  @override
  Future<AuthResponse> registerWithPasskey({
    required String email,
    required String username,
    required String fullName,
  }) async {
    final response = await _remoteDatasource.registerWithPasskey(
      email: email,
      username: username,
      fullName: fullName,
    );
    if (response.user != null) {
      _notificationService.updateFcmToken(response.user!.id);
    }
    return response;
  }

  @override
  Future<void> addPasskeyToCurrentUser() async {
    await _remoteDatasource.addPasskeyToCurrentUser();
  }
}
