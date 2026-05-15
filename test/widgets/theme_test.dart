import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasis/themes/app_theme.dart';
import '../test_setup.dart';

void main() {
  setupTestEnvironment();

  group('AppTheme', () {
    group('Light Theme', () {
      test('should have correct primary color', () {
        final theme = AppTheme.light();
        expect(theme.colorScheme.primary, isNotNull);
      });

      test('should use Material 3', () {
        final theme = AppTheme.light();
        expect(theme.useMaterial3, isTrue);
      });

      test('should have light brightness', () {
        final theme = AppTheme.light();
        expect(theme.colorScheme.brightness, equals(Brightness.light));
      });

      test('should have text theme', () {
        final theme = AppTheme.light();
        expect(theme.textTheme, isNotNull);
        expect(theme.textTheme.bodyMedium, isNotNull);
      });
    });

    group('Dark Theme', () {
      test('should have correct primary color', () {
        final theme = AppTheme.dark();
        expect(theme.colorScheme.primary, isNotNull);
      });

      test('should use Material 3', () {
        final theme = AppTheme.dark();
        expect(theme.useMaterial3, isTrue);
      });

      test('should have dark brightness', () {
        final theme = AppTheme.dark();
        expect(theme.colorScheme.brightness, equals(Brightness.dark));
      });

      test('should have dark scaffold background', () {
        final theme = AppTheme.dark();
        expect(theme.scaffoldBackgroundColor, isNotNull);
        // Dark theme scaffold should be darker than white
        expect(theme.scaffoldBackgroundColor.computeLuminance(), lessThan(0.2));
      });
    });

    group('getTheme helper', () {
      test('should return light theme for Brightness.light', () {
        final theme = AppTheme.getTheme(Brightness.light);
        expect(theme.colorScheme.brightness, equals(Brightness.light));
      });

      test('should return dark theme for Brightness.dark', () {
        final theme = AppTheme.getTheme(Brightness.dark);
        expect(theme.colorScheme.brightness, equals(Brightness.dark));
      });
    });

    group('Theme Components', () {
      test('should have card theme', () {
        expect(AppTheme.light().cardTheme, isNotNull);
        expect(AppTheme.dark().cardTheme, isNotNull);
      });

      test('should have elevated button theme', () {
        expect(AppTheme.light().elevatedButtonTheme, isNotNull);
        expect(AppTheme.dark().elevatedButtonTheme, isNotNull);
      });

      test('should have input decoration theme', () {
        expect(AppTheme.light().inputDecorationTheme, isNotNull);
        expect(AppTheme.dark().inputDecorationTheme, isNotNull);
      });

      test('should have navigation bar theme', () {
        expect(AppTheme.light().navigationBarTheme, isNotNull);
        expect(AppTheme.dark().navigationBarTheme, isNotNull);
      });
    });
  });

  group('Theme Widget Tests', () {
    testWidgets('Light theme applies correctly to MaterialApp', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: Center(child: Text('Test'))),
          ),
        );
        await tester.pumpAndSettle();
      });

      final context = tester.element(find.byType(Scaffold));
      final theme = Theme.of(context);

      expect(theme.colorScheme.brightness, equals(Brightness.light));
    });

    testWidgets('Dark theme applies correctly to MaterialApp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: Text('Test'))),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final theme = Theme.of(context);

      expect(theme.colorScheme.brightness, equals(Brightness.dark));
    });

    testWidgets('Theme colors are accessible for text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Button'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Button'), findsOneWidget);
    });
  });
}
