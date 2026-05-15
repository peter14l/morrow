/// Test utilities for Oasis app
///
/// This file provides common test setup functions and mock factories
/// to streamline testing across the application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/services/screen_time_service.dart';

/// Sets up shared preferences for testing
Future<void> setupTestPreferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
}

/// Creates a test wrapper widget with necessary providers
Widget createTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: themeMode,
    home: child,
  );
}

/// Creates a test wrapper with a Scaffold
Widget createScaffoldTestApp({
  required Widget body,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  return createTestApp(
    themeMode: themeMode,
    child: Scaffold(body: body),
  );
}

/// Pumps a widget and waits for all animations to complete
Future<void> pumpAndSettle(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

/// Helper to create a ScreenTimeService for testing
Future<ScreenTimeService> createTestScreenTimeService() async {
  await setupTestPreferences();
  return ScreenTimeService.init();
}

/// Helper class for common test assertions
class TestAssertions {
  /// Asserts that a widget with the given key exists
  static void widgetExists(String key) {
    expect(find.byKey(Key(key)), findsOneWidget);
  }

  /// Asserts that text exists in the widget tree
  static void textExists(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Asserts that text does not exist in the widget tree
  static void textNotExists(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Asserts that a widget of type T exists
  static void widgetOfTypeExists<T>() {
    expect(find.byType(T), findsOneWidget);
  }
}

/// Extension on WidgetTester for common operations
extension WidgetTesterExtensions on WidgetTester {
  /// Enters text into a text field with the given key
  Future<void> enterTextByKey(String key, String text) async {
    await enterText(find.byKey(Key(key)), text);
    await pump();
  }

  /// Taps a widget with the given key
  Future<void> tapByKey(String key) async {
    await tap(find.byKey(Key(key)));
    await pump();
  }

  /// Taps a widget with the given text
  Future<void> tapByText(String text) async {
    await tap(find.text(text));
    await pump();
  }
}
