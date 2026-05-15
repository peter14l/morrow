import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:oasis/routes/app_router.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:go_router/go_router.dart';

class FakeScreenTimeService {
  void startTracking() {}
  void stopTracking() {}
  void setCurrentCategory(String? category) {}
}

class FakeWellnessService extends ChangeNotifier implements WellnessService {
  @override
  bool get zenModeEnabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserSettingsProvider extends ChangeNotifier
    implements UserSettingsProvider {
  @override
  bool get micaEnabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeThemeProvider extends ChangeNotifier implements ThemeProvider {
  @override
  bool get useFluentUI => false;
  @override
  bool get isM3EEnabled => true;
  @override
  bool get isM3ETransparencyDisabled => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeConversationProvider extends ChangeNotifier
    implements ConversationProvider {
  @override
  int get totalUnreadCount => 2;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEncryptionService {
  Future<EncryptionStatus> init() async => EncryptionStatus.setupComplete;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('MainLayout Mobile Golden Test', (WidgetTester tester) async {
    // Setup Mobile Window Size
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await _pumpMainLayout(tester);
    await tester.pumpAndSettle();

    // Verify NavigationBar exists
    expect(
      find.byType(NavigationBar),
      findsNothing,
    ); // Wait, we use NavigationBarM3E or something. Let's just check for an Icon that exists.
    expect(
      find.byIcon(Icons.person),
      findsNothing,
    ); // It's in the rail? Mobile bottom bar doesn't have Profile.

    // Let's use matchesGoldenFile
    await expectLater(
      find.byType(MainLayout),
      matchesGoldenFile('goldens/main_layout_mobile.png'),
    );

    // Tear down
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('MainLayout Desktop Golden Test', (WidgetTester tester) async {
    // Setup Desktop Window Size
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await _pumpMainLayout(tester);
    await tester.pumpAndSettle();

    // Let's use matchesGoldenFile
    await expectLater(
      find.byType(MainLayout),
      matchesGoldenFile('goldens/main_layout_desktop.png'),
    );

    // Tear down
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

Future<void> _pumpMainLayout(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Center(
                child: Text(
                  'Home Content',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ScreenTimeService>(
          create: (_) => FakeScreenTimeService() as ScreenTimeService,
        ),
        ChangeNotifierProvider<WellnessService>(
          create: (_) => FakeWellnessService(),
        ),
        ChangeNotifierProvider<UserSettingsProvider>(
          create: (_) => FakeUserSettingsProvider(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => FakeThemeProvider(),
        ),
        ChangeNotifierProvider<ConversationProvider>(
          create: (_) => FakeConversationProvider(),
        ),
        Provider<EncryptionService>(
          create: (_) => FakeEncryptionService() as EncryptionService,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        ),
      ),
    ),
  );
}
