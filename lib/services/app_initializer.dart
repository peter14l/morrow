import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:oasis/routes/app_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_io/io.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:oasis/firebase_options.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/services/app_analytics.dart';
import 'package:oasis/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasis/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:oasis/services/desktop_window_service.dart';
import 'package:oasis/services/energy_meter_service.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/services/notification_manager.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:oasis/services/notification_decryption_service.dart';
import 'package:oasis/services/desktop_call_notifier.dart';

import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/services/iap_service.dart';
import 'package:oasis/services/revenuecat_service.dart';
import 'package:oasis/services/razorpay_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/services/curation_tracking_service.dart';
import 'package:oasis/services/voice_transcript_service.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/services/update_service.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:oasis/features/capsules/presentation/providers/capsule_provider.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/features/circles/data/repositories/circle_repository_impl.dart';
import 'package:oasis/providers/community_provider.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:oasis/features/feed/data/repositories/post_repository_impl.dart';
import 'package:oasis/features/feed/data/repositories/comment_repository_impl.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_provider.dart';
import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:oasis/providers/typing_indicator_provider.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/features/messages/presentation/providers/chat_reactions_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:oasis/features/settings/domain/usecases/settings_usecases.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:oasis/features/collections/presentation/providers/collections_provider.dart';
import 'package:oasis/features/collections/data/repositories/collection_repository_impl.dart';
import 'package:oasis/features/collections/domain/usecases/get_collections.dart';
import 'package:oasis/features/collections/domain/usecases/create_collection.dart';
import 'package:oasis/features/collections/domain/usecases/update_collection.dart';
import 'package:oasis/features/collections/domain/usecases/delete_collection.dart';
import 'package:oasis/features/collections/domain/usecases/add_to_collection.dart';
import 'package:oasis/features/collections/domain/usecases/remove_from_collection.dart';
import 'package:oasis/features/collections/domain/usecases/get_collection_detail.dart';
import 'package:oasis/features/collections/domain/usecases/check_post_in_collection.dart';
import 'package:oasis/features/collections/domain/usecases/get_collections_for_post.dart';
import 'package:oasis/features/calling/data/repositories/call_repository_impl.dart';
import 'package:oasis/features/calling/domain/usecases/initiate_call.dart';
import 'package:oasis/features/calling/domain/usecases/accept_call.dart';
import 'package:oasis/features/calling/domain/usecases/end_call.dart';
import 'package:oasis/features/calling/domain/usecases/get_active_calls.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// ---------------------------------------------------------------------------
// ThemeProvider (kept here — it's UI-level state, not a service)
// ---------------------------------------------------------------------------

// Predefined color palette options
enum ColorPalette {
  none, // Uses default M3E colors
  emerald, // Green (current default)
  ocean, // Blue
  sunset, // Orange/Red
  lavender, // Purple
  rose, // Pink
  teal, // Teal
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _highContrast = false;
  bool _isM3EEnabled = true;
  bool _isM3ETransparencyDisabled = false;
  bool _useMaterialYou = false;
  ColorPalette _colorPalette = ColorPalette.none;
  static const String _themeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast';
  static const String _m3eKey = 'm3e_enabled';
  static const String _m3eTransparencyKey = 'm3e_transparency_disabled';
  static const String _materialYouKey = 'use_material_you';
  static const String _colorPaletteKey = 'color_palette';

  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  bool get isM3EEnabled => _isM3EEnabled;
  bool get isM3ETransparencyDisabled => _isM3ETransparencyDisabled;
  bool get useMaterialYou => _useMaterialYou;
  ColorPalette get colorPalette => _colorPalette;

  /// Check if the current platform should use Fluent UI (Windows or macOS)
  bool get useFluentUI {
    // Force Material on mobile platforms and WEB
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) return false;
    
