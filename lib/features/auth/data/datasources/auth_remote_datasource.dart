import 'package:oasis/core/config/app_config.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/auth/domain/models/auth_models.dart';
import 'package:oasis/services/session_registry_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:oasis/services/auth/auth_providers_delegate.dart';

class AuthRemoteDatasource {
  final SupabaseClient _supabase = SupabaseService().client;
  final AuthProvidersDelegate _authProvidersDelegate;

  AuthRemoteDatasource({AuthProvidersDelegate? authProvidersDelegate})
    : _authProvidersDelegate =
          authProvidersDelegate ??
          AuthProvidersDelegate(SupabaseService().client);

  Future<String?> _getEmailFromUsername(String username) async {
    try {
      final response = await _supabase.rpc(
        SupabaseConfig.getEmailByUsernameFn,
        params: {'p_username': username},
      );
      return response as String?;
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Error resolving username: $e');
      return null;
    }
  }

  Future<RegisteredAccount> signInWithEmail(AuthCredentials credentials) async {
    try {
      String email = credentials.identifier;

      // If not an email, try resolving as username
      if (!email.contains('@')) {
        debugPrint(
          '[AuthRemoteDatasource] Resolving username: ${credentials.identifier}',
        );
        final resolvedEmail = await _getEmailFromUsername(
          credentials.identifier,
        );
        if (resolvedEmail == null) {
          throw const AuthException(
            'No user found with this username',
            statusCode: '404',
          );
        }
        email = resolvedEmail;
        debugPrint('[AuthRemoteDatasource] Resolved to email: $email');
      }

      debugPrint(
        '[AuthRemoteDatasource] Starting sign in with resolved email: $email',
      );

      // CRITICAL FIX: If we are already logged in (adding an account),
      // we MUST sign out locally before signing in with a new user.
      // This ensures Supabase client starts from a clean state.
      if (_supabase.auth.currentSession != null) {
        debugPrint(
          '[AuthRemoteDatasource] Existing session found. Signing out locally first.',
        );
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: credentials.password,
      );

      final user = response.user;
      final session = response.session;

      debugPrint(
        '[AuthRemoteDatasource] Response - user: ${user?.id}, session: ${session != null}',
      );

      if (user == null || session == null) {
        throw Exception('Sign in failed: no user or session returned');
      }

      return _toRegisteredAccount(user, session);
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign in AuthException: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign in error: $e');
      rethrow;
    }
  }

  Future<RegisteredAccount> signUp({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    try {
      // CRITICAL FIX: If we are already logged in (adding an account),
      // we MUST sign out locally before signing up a new user.
      if (_supabase.auth.currentSession != null) {
        debugPrint(
          '[AuthRemoteDatasource] Existing session found. Signing out locally first.',
        );
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.getWebUrl('/auth/callback'),
        data: {
          if (username != null) 'username': username,
          if (fullName != null) 'full_name': fullName,
          'has_accepted_terms': true,
          'accepted_terms_at': DateTime.now().toIso8601String(),
        },
      );

      final user = response.user;
      final session = response.session;

      if (user == null) {
        throw Exception('Sign up failed: no user returned');
      }

      if (session == null) {
        throw Exception('Please check your email to verify your account');
      }

      return _toRegisteredAccount(user, session);
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign up error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      );

      // Sign out first to clear any cached session - this forces account picker
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw Exception('No ID token returned from Google');
      }

      // CRITICAL FIX: If we are already logged in (adding an account),
      // we MUST sign out locally before signing in with a new user.
      if (_supabase.auth.currentSession != null) {
        debugPrint(
          '[AuthRemoteDatasource] Existing session found. Signing out locally first.',
        );
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Google sign in error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Google sign in error: $e');
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      // CRITICAL FIX: If we are already logged in (adding an account),
      // we MUST sign out locally before signing in with a new user.
      if (_supabase.auth.currentSession != null) {
        debugPrint(
          '[AuthRemoteDatasource] Existing session found. Signing out locally first.',
        );
        await _supabase.auth.signOut(scope: SignOutScope.local);
      }

      await _supabase.auth.signInWithOAuth(OAuthProvider.apple);
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Apple sign in error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Apple sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign out error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Sign out error: $e');
      rethrow;
    }
  }

