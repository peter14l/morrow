import 'package:oasis/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as all_platforms;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:universal_io/io.dart';
// import 'package:passkeys/passkeys.dart' as pk;

class AuthProvidersDelegate {
  final SupabaseClient _supabase;
  // final pk.PasskeyAuthenticator _authenticator = pk.PasskeyAuthenticator();

  AuthProvidersDelegate(this._supabase);

  static String get _googleWebClientId {
    const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  static String get _googleWebClientSecret {
    const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_SECRET');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _googleWebClientId : null,
    serverClientId: kIsWeb ? null : _googleWebClientId,
    scopes: ['email', 'profile'],
  );

  // Removed static initialization of _googleSignInDesktop to avoid assertion errors on Windows
  // when client ID/Secret are not provided in the environment.

  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
    String? idToken;
    String? accessToken;

    if (!kIsWeb && Platform.isWindows) {
      final googleSignInDesktop = all_platforms.GoogleSignIn(
        params: all_platforms.GoogleSignInParams(
          clientId: _googleWebClientId,
          clientSecret: _googleWebClientSecret,
          redirectPort: 3000,
          scopes: ['email', 'profile', 'openid'],
        ),
      );
      final response = await googleSignInDesktop.signIn();
      if (response == null)
        throw const AuthException('Google sign in was cancelled');
      idToken = response.idToken;
      accessToken = response.accessToken;
    } else {
      GoogleSignInAccount? googleUser;
      if (forceSignIn) {
        await _googleSignIn.signOut();
        googleUser = await _googleSignIn.signIn();
      } else {
        googleUser =
            await _googleSignIn.signInSilently() ??
            await _googleSignIn.signIn();
      }

      if (googleUser == null)
        throw const AuthException('Google sign in was cancelled');

      final googleAuth = await googleUser.authentication;
      idToken = googleAuth.idToken;
      accessToken = googleAuth.accessToken;
    }

    if (idToken == null) throw const AuthException('No ID Token found.');

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
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
    throw UnimplementedError('Native Passkey support in Supabase Flutter SDK is still in preview/experimental.');
  }

  /// Registers a new user with a passkey.
  Future<AuthResponse> registerWithPasskey({
    required String email,
    required String username,
    required String fullName,
    Map<String, dynamic>? data,
  }) async {
    throw UnimplementedError('Native Passkey support in Supabase Flutter SDK is still in preview/experimental.');
  }

  /// Adds a passkey to the currently authenticated user's account.
  Future<void> addPasskeyToCurrentUser() async {
    throw UnimplementedError('Native Passkey support in Supabase Flutter SDK is still in preview/experimental.');
  }

  Future<void> signOut() async {
    try {
      if (kIsWeb || !Platform.isWindows) {
        await _googleSignIn.signOut().catchError((e) => null);
      } else {
        // Only attempt desktop sign out if client ID is configured to avoid assertion errors
        if (_googleWebClientId.isNotEmpty) {
          final googleSignInDesktop = all_platforms.GoogleSignIn(
            params: all_platforms.GoogleSignInParams(
              clientId: _googleWebClientId,
              clientSecret: _googleWebClientSecret,
              redirectPort: 3000,
              scopes: ['email', 'profile', 'openid'],
            ),
          );
          await googleSignInDesktop.signOut().catchError((e) => null);
        }
      }
    } catch (e) {
      debugPrint('Error during Google sign out: $e');
    }
    await _supabase.auth.signOut();
  }
}
