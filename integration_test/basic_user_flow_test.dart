import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oasis/main.dart' as app;
import 'package:oasis/widgets/splash_screen.dart';
import 'package:oasis/features/auth/presentation/screens/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Basic User Flow Test', () {
    testWidgets('App starts, shows splash, and reaches login screen', (
      tester,
    ) async {
      // 1. Start the app
      app.main();
      await tester.pumpAndSettle();

      // 2. Verify Splash Screen is shown initially (or app is in transition)
      // Note: app.main() might already be past splash if everything is fast
      debugPrint('Checking for Splash Screen or Login Screen...');

      // 3. Wait for initialization to complete and redirect to Login
      // We use a longer timeout for initialization (Firebase, Supabase, etc)
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 4. Verify we are on the Login Screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);

      debugPrint('✅ Successfully reached Login Screen');

      // 5. Check if we can find common auth elements
      expect(
        find.byType(TextField),
        findsAtLeastNWidgets(2),
      ); // Email and Password

      // 6. Navigate to Register
      final registerButton = find.textContaining('Create Account');
      if (registerButton.evaluate().isNotEmpty) {
        await tester.tap(registerButton);
        await tester.pumpAndSettle();
        debugPrint('✅ Navigated to Register Screen');
      }
    });
  });
}