  Future<RegisteredAccount?> restoreSession() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) return null;

      return _toRegisteredAccount(user, session);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Restore session error: $e');
      return null;
    }
  }

  Future<void> resetPassword(String identifier) async {
    String email = identifier;
    try {
      if (!identifier.contains('@')) {
        debugPrint(
          '[AuthRemoteDatasource] Resolving username for reset: $identifier',
        );
        final resolvedEmail = await _getEmailFromUsername(identifier);
        if (resolvedEmail == null) {
          throw const AuthException(
            'No user found with this username',
            statusCode: '404',
          );
        }
        email = resolvedEmail;
        debugPrint('[AuthRemoteDatasource] Resolved to email: $email');
      }

      // First try the built-in Supabase email with full URL for redirect
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConfig.getWebUrl('/reset-password'),
      );
    } on AuthException catch (e) {
      // If Supabase fails (rate limit, etc.), try the custom Edge Function with Resend
      debugPrint(
        '[AuthRemoteDatasource] Supabase email failed, trying Edge Function: ${e.message}',
      );
      await _sendPasswordResetViaEdgeFunction(email);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Reset password error: $e');
      // Try Edge Function as fallback
      try {
        await _sendPasswordResetViaEdgeFunction(email);
      } catch (edgeError) {
        debugPrint(
          '[AuthRemoteDatasource] Edge function also failed: $edgeError',
        );
        rethrow;
      }
    }
  }

  /// Send password reset email via custom Edge Function (bypasses Supabase rate limits)
  Future<void> _sendPasswordResetViaEdgeFunction(String email) async {
    try {
      final supabaseUrl = SupabaseConfig.supabaseUrl;
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/send-password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode != 200) {
        throw Exception('Edge function failed: ${response.body}');
      }

      debugPrint(
        '[AuthRemoteDatasource] Password reset email sent via Edge Function',
      );
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Edge function error: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  Future<void> setSession(String refreshToken) async {
    try {
      await _supabase.auth.setSession(refreshToken);
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Set session error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Set session error: $e');
      rethrow;
    }
  }

  /// Update the user's password (used after password reset link or for Google users)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Update password error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Update password error: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            if (username != null) 'username': username,
            if (fullName != null) 'full_name': fullName,
            if (avatarUrl != null) 'avatar_url': avatarUrl,
          },
        ),
      );
    } on AuthException catch (e) {
      debugPrint('[AuthRemoteDatasource] Update profile error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[AuthRemoteDatasource] Update profile error: $e');
      rethrow;
    }
  }

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithPasskey(String email) async {
    final response = await _authProvidersDelegate.signInWithPasskey(email);
    final user = response.user;
    final session = response.session;
    if (user == null || session == null) {
      throw Exception('Passkey sign in failed: no user or session returned');
    }
    return response;
  }

  Future<AuthResponse> registerWithPasskey({
    required String email,
    required String username,
    required String fullName,
  }) async {
    final response = await _authProvidersDelegate.registerWithPasskey(
      email: email,
      username: username,
      fullName: fullName,
      data: {
        'has_accepted_terms': true,
        'accepted_terms_at': DateTime.now().toIso8601String(),
      },
    );
    final user = response.user;
    final session = response.session;
    if (user == null || session == null) {
      throw Exception(
        'Passkey registration failed: no user or session returned',
      );
    }
    return response;
  }

  Future<void> addPasskeyToCurrentUser() async {
    await _authProvidersDelegate.addPasskeyToCurrentUser();
  }

  RegisteredAccount _toRegisteredAccount(User user, Session session) {
    final metadata = user.userMetadata ?? {};
    return RegisteredAccount(
      userId: user.id,
      email: user.email ?? '',
      username: metadata['username'] ?? user.email?.split('@')[0] ?? 'user',
      fullName: metadata['full_name'],
      avatarUrl: metadata['avatar_url'],
      session: session,
      lastUsed: DateTime.now(),
    );
  }
}