    // Only use Fluent UI on desktop OSs
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return true;
    return false;
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    _highContrast = prefs.getBool(_highContrastKey) ?? false;
    _isM3EEnabled = prefs.getBool(_m3eKey) ?? true;
    _isM3ETransparencyDisabled = prefs.getBool(_m3eTransparencyKey) ?? false;
    _useMaterialYou = prefs.getBool(_materialYouKey) ?? false;
    final paletteIndex =
        prefs.getInt(_colorPaletteKey) ?? ColorPalette.none.index;
    _colorPalette = ColorPalette.values[paletteIndex];
    notifyListeners();
  }

  Future<void> _syncToSupabase() async {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('profiles').update({
          'high_contrast': _highContrast,
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('ThemeProvider: Failed to sync to Supabase: $e');
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, value);
    notifyListeners();
    _syncToSupabase();
  }

  Future<void> setM3EEnabled(bool value) async {
    _isM3EEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_m3eKey, value);
    notifyListeners();
  }

  Future<void> setM3ETransparencyDisabled(bool value) async {
    _isM3ETransparencyDisabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_m3eTransparencyKey, value);
    notifyListeners();
  }

  Future<void> setMaterialYou(bool value) async {
    _useMaterialYou = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_materialYouKey, value);
    notifyListeners();
  }

  Future<void> setColorPalette(ColorPalette palette) async {
    _colorPalette = palette;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorPaletteKey, palette.index);
    notifyListeners();
  }

  /// Generate a ColorScheme based on the selected palette
  ColorScheme? getPaletteColorScheme(Brightness brightness) {
    if (_colorPalette == ColorPalette.none) return null;

    final isDark = brightness == Brightness.dark;
    final baseColor = _getPaletteBaseColor(_colorPalette);

    return ColorScheme.fromSeed(seedColor: baseColor, brightness: brightness);
  }

  Color _getPaletteBaseColor(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return const Color(0xFF6750A4); // Default purple (M3 standard)
      case ColorPalette.emerald:
        return const Color(0xFF1C6758); // Green
      case ColorPalette.ocean:
        return const Color(0xFF0D47A1); // Blue
      case ColorPalette.sunset:
        return const Color(0xFFE65100); // Orange/Red
      case ColorPalette.lavender:
        return const Color(0xFF7E57C2); // Purple
      case ColorPalette.rose:
        return const Color(0xFFC2185B); // Pink
      case ColorPalette.teal:
        return const Color(0xFF00796B); // Teal
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setTheme(_themeMode);
  }
}

// ---------------------------------------------------------------------------
// AppInitializer — encapsulates all startup logic
// ---------------------------------------------------------------------------

/// Holds every service/provider instance needed by the widget tree.
class InitializedServices {
  final ThemeProvider themeProvider;
  final AuthProvider authProvider;
  final UserSettingsProvider userSettingsProvider;
  final ScreenTimeService screenTimeService;
  final WellnessService wellnessService;
  final EnergyMeterService energyMeterService;
  final SubscriptionService subscriptionService;
  final IAPService iapService;
  final RevenueCatService revenueCatService;
  final DigitalWellbeingService digitalWellbeingService;
  final VaultService vaultService;
  final CurationTrackingService curationTrackingService;
  final UpdateService updateService;
  final AppAnalytics appAnalytics;

  const InitializedServices({
    required this.themeProvider,
    required this.authProvider,
    required this.userSettingsProvider,
    required this.screenTimeService,
    required this.wellnessService,
    required this.energyMeterService,
    required this.subscriptionService,
    required this.iapService,
    required this.revenueCatService,
    required this.digitalWellbeingService,
    required this.vaultService,
    required this.curationTrackingService,
    required this.updateService,
    required this.appAnalytics,
  });
}

class AppInitializer {
  /// Background FCM message handler (must be top-level / static).
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    // Required for plugin communication in background isolates
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize database factory for desktop background processes
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    // 1. Core initialization for the background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      // Supabase is critical for decryption (holds user identity)
      await SupabaseService.initialize();
      
