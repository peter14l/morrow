import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/widgets/recovery_key_sheet.dart';

void main() {
  group('RecoveryKeySheet - Lost Recovery Code Navigation', () {
    testWidgets('should display Lost your recovery code button in entry mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RecoveryKeySheet.show(context);
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show sheet in entry mode
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify Lost your recovery code button is shown
      expect(find.text('Lost your recovery code?'), findsOneWidget);
    });

    testWidgets('should NOT display Lost your recovery code in display mode', (
      tester,
    ) async {
      // Display mode when recoveryKey is provided
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RecoveryKeySheet.show(
                    context,
                    recoveryKey: 'ABCD-1234-EFGH-5678',
                  );
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify Lost your recovery code button is NOT shown in display mode
      expect(find.text('Lost your recovery code?'), findsNothing);
    });

    testWidgets('should have cancel button in entry mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RecoveryKeySheet.show(context);
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should have verify recovery key button in entry mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RecoveryKeySheet.show(context);
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Recovery Key'), findsOneWidget);
    });

    testWidgets('should display Enter Recovery Key title in entry mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  RecoveryKeySheet.show(context);
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Recovery Key'), findsOneWidget);
    });
  });
}
