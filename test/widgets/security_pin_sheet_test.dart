import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/security_pin_sheet.dart';

void main() {
  group('SecurityPinSheet - Forgot PIN Navigation', () {
    testWidgets(
      'should display Forgot PIN button when in needsRestore status',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider(
                create: (_) => _TestEncryptionService(),
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      SecurityPinSheet.show(
                        context,
                        EncryptionStatus.needsRestore,
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap button to show sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify Forgot PIN button is shown
        expect(find.text('Forgot PIN?'), findsOneWidget);
      },
    );

    testWidgets(
      'should NOT display Forgot PIN button when in needsSetup status',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider(
                create: (_) => _TestEncryptionService(),
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      SecurityPinSheet.show(
                        context,
                        EncryptionStatus.needsSetup,
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap button to show sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify Forgot PIN button is NOT shown for needsSetup
        expect(find.text('Forgot PIN?'), findsNothing);
      },
    );

    testWidgets('should have Forgot PIN button with correct styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => _TestEncryptionService(),
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SecurityPinSheet.show(
                      context,
                      EncryptionStatus.needsRestore,
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Find the TextButton with Forgot PIN text
      final forgotPinButton = find.widgetWithText(TextButton, 'Forgot PIN?');
      expect(forgotPinButton, findsOneWidget);
    });
  });
}

/// Test implementation of EncryptionService for widget testing
class _TestEncryptionService extends ChangeNotifier
    implements EncryptionService {
  @override
  bool get isInitialized => false;

  @override
  Future<EncryptionStatus> init() async {
    return EncryptionStatus.needsRestore;
  }

  @override
  Future<bool> restoreSecureKeys(String pin) async {
    return false;
  }

  @override
  Future<({bool success, String? recoveryKey})> setupEncryption({
    String? pin,
  }) async {
    return (success: false, recoveryKey: null);
  }

  @override
  Future<bool> generateNewKeys() async {
    return false;
  }

  @override
  Future<({bool success, String? recoveryKey})> generateNewKeysWithPin(
    String pin,
  ) async {
    return (success: false, recoveryKey: null);
  }

  @override
  Future<bool> restoreKeys() async {
    return false;
  }

  @override
  Future<bool> restoreWithRecoveryKey(String recoveryKey) async {
    return false;
  }

  @override
  Future<({bool success, String? recoveryKey})> upgradeSecurity(
    String pin,
  ) async {
    return (success: false, recoveryKey: null);
  }

  @override
  Future<({bool success, String? recoveryKey})> resetPinWithRecoveryKey(
    String recoveryKey,
    String newPin,
  ) async {
    return (success: false, recoveryKey: null);
  }

  @override
  Future<bool> backupSignalIdentity(
    String identityKeyPairBase64,
    int registrationId,
  ) async {
    return false;
  }

  @override
  Future<Map<String, dynamic>?> restoreSignalIdentity() async {
    return null;
  }

  @override
  Future<void> clearKeys() async {}

  @override
  Future<EncryptedMessage> encryptMessage(
    String content,
    List<String> recipientPublicKeysPem, {
    encrypt.Key? reuseKey,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> decryptMessage(
    String encryptedContentBase64,
    Map<String, dynamic> encryptedKeys,
    String ivBase64,
  ) async {
    return null;
  }

  @override
  encrypt.Key generateAESKey() {
    throw UnimplementedError();
  }

  @override
  Uint8List encryptData(Uint8List data, encrypt.Key key) {
    throw UnimplementedError();
  }

  @override
  Uint8List? decryptData(Uint8List combinedData, encrypt.Key key) {
    return null;
  }
}