      // Give Supabase a tiny moment to restore session from storage
      int retry = 0;
      while (Supabase.instance.client.auth.currentUser == null && retry < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        retry++;
      }
    } catch (e) {
      debugPrint('Background Supabase init failed: $e');
    }

    await NotificationManager.instance.initialize(isBackground: true);

    debugPrint('Handling a background message: ${message.messageId}');

    // 2. Data processing
    if (message.data.isNotEmpty || message.notification != null) {
      final messageType = message.data['message_type'] ?? message.data['type'];

      if (messageType == 'call') {
        final callId = message.data['call_id'] ?? '';
        final callerName = message.data['title'] ?? 'Someone';
        final callerAvatar = message.data['sender_avatar'] ?? '';
        final callType = message.data['call_type'] == 'video' ? 1 : 0;
        
        final params = CallKitParams(
          id: callId,
          nameCaller: callerName,
          appName: 'Oasis',
          avatar: callerAvatar,
          handle: 'Incoming Call',
          type: callType,
          duration: 30000,
          textAccept: 'Accept',
          textDecline: 'Decline',
          missedCallNotification: const NotificationParams(
            showNotification: true,
            isShowCallback: false,
            subtitle: 'Missed call',
          ),
          extra: message.data,
        );
        
        await FlutterCallkitIncoming.showCallkitIncoming(params);
        return;
      }

      // 3. Decryption
      String title =
          message.data['title'] ??
          message.notification?.title ??
          'New Notification';
      
      String body =
          message.data['body'] ??
          message.notification?.body ?? 
          '';
      
      // Decrypt body if it's an encrypted message
      try {
        final decryptedBody = await NotificationDecryptionService().decryptMessage(message.data);
        if (decryptedBody != null && decryptedBody.isNotEmpty && !decryptedBody.contains('🔒')) {
          body = decryptedBody;
        } else if (body.length > 100 && !body.contains(' ')) {
           // If body looks like a long base64/hex string and decryption failed, 
           // better show a placeholder than the raw ciphertext.
           body = '🔒 Encrypted message';
        }
      } catch (e) {
        debugPrint('Background decryption failed: $e');
      }

      final String? payload = message.data.isNotEmpty
          ? jsonEncode(message.data)
          : null;

      // 4. Show Notification
      await NotificationManager.instance.showNotification(
        title: title,
        body: body,
        payload: payload,
        senderAvatar: message.data['sender_avatar'],
        messageType: message.data['message_type'] ?? message.data['type'],
      );
    }
  }

  /// Step 1 — Load .env (best-effort, never fatal).
  static Future<void> loadEnv() async {
    try {
      // Use String.fromEnvironment to check if we have injected keys
      // if we have them, we might not need the .env file at all.
      const hasUrl = String.fromEnvironment('SUPABASE_URL');
      if (hasUrl.isNotEmpty) {
        debugPrint(
          '.env variables injected via dart-define, skipping file load',
        );
        return;
      }

      // Only attempt to load if the file exists in the bundle
      // Note: flutter_dotenv load() throws if not found in assets
      await dotenv.load(fileName: '.env');
      debugPrint('.env loaded successfully');
    } catch (e) {
      debugPrint('Note: .env file not loaded (intended for release): $e');
    }
  }

  /// Step 2 — Initialize Sentry and run the app inside its appRunner.
  static Future<void> runWithSentry(Future<void> Function() appRunner) async {
    debugPrint('runWithSentry: Setting up Sentry options...');
    try {
      await SentryFlutter.init(
        (options) {
          debugPrint('SentryFlutter.init callback started');
          const dsn = String.fromEnvironment('SENTRY_DSN');
          options.dsn = dsn.isNotEmpty ? dsn : null;
          options.tracesSampleRate = kDebugMode ? 0.2 : 0.05;
          options.sendDefaultPii = false;
          options.debug = false;
          debugPrint(
            'Sentry options configured',
          );
        },
      );
      debugPrint('SentryFlutter.init call completed');
    } catch (e, st) {
      debugPrint('Sentry initialization exception: $e');
      debugPrint('Stack trace: $st');
    }
    
    // Run the app in the current zone
    debugPrint('Sentry appRunner triggered (in root zone)');
    await appRunner();
  }

  /// Step 3 — Initialize Firebase (best-effort).
  static Future<void> initFirebase() async {
    debugPrint('Initializing Firebase...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      // Log app open to trigger DAU reporting
      unawaited(AppAnalytics().logAppOpen());
      
      debugPrint('Firebase initialized successfully');
    } catch (e, st) {
      debugPrint('Firebase initialization failed: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Step 4 — Core initialization: Supabase → auth → settings → services.
  /// Returns all pre-instantiated providers so main.dart can wire them up.
  static Future<InitializedServices> initCore() async {
    // Initialize database factory for desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Android-specific WebView initialization
    if (Platform.isAndroid) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    }

    // --- CRITICAL PHASE: Must complete before UI shows ---
    debugPrint('STEP: Critical initialization starting...');
    
    // 1. Supabase & Storage (Parallel)
    await Future.wait([
      SupabaseService.initialize(),
      PrefsStorage.init(),
    ]);

    // Handle CallKit events (Android/iOS only — plugin doesn't exist on desktop)
    if (Platform.isAndroid || Platform.isIOS) {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        switch (event.event) {
          case Event.actionCallAccept:
            final data = event.body['extra'];
            if (data == null) break;
            final callId = data['call_id'];
            final senderId = data['actor_id'];
            if (callId != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                AppRouter.router.pushNamed(
                  'active_call',
                  pathParameters: {'callId': callId},
                  extra: {'isIncoming': true, 'callerId': senderId},
                );
              });
            }
            break;
          case Event.actionCallDecline:
            final data = event.body['extra'];
            if (data == null) break;
            final callId = data['call_id'];
            if (callId != null) {
              SupabaseService().client
                .from('calls')
                .update({'status': 'declined'})
                .eq('id', callId);
            }
            break;
          default:
            break;
        }
      });
    }

    // 2. Auth & Theme & Settings & Analytics (Parallel)
    final appAnalytics = AppAnalytics();
    final authProvider = AuthProvider(
      repository: AuthRepositoryImpl(),
      analytics: appAnalytics,
    );

    final themeProvider = ThemeProvider();
    final settingsRepo = SettingsRepositoryImpl();
    final userSettingsProvider = UserSettingsProvider(
      getSettingsUseCase: GetSettingsUseCase(settingsRepo),
      saveSettingsUseCase: SaveSettingsUseCase(settingsRepo),
    );

    await Future.wait([
      authProvider.restoreSession(),
      themeProvider.loadTheme(),
      userSettingsProvider.loadSettings(),
    ]);

    // --- BACKGROUND PHASE: Can finish after splash screen ---
    debugPrint('STEP: Background initialization starting...');

    // Initialize DM notifications after session is restored, but don't block
    if (authProvider.isAuthenticated) {
      unawaited(Future.microtask(() => subscribeToDmNotifications()));
    }

    // Windows enhancements
    if (Platform.isWindows) {
      unawaited(DesktopWindowService.instance.initialize().then((_) async {
        await DesktopWindowService.instance.enableCloseToTray();
        await DesktopWindowService.instance.setWindowEffect(
          enabled: userSettingsProvider.micaEnabled,
          effect: userSettingsProvider.windowEffect,
        );
      }));
    }

    // Wellness & tracking services - PARALLELIZE
    final screenTimeServiceFuture = ScreenTimeService.init();
    final wellnessServiceFuture = WellnessService.init();
    final digitalWellbeingServiceFuture = DigitalWellbeingService.init(AuthService());
    final energyMeterServiceFuture = EnergyMeterService.init();

    final wellnessResults = await Future.wait([
      screenTimeServiceFuture,
      wellnessServiceFuture,
      digitalWellbeingServiceFuture,
      energyMeterServiceFuture,
    ]);

    final screenTimeService = wellnessResults[0] as ScreenTimeService;
    final wellnessService = wellnessResults[1] as WellnessService;
    final digitalWellbeingService = wellnessResults[2] as DigitalWellbeingService;
    final energyMeterService = wellnessResults[3] as EnergyMeterService;

    // Pre-initialize basic Notification manager
    await NotificationManager.instance.initialize();

    // Deferred non-critical services (IAP, Subscriptions, Encryption, etc.)
    final iapService = IAPService();
    final revenueCatService = RevenueCatService();
    final subscriptionService = SubscriptionService();
    final vaultService = VaultService();
    final razorpayService = RazorpayService();
    final curationTrackingService = CurationTrackingService();
    final updateService = UpdateService.instance;

    unawaited(() async {
      try {
        await Future.wait([
          iapService.init(),
          revenueCatService.init(),
          subscriptionService.init(),
          vaultService.init(),
          EncryptionService().init(),
          SignalService().init(),
        ]).timeout(const Duration(seconds: 15));
        
        razorpayService.init();
        debugPrint('Post-startup background services completed');
      } catch (e) {
        debugPrint('Non-critical background service init warning: $e');
      }
    }());

    return InitializedServices(
      themeProvider: themeProvider,
      authProvider: authProvider,
      userSettingsProvider: userSettingsProvider,
      screenTimeService: screenTimeService,
      wellnessService: wellnessService,
      energyMeterService: energyMeterService,
      subscriptionService: subscriptionService,
      iapService: iapService,
      revenueCatService: revenueCatService,
      digitalWellbeingService: digitalWellbeingService,
      vaultService: vaultService,
      curationTrackingService: curationTrackingService,
      updateService: updateService,
      appAnalytics: appAnalytics,
    );
  }

  /// Subscribe to DM notifications and display local notifications
  static void subscribeToDmNotifications() {
    final supabase = SupabaseService().client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final notificationService = NotificationService();
    notificationService.subscribeToNotifications(
      userId: userId,
      onNewNotification: (notification) async {
        // Only handle DM notifications - other types are handled elsewhere
        if (notification.type == 'dm') {
          // Get sender info for the notification
          final senderName = notification.actorName ?? 'Someone';
          final senderAvatar = notification.actorAvatar;

          String body = notification.message ?? 'New message';
          
          // Decrypt body if it's an encrypted message
          final decryptedBody = await NotificationDecryptionService().decryptNotification(notification);
          if (decryptedBody != null) {
            body = decryptedBody;
          }

          // Show local notification with grouping payload
          NotificationManager.instance.showNotification(
            title: senderName,
            body: body,
            senderAvatar: senderAvatar,
            messageType: 'dm',
            payload: jsonEncode({
              'type': 'dm',
              'conversation_id': notification.conversationId ?? notification.actorId,
              'message_id': notification.messageId,
              'sender_id': notification.actorId,
              'sender_name': senderName,
              'sender_avatar': senderAvatar,
            }),
          );
        }
      },
    );
    debugPrint('AppInitializer: Subscribed to DM notifications');
  }

  /// Step 5 — Build the MultiProvider tree with all initialized services.
  static Widget buildProviderTree({
    required InitializedServices services,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        Provider<AppAnalytics>.value(value: services.appAnalytics),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: services.themeProvider,
        ),
        ChangeNotifierProvider<AuthProvider>.value(
          value: services.authProvider,
        ),
        ChangeNotifierProvider<AuthService>.value(value: AuthService()),
        ChangeNotifierProvider<MessagingService>(create: (_) => MessagingService()),
        ChangeNotifierProvider<UserSettingsProvider>.value(
          value: services.userSettingsProvider,
        ),
        ChangeNotifierProvider<ScreenTimeService>.value(
          value: services.screenTimeService,
        ),
        ChangeNotifierProvider<WellnessService>.value(
          value: services.wellnessService,
        ),
        ChangeNotifierProvider<DigitalWellbeingService>.value(
          value: services.digitalWellbeingService,
        ),
        ChangeNotifierProvider<EnergyMeterService>.value(
          value: services.energyMeterService,
        ),
        ChangeNotifierProvider<SubscriptionService>.value(
          value: services.subscriptionService,
        ),
        ChangeNotifierProvider<IAPService>.value(value: services.iapService),
        ChangeNotifierProvider<RevenueCatService>.value(
          value: services.revenueCatService,
        ),
        ChangeNotifierProvider<RazorpayService>.value(value: RazorpayService()),
        Provider<EncryptionService>(create: (_) => EncryptionService()),
        ChangeNotifierProvider(
          create: (_) => FeedProvider(
            feedRepository: FeedRepositoryImpl(),
            postRepository: PostRepositoryImpl(),
            commentRepository: CommentRepositoryImpl(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            profileRepository: ProfileRepositoryImpl(),
            postRepository: PostRepositoryImpl(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => TypingIndicatorProvider()),
        ChangeNotifierProvider(create: (_) => PresenceProvider()),
        ChangeNotifierProxyProvider<PresenceProvider, ConversationProvider>(
          create: (_) => ConversationProvider(),
          update: (context, presenceProvider, conversationProvider) =>
              conversationProvider!..updatePresenceProvider(presenceProvider),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => CanvasProvider()),
        ChangeNotifierProvider(
          create: (_) => CircleProvider(repository: CircleRepositoryImpl()),
        ),
        ChangeNotifierProvider(create: (_) => RipplesProvider()),
        ChangeNotifierProvider(create: (_) => CapsuleProvider()),
        ChangeNotifierProvider(create: (_) => StoriesProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final repo = CollectionRepositoryImpl();
            return CollectionsProvider(
              getCollectionsUseCase: GetCollectionsUseCase(repo),
              createCollectionUseCase: CreateCollectionUseCase(repo),
              updateCollectionUseCase: UpdateCollectionUseCase(repo),
              deleteCollectionUseCase: DeleteCollectionUseCase(repo),
              addToCollectionUseCase: AddToCollectionUseCase(repo),
              removeFromCollectionUseCase: RemoveFromCollectionUseCase(repo),
              getCollectionDetailUseCase: GetCollectionDetailUseCase(repo),
              checkPostInCollectionUseCase: CheckPostInCollectionUseCase(repo),
              getCollectionsForPostUseCase: GetCollectionsForPostUseCase(repo),
            );
          },
        ),
        ChangeNotifierProvider<VaultService>.value(
          value: services.vaultService,
        ),
        ChangeNotifierProvider<UpdateService>.value(
          value: services.updateService,
        ),
        ChangeNotifierProvider<CurationTrackingService>.value(
          value: services.curationTrackingService,
        ),
        Provider<VoiceTranscriptService>(
          create: (_) => VoiceTranscriptService(),
        ),
        ChangeNotifierProvider<CallService>(
          create: (_) => AppConfig.enableCalls ? CallService() : DisabledCallService(),
        ),
        ChangeNotifierProxyProvider<CallService, CallProvider>(
          create: (context) {
            CallService? callService;
            try {
               callService = context.read<CallService>();
            } catch (e) {
               debugPrint('CallService not found during CallProvider creation: $e');
               callService = DisabledCallService();
            }
            final provider = CallProvider(callService);
            
            if (AppConfig.enableCalls && callService is! DisabledCallService) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Check if context is still valid (using a closure-safe way)
                final repo = CallRepositoryImpl();
                provider.initialize(
                  initiateCall: InitiateCall(repo),
                  acceptCall: AcceptCall(repo),
                  endCall: EndCall(repo),
                  getActiveCalls: GetActiveCalls(repo),
                );
              });
            } else {
              // Mark as initialized but don't start any listeners
              // Use a private microtask to not block create()
              Future.microtask(() {
                try {
                  if (context.mounted) {
                    provider.clearError(); // Just to trigger a notify if needed
                  }
                } catch (_) {}
              });
            }
            return provider;
          },
          update: (context, service, provider) => provider!,
        ),
      ],
      child: child,
    );
  }
}
