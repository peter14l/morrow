import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oasis/features/settings/presentation/providers/decoy_provider.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/core/storage/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSecureStorage extends Mock implements SecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({required String key}) async {
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DecoyProvider Tests', () {
    late DecoyProvider provider;
    late PrefsStorage prefsStorage;
    late MockSecureStorage secureStorage;
    bool methodChannelCalledWithEnable = false;
    bool methodChannelInvoked = false;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefsStorage = await PrefsStorage.init();

      // Mock SecureStorage
      secureStorage = MockSecureStorage();

      // Mock MethodChannel
      const channel = MethodChannel('oasis/stealth_mode');
      methodChannelCalledWithEnable = false;
      methodChannelInvoked = false;
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'setStealthMode') {
          methodChannelInvoked = true;
          methodChannelCalledWithEnable = methodCall.arguments['enable'] as bool;
          return true;
        }
        return null;
      });

      provider = DecoyProvider(
        prefsStorage: prefsStorage,
        secureStorage: secureStorage,
      );
    });

    test('Initial state: decoy is disabled and locked', () {
      expect(provider.isDecoyEnabled, isFalse);
      expect(provider.isUnlocked, isFalse);
    });

    test('enableDecoy stores pin, enables decoy mode, and notifies platform channel', () async {
      final success = await provider.enableDecoy('654321');
      expect(success, isTrue);
      expect(provider.isDecoyEnabled, isTrue);
      expect(provider.isUnlocked, isTrue); // Auto-unlock on initial activation

      // Verify persistence
      expect(prefsStorage.readBool('is_decoy_enabled'), isTrue);
      final storedPin = await secureStorage.read(key: 'decoy_pin');
      expect(storedPin, equals('654321'));

      // Verify MethodChannel call
      expect(methodChannelInvoked, isTrue);
      expect(methodChannelCalledWithEnable, isTrue);
    });

    test('disableDecoy deletes pin, disables decoy mode, and restores normal icon', () async {
      // Setup enabled decoy
      await provider.enableDecoy('112233');
      expect(provider.isDecoyEnabled, isTrue);

      // Disable
      final success = await provider.disableDecoy();
      expect(success, isTrue);
      expect(provider.isDecoyEnabled, isFalse);
      expect(provider.isUnlocked, isFalse);

      // Verify deletion from persistence
      expect(prefsStorage.readBool('is_decoy_enabled'), isFalse);
      final storedPin = await secureStorage.read(key: 'decoy_pin');
      expect(storedPin, isNull);

      // Verify MethodChannel call
      expect(methodChannelInvoked, isTrue);
      expect(methodChannelCalledWithEnable, isFalse);
    });

    test('unlock with correct PIN sets isUnlocked to true', () async {
      await provider.enableDecoy('123456');
      
      // Lock first
      provider.lock();
      expect(provider.isUnlocked, isFalse);

      // Unlock
      final success = await provider.unlock('123456');
      expect(success, isTrue);
      expect(provider.isUnlocked, isTrue);
    });

    test('unlock with incorrect PIN fails and keeps locked status', () async {
      await provider.enableDecoy('123456');
      provider.lock();
      
      final success = await provider.unlock('654321');
      expect(success, isFalse);
      expect(provider.isUnlocked, isFalse);
    });

    test('changePin changes the PIN in secure storage if current PIN is correct', () async {
      await provider.enableDecoy('123456');

      final success = await provider.changePin('123456', '987654');
      expect(success, isTrue);

      final pinInStorage = await secureStorage.read(key: 'decoy_pin');
      expect(pinInStorage, equals('987654'));
    });

    test('changePin fails if current PIN is incorrect', () async {
      await provider.enableDecoy('123456');

      final success = await provider.changePin('wrong_pin', '987654');
      expect(success, isFalse);

      final pinInStorage = await secureStorage.read(key: 'decoy_pin');
      expect(pinInStorage, equals('123456')); // unchanged
    });

    test('lock resets unlocked state back to false', () async {
      await provider.enableDecoy('123456');
      expect(provider.isUnlocked, isTrue);

      provider.lock();
      expect(provider.isUnlocked, isFalse);
    });
  });
}
