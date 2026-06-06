import 'package:oasis/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:universal_io/io.dart';
// import 'package:passkeys/passkeys.dart' as pk;

class AuthProvidersDelegate {
  final SupabaseClient _supabase;
  // final pk.PasskeyAuthenticator _authenticator = pk.PasskeyAuthenticator();

  AuthProvidersDelegate(this._supabase);

  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // CRITICAL FIX: If we are already logged in (adding an account),
    // we MUST sign out locally before signing in with a new user.
    if (_supabase.auth.currentSession != null) {
      debugPrint(
        '[AuthProvidersDelegate] Existing session found. Signing out locally first.',
      );
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }

    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: AppConfig.getWebUrl('/auth/callback'),
    );
  }

  Future<void> signInWithGoogle({bool forceSignIn = false}) async {
    throw UnimplementedError('Google Sign-In has been removed from this project.');
  }

  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: const String.fromEnvironment(
          'APPLE_SERVICE_ID',
          defaultValue: 'com.oasis.service',
        ),
        redirectUri: Uri.parse(AppConfig.getWebUrl('/auth/apple/callback')),
      ),
    );

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
    );
  }

  // --- Passkey (WebAuthn) methods ---
  // Note: Standard supabase_flutter (2.x) currently requires custom implementation for WebAuthn/Passkeys
  // or use of Edge Functions for native flows. The methods below are placeholders
  // that need to be aligned with your specific backend/MFA strategy.

  /// Initiates a passkey sign-in flow.
  Future<AuthResponse> signInWithPasskey(String email) async {
    throw UnimplementedError(
      'Native Passkey support in Supabase Flutter SDK is still in preview/experimental.',
    );
  }

  /// Registers a new user with a passkey.
  Future<AuthResponse> registerWithPasskey({
    required String email,
    required String username,
    required String fullName,
    Map<String, dynamic>? data,
  }) async {
    throw UnimplementedError(
      'Native Passkey support in Supabase Flutter SDK is still in preview/experimental.',
    );
  }

  /// Adds a passkey to the currently authenticated user's account.
  Future<void> addPasskeyToCurrentUser() async {
    throw UnimplementedError(
      'Native Passkey support in Supabase Flutter SDK is still in preview/experimental.',
    );
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      // If the error is about a missing or invalid refresh token, we can ignore it
      // as the goal is to be signed out anyway.
      if (e.message.contains('refresh_token_not_found') ||
          e.message.contains('Invalid Refresh Token')) {
        debugPrint(
          '[AuthProvidersDelegate] Sign out error (token already invalid): ${e.message}',
        );
      } else {
        rethrow;
      }
    }
  }
}
