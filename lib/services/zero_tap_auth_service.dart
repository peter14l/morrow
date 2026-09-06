import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

/// Service providing cross-platform integration with the Android Restore
/// Credentials API (Zero-Tap Sign-In requirement) via platform MethodChannel.
class ZeroTapAuthService {
  static final ZeroTapAuthService instance = ZeroTapAuthService._internal();

  factory ZeroTapAuthService() {
    return instance;
  }

  ZeroTapAuthService._internal();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.yourapp.zerotap/restore',
  );

  /// Queries the Android OS CredentialManager cache for migrated user credentials.
  ///
  /// Returns the credential/session string if available, or `null` if not found,
  /// cancelled, unsupported, or running on a non-Android platform.
  Future<String?> getRestoreKey() async {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }

    try {
      debugPrint('[ZeroTapAuthService] Querying OS for restore credential key...');
      final result = await channel.invokeMethod<String>('getRestoreKey');
      if (result != null && result.isNotEmpty) {
        debugPrint(
          '[ZeroTapAuthService] Successfully retrieved restore credential key from OS.',
        );
        return result;
      }
      debugPrint('[ZeroTapAuthService] No restore credential found in OS cache.');
      return null;
    } on PlatformException catch (e) {
      debugPrint(
        '[ZeroTapAuthService] PlatformException getting restore key: ${e.code} - ${e.message}',
      );
      return null;
    } catch (e, st) {
      debugPrint('[ZeroTapAuthService] Unexpected error getting restore key: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Commits an encrypted token or session JSON down to the Android OS
  /// CredentialManager system layer upon successful baseline app logins.
  Future<bool> saveRestoreKey(String token) async {
    if (token.isEmpty) {
      debugPrint('[ZeroTapAuthService] saveRestoreKey skipped: token is empty');
      return false;
    }

    if (kIsWeb || !Platform.isAndroid) {
      return true; // Graceful no-op on non-Android platforms
    }

    try {
      debugPrint('[ZeroTapAuthService] Saving restore key to OS CredentialManager...');
      final success = await channel.invokeMethod<bool>('saveRestoreKey', {
        'token': token,
      });
      debugPrint(
        '[ZeroTapAuthService] Save restore key result: ${success ?? false}',
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ZeroTapAuthService] PlatformException saving restore key: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e, st) {
      debugPrint('[ZeroTapAuthService] Unexpected error saving restore key: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// Clears the restore credential state from the OS CredentialManager.
  Future<bool> clearRestoreKey() async {
    if (kIsWeb || !Platform.isAndroid) {
      return true;
    }

    try {
      debugPrint('[ZeroTapAuthService] Clearing restore key from OS...');
      final success = await channel.invokeMethod<bool>('clearRestoreKey');
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint(
        '[ZeroTapAuthService] PlatformException clearing restore key: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e, st) {
      debugPrint('[ZeroTapAuthService] Unexpected error clearing restore key: $e');
      debugPrint('$st');
      return false;
    }
  }
}
