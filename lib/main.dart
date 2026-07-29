import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrintThrottled, kDebugMode;

import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/routes/app_router.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/services/desktop_window_service.dart';
import 'package:oasis/services/energy_meter_service.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/services/sharing_service.dart';
import 'package:oasis/services/deep_link_service.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:flutter/services.dart' as services;
import 'package:firebase_core/firebase_core.dart';
import 'package:oasis/firebase_options.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_provider.dart';
import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/calling/presentation/widgets/floating_call_overlay.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/themes/app_theme.dart';
import 'package:oasis/themes/fluent_theme.dart';
import 'package:oasis/widgets/windows_title_bar.dart';
import 'package:oasis/widgets/mesh_gradient_background.dart';
import 'package:oasis/widgets/splash_screen.dart';
import 'package:oasis/widgets/global_wellness_wrapper.dart';
import 'package:oasis/services/update_service.dart';
import 'package:oasis/services/home_arrival_service.dart';
import 'package:oasis/services/home_checkin_service.dart';
import 'package:oasis/features/couples/data/home_checkin_repository.dart';
import 'package:oasis/widgets/verification_dialog.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:oasis/widgets/lifecycle_manager.dart';
import 'package:oasis/widgets/call_navigator.dart';
import 'package:oasis/features/calling/presentation/screens/incoming_call_overlay_screen.dart';

// ---------------------------------------------------------------------------
// Global Shortcuts and Scroll
// ---------------------------------------------------------------------------

class EscapeIntent extends material.Intent {
  const EscapeIntent();
}

class AppScrollBehavior extends material.ScrollBehavior {
  @override
  Set<ui.PointerDeviceKind> get dragDevices => {
        ui.PointerDeviceKind.touch,
        ui.PointerDeviceKind.mouse,
        ui.PointerDeviceKind.trackpad,
      };
}



class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;
  bool _navigatingToReset = false;
  String? _lastInitializedUserId;

  material.ThemeData? _cachedLightTheme;
  material.ThemeData? _cachedDarkTheme;
  material.ColorScheme? _cachedLightScheme;
  material.ColorScheme? _cachedDarkScheme;
  String _cachedSettingsKey = '';
  final bool _themeSettingsChanged = true;
  bool? _cachedIsDark;
  bool? _cachedMicaEnabled;
  String? _cachedWindowEffect;

  @override
  void initState() {
    super.initState();
    _listenForPasswordRecovery();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (kIsWeb) return;
    final updateInfo = await UpdateService.instance.checkForUpdates();
    if (updateInfo != null && updateInfo.isUpdateAvailable) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _showUpdateNotification(updateInfo);
        }
      });
    }
  }

  void _showUpdateNotification(UpdateInfo updateInfo) {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null) return;

    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS);

    if (isDesktop) {
      material.showDialog(
        context: context,
        barrierDismissible: !updateInfo.isRequired,
        builder: (context) => material.Center(
          child: material.Container(
            width: 450,
            padding: const material.EdgeInsets.all(32),
            decoration: material.BoxDecoration(
              color: material.Theme.of(context).colorScheme.surface,
              borderRadius: material.BorderRadius.circular(24),
              border: material.Border.all(
                color: material.Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                material.BoxShadow(
                  color: material.Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const material.Offset(0, 10),
                ),
              ],
            ),
            child: material.Material(
              color: material.Colors.transparent,
              child: material.Column(
                mainAxisSize: material.MainAxisSize.min,
                crossAxisAlignment: material.CrossAxisAlignment.start,
                children: [
                  material.Row(
                    children: [
                      material.Container(
                        padding: const material.EdgeInsets.all(12),
                        decoration: material.BoxDecoration(
                          color: material.Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: material.BorderRadius.circular(16),
                        ),
                        child: material.Icon(
                          material.Icons.system_update,
                          color: material.Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const material.SizedBox(width: 20),
                      material.Expanded(
                        child: material.Column(
                          crossAxisAlignment: material.CrossAxisAlignment.start,
                          children: [
                            material.Text(
                              'Update Available',
                              style: material.Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: material.FontWeight.bold,
                                  ),
                            ),
                            material.Text(
                              'Version ${updateInfo.latestVersion} is ready to install',
                              style: material.Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: material.Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const material.SizedBox(height: 24),
                  if (updateInfo.releaseNotes.isNotEmpty) ...[
                    material.Text(
                      'What\'s New:',
                      style: material.Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: material.FontWeight.bold),
                    ),
                    const material.SizedBox(height: 12),
                    material.Container(
                      padding: const material.EdgeInsets.all(16),
                      decoration: material.BoxDecoration(
                        color: material.Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: material.BorderRadius.circular(12),
                      ),
                      child: material.Text(
                        updateInfo.releaseNotes,
                        style: material.Theme.of(context).textTheme.bodyMedium,
                        maxLines: 8,
                        overflow: material.TextOverflow.ellipsis,
                      ),
                    ),
                    const material.SizedBox(height: 32),
                  ],
                  material.Row(
                    mainAxisAlignment: material.MainAxisAlignment.end,
                    children: [
                      if (!updateInfo.isRequired)
                        material.TextButton(
                          onPressed: () => material.Navigator.pop(context),
                          child: const material.Text('Later'),
                        ),
                      if (!updateInfo.isRequired)
                        const material.SizedBox(width: 12),
                      material.FilledButton.icon(
                        onPressed: () {
                          material.Navigator.pop(context);
                          context.push('/settings/update');
                        },
                        icon: const material.Icon(
                          material.Icons.download,
                          size: 18,
                        ),
                        label: const material.Text('Update Now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: material.Colors.transparent,
      builder: (context) => material.Container(
        padding: const material.EdgeInsets.all(24),
        decoration: material.BoxDecoration(
          color: material.Theme.of(context).colorScheme.surface,
          borderRadius: const material.BorderRadius.vertical(
            top: material.Radius.circular(32),
          ),
        ),
        child: material.Column(
          mainAxisSize: material.MainAxisSize.min,
          crossAxisAlignment: material.CrossAxisAlignment.start,
          children: [
            material.Center(
              child: material.Container(
                width: 40,
                height: 4,
                decoration: material.BoxDecoration(
                  color: material.Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: material.BorderRadius.circular(2),
                ),
              ),
            ),
            const material.SizedBox(height: 24),
            material.Row(
              children: [
                material.Icon(
                  material.Icons.system_update,
                  color: material.Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const material.SizedBox(width: 16),
                material.Expanded(
                  child: material.Column(
                    crossAxisAlignment: material.CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        'New Version Available',
                        style: material.Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: material.FontWeight.bold),
                      ),
                      material.Text(
                        'Version ${updateInfo.latestVersion} is ready',
                        style: material.Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: material.Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const material.SizedBox(height: 20),
            if (updateInfo.releaseNotes.isNotEmpty) ...[
              material.Text(
                'What\'s New:',
                style: material.Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: material.FontWeight.bold),
              ),
              const material.SizedBox(height: 8),
              material.Text(
                updateInfo.releaseNotes,
                style: material.Theme.of(context).textTheme.bodyMedium,
                maxLines: 5,
                overflow: material.TextOverflow.ellipsis,
              ),
              const material.SizedBox(height: 20),
            ],
            material.Row(
              children: [
                if (!updateInfo.isRequired)
                  material.Expanded(
                    child: material.OutlinedButton(
                      onPressed: () => material.Navigator.pop(context),
                      child: const material.Text('Later'),
                    ),
                  ),
                if (!updateInfo.isRequired) const material.SizedBox(width: 12),
                material.Expanded(
                  flex: 2,
                  child: material.FilledButton(
                    onPressed: () {
                      material.Navigator.pop(context);
                      context.push('/settings/update');
                    },
                    child: const material.Text('Update Now'),
                  ),
                ),
              ],
            ),
            const material.SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _listenForPasswordRecovery() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery &&
          !_navigatingToReset) {
        _navigatingToReset = true;
        material.WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              AppRouter.router.go('/reset-password');
            }
            _navigatingToReset = false;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _handleInitialization(String? userId) {
    if (_lastInitializedUserId == userId) return;
    debugPrint('[MainApp] _handleInitialization triggered for userId: $userId');
    _lastInitializedUserId = userId;

    if (userId != null) {
      debugPrint('[MainApp] Starting full initialization for user $userId');
      // Use unawaited to fire off data loads concurrently without blocking UI
      // We still use slight delays to prioritize the very first frame of the home screen
      unawaited(
        Future.microtask(() {
          if (!mounted) return;
          debugPrint('[MainApp] Initializing Notification and Presence');
          context.read<NotificationProvider>().init(userId);
          context.read<PresenceProvider>().updateUserPresence(userId, 'online');
        }),
      );

      unawaited(
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          debugPrint('[MainApp] Initializing ConversationProvider');
          context.read<ConversationProvider>().initialize(userId);
        }),
      );

      unawaited(
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          debugPrint('[MainApp] Initializing ProfileProvider');
          context.read<ProfileProvider>().loadCurrentProfile(userId);
        }),
      );

      // Non-critical data can wait even longer or be triggered by screen entry
      unawaited(
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            debugPrint('[MainApp] Triggering Circle and Canvas loading');
            context.read<CircleProvider>().loadCircles(userId);
            context.read<CanvasProvider>().loadCanvases(userId);

            if (AppConfig.enableCalls) {
              debugPrint('[MainApp] Eagerly instantiating CallProvider');
              // Eagerly instantiate CallProvider to attach incoming call listeners
              context.read<CallProvider>();
            }
          } else {
            debugPrint(
              '[MainApp] Widget unmounted before 500ms delay, skipping circle/canvas load',
            );
          }
        }),
      );

      SharingService().init(context);
      DeepLinkService().init();
    } else {
      debugPrint('[MainApp] User is null, only initializing notifications');
      context.read<NotificationProvider>().init(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router;
    final themeProvider = context.watch<ThemeProvider>();
    final userSettings = context.watch<UserSettingsProvider>();
    final authService = Provider.of<AuthService>(context, listen: false);

    return DynamicColorBuilder(
      builder: (material.ColorScheme? lightDynamic, material.ColorScheme? darkDynamic) {
        // OPTIMIZATION: Cache theme objects to prevent expensive re-calculation on every rebuild
        // but ensure key includes all relevant styling tokens for desktop reactivity.
        final settingsKey =
            '${themeProvider.themeMode}_'
            '${themeProvider.isM3EEnabled}_'
            '${themeProvider.useMaterialYou}_'
            '${themeProvider.colorPalette}_'
            '${themeProvider.highContrast}_'
            '${userSettings.micaEnabled}_'
            '${userSettings.windowEffect}_'
            '${userSettings.fontFamily}_'
            '${lightDynamic?.primary.value}_'
            '${darkDynamic?.primary.value}';

        if (settingsKey != _cachedSettingsKey) {
          _cachedSettingsKey = settingsKey;

          material.ColorScheme? lightScheme;
          material.ColorScheme? darkScheme;

          if (themeProvider.useMaterialYou && themeProvider.isM3EEnabled) {
            lightScheme = lightDynamic;
            darkScheme = darkDynamic;
          } else {
            // Always use our HSL palette color scheme so dynamic theme colors
            // are applied app-wide, not just in M3E mode. This prevents
            // falling back to the hardcoded OasisColors.deep (black) background.
            lightScheme = themeProvider.getPaletteColorScheme(
              material.Brightness.light,
            );
            darkScheme = themeProvider.getPaletteColorScheme(
              material.Brightness.dark,
            );
          }

          _cachedLightScheme = lightScheme;
          _cachedDarkScheme = darkScheme;

          _cachedLightTheme = AppTheme.getTheme(
            material.Brightness.light,
            isM3E: themeProvider.isM3EEnabled,
            highContrast: themeProvider.highContrast,
            micaEnabled: userSettings.micaEnabled,
            fontFamily: userSettings.fontFamily,
            dynamicColorScheme: lightScheme,
          );
          _cachedDarkTheme = AppTheme.getTheme(
            material.Brightness.dark,
            isM3E: themeProvider.isM3EEnabled,
            highContrast: themeProvider.highContrast,
            micaEnabled: userSettings.micaEnabled,
            fontFamily: userSettings.fontFamily,
            dynamicColorScheme: darkScheme,
          );
        }

        final theme = _cachedLightTheme ?? material.ThemeData.light();
        final darkTheme = _cachedDarkTheme ?? material.ThemeData.dark();

        return StreamBuilder<AuthState>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            final userId = snapshot.hasData && snapshot.data?.session != null
                ? snapshot.data!.session!.user.id
                : null;

            // Use postFrameCallback to avoid calling setState/init during build
            material.WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _handleInitialization(userId);
            });

            // Apply window effects whenever the theme or settings change
            if (!kIsWeb && Platform.isWindows) {
              final isDark =
                  themeProvider.themeMode == material.ThemeMode.system
                  ? material.MediaQuery.platformBrightnessOf(context) ==
                        material.Brightness.dark
                  : themeProvider.themeMode == material.ThemeMode.dark;

              material.WidgetsBinding.instance.addPostFrameCallback((_) {
                DesktopWindowService.instance.setWindowEffect(
                  enabled: userSettings.micaEnabled,
                  effect: userSettings.windowEffect,
                  isDark: isDark,
                );
              });
            }

            if (themeProvider.useFluentUI) {
              return fluent.FluentApp.router(
                title: 'Oasis',
                debugShowCheckedModeBanner: false,
                theme: AppFluentTheme.getTheme(
                  material.Brightness.light,
                  materialColorScheme: _cachedLightScheme,
                  fontFamily: userSettings.fontFamily,
                  micaEnabled: userSettings.micaEnabled,
                ),
                darkTheme: AppFluentTheme.getTheme(
                  material.Brightness.dark,
                  materialColorScheme: _cachedDarkScheme,
                  fontFamily: userSettings.fontFamily,
                  micaEnabled: userSettings.micaEnabled,
                ),
                themeMode: themeProvider.themeMode == material.ThemeMode.system
                    ? fluent.ThemeMode.system
                    : themeProvider.themeMode == material.ThemeMode.dark
                    ? fluent.ThemeMode.dark
                    : fluent.ThemeMode.light,
                scrollBehavior: AppScrollBehavior(),
                routerConfig: router,
                builder: (context, child) {
                  return material.ScaffoldMessenger(
                    child: material.Stack(
                      children: [
                        material.Padding(
                          padding: material.EdgeInsets.only(
                            top: (!kIsWeb && Platform.isWindows) ? kWin11TitleBarHeight : 0,
                          ),
                          child: material.MediaQuery(
                            data: material.MediaQuery.of(context).copyWith(
                              textScaler: material.TextScaler.linear(
                                userSettings.fontSizeFactor,
                              ),
                            ),
                            child: GlobalWellnessWrapper(
                              child: material.Shortcuts(
                                shortcuts: <material.LogicalKeySet, material.Intent>{
                                  material.LogicalKeySet(services.LogicalKeyboardKey.escape): const EscapeIntent(),
                                },
                                child: material.Actions(
                                  actions: <Type, material.Action<material.Intent>>{
                                    EscapeIntent: material.CallbackAction<EscapeIntent>(
                                      onInvoke: (EscapeIntent intent) {
                                        if (router.canPop()) router.pop();
                                        return null;
                                      },
                                    ),
                                  },
                                  child: CallNavigator(child: child!),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!kIsWeb && Platform.isWindows)
                          const WindowsTitleBar(height: kWin11TitleBarHeight),
                        // const FloatingCallOverlay(),
                      ],
                    ),
                  );
                },
              );
            }

            return material.MaterialApp.router(
              title: 'Oasis',
              debugShowCheckedModeBanner: false,
              theme: theme,
              darkTheme: darkTheme,
              themeMode: themeProvider.themeMode,
              scrollBehavior: AppScrollBehavior(),
              routerConfig: router,
              builder: (context, child) {
                return material.Stack(
                  children: [
                    material.Padding(
                      padding: material.EdgeInsets.only(
                        top: (!kIsWeb && Platform.isWindows) ? kWin11TitleBarHeight : 0,
                      ),
                      child: material.MediaQuery(
                        data: material.MediaQuery.of(context).copyWith(
                          textScaler: material.TextScaler.linear(
                            userSettings.fontSizeFactor,
                          ),
                          boldText: false,
                        ),
                        child: GlobalWellnessWrapper(
                          child: material.Shortcuts(
                            shortcuts: <material.LogicalKeySet, material.Intent>{
                              material.LogicalKeySet(services.LogicalKeyboardKey.escape): const EscapeIntent(),
                            },
                            child: material.Actions(
                              actions: <Type, material.Action<material.Intent>>{
                                EscapeIntent: material.CallbackAction<EscapeIntent>(
                                  onInvoke: (EscapeIntent intent) {
                                    if (router.canPop()) router.pop();
                                    return null;
                                  },
                                ),
                              },
                              child: CallNavigator(child: child!),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!kIsWeb && Platform.isWindows) const WindowsTitleBar(height: kWin11TitleBarHeight),
                    // const FloatingCallOverlay(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}



void main() async {
  // 1. Initialize Flutter bindings in the Root Zone.
  // This prevents "Zone mismatch" errors if async operations drop the zone.
  material.WidgetsFlutterBinding.ensureInitialized();

  // 2. Silence Flutter framework errors that are harmless but messy
  material.FlutterError.onError = (material.FlutterErrorDetails details) {
    final exception = details.exception;
    final errorStr = exception.toString();
    if (exception is AssertionError) {
      if (errorStr.contains('RawKeyDownEvent') &&
          errorStr.contains('_keysPressed.isNotEmpty')) {
        // Silencing the Windows "Alt" key assertion error
        return;
      }
    }
    // Forward everything else to Sentry and default handler
    Sentry.captureException(details.exception, stackTrace: details.stack);
    material.FlutterError.presentError(details);
  };

  // 3. Catch all uncaught asynchronous errors (replaces runZonedGuarded)
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    final errorStrLower = errorStr.toLowerCase();

    if (error is AssertionError) {
      if (errorStr.contains('RawKeyDownEvent') &&
          errorStr.contains('_keysPressed.isNotEmpty')) {
        // Silencing the Windows "Alt" key assertion error
        return true;
      }
    }

    // Ignore transient network or realtime errors that shouldn't crash the UI
    if (errorStrLower.contains('realtimesubscribeexception') ||
        errorStrLower.contains('channelerror') ||
        errorStrLower.contains('socketexception') ||
        errorStrLower.contains('handshakeexception') ||
        errorStrLower.contains('connection closed before full header') ||
        errorStrLower.contains('software caused connection abort') ||
        errorStrLower.contains('authretryablefetchexception') ||
        errorStrLower.contains('clientexception') ||
        errorStrLower.contains('timeoutexception') ||
        errorStrLower.contains('authapierror') ||
        errorStrLower.contains('authapiexception') ||
        errorStrLower.contains('refresh_token_not_found') ||
        errorStrLower.contains('xmlhttprequest error') ||
        errorStrLower.contains('invalid statuscode: 404') ||
        errorStrLower.contains('failed host lookup')) {
      material.debugPrint(
        '[GlobalError] Ignoring transient network/auth error: $error',
      );
      return true;
    }

    material.debugPrint('--- UNCAUGHT ERROR ---');
    material.debugPrint('Error: $error');

    // If it is a FormatException during startup, it is likely disk corruption
    if (error is FormatException) {
      _showErrorScreen(
        'Data Corruption Detected\\n\\nYour local session data was corrupted (likely due to a system crash). Please click "Repair App" to reset and log in again.',
        stack,
        isCorruption: true,
      );
    } else {
      _showErrorScreen(
        error,
        stack,
        title: AppInitializer.isInitialized
            ? 'Unexpected Error'
            : 'Failed to Initialize',
      );
    }

    // Also log to Sentry
    Sentry.captureException(error, stackTrace: stack);
    return true; // Return true to indicate the error was handled
  };

  // Capture log messages to debug throttled issues
  const int wrapWidth = 100;
  material.debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;

    // Ignore frequent layout/render noise in debug console
    if (message.contains('Sentry') ||
        message.contains('Firebase') ||
        message.contains('Supabase') ||
        message.contains('[PQAura]') ||
        message.contains('[Signal]') ||
        message.contains('[MainApp]') ||
        message.contains('[CircleProvider]') ||
        message.contains('[CircleRemoteDatasource]') ||
        message.contains('[CanvasProvider]')) {
      if (kDebugMode) {
        debugPrintThrottled(message, wrapWidth: wrapWidth);
        return;
      }
    }

    if (message.contains('ERROR') ||
        message.contains('failed') ||
        message.contains('EXCEPTION') ||
        message.contains('UNCAUGHT')) {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
    }
  };

  // 4. Initialize Sentry and run the app
  await AppInitializer.runWithSentry(() async {
    try {
      await AppInitializer.loadEnv();
      await AppInitializer.initFirebase();

      // Initialize preferences early to check decoy mode status on splash screen
      try {
        await PrefsStorage.init();
      } catch (e) {
        material.debugPrint('Early PrefsStorage initialization failed: $e');
      }

      runApp(
        material.MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SplashScreen(
            onInitComplete: () async {
              try {
                final packageInfo = await PackageInfo.fromPlatform();
                AppConfig.appVersion = packageInfo.version;

                final services = await AppInitializer.initCore();

                runApp(
                  SentryWidget(
                    child: AppInitializer.buildProviderTree(
                      services: services,
                      child: const LifecycleManager(child: MyApp()),
                    ),
                  ),
                );
              } catch (e, stackTrace) {
                _showErrorScreen(e, stackTrace);
              }
            },
          ),
        ),
      );
    } catch (e, st) {
      material.debugPrint('Root initialization failed: $e');
      _showErrorScreen(e, st);
    }
  });
}

// Removed redundant _runAppInitialization

void _showErrorScreen(
  Object error,
  StackTrace stack, {
  bool isCorruption = false,
  String? title,
}) {
  runApp(
    material.MaterialApp(
      home: material.Scaffold(
        backgroundColor: const material.Color(0xFF080A0E),
        body: material.Center(
          child: material.Padding(
            padding: const material.EdgeInsets.all(32.0),
            child: material.Column(
              mainAxisAlignment: material.MainAxisAlignment.center,
              children: [
                const material.Icon(
                  material.Icons.warning_amber_rounded,
                  color: material.Colors.amber,
                  size: 64,
                ),
                const material.SizedBox(height: 24),
                material.Text(
                  title ??
                      (isCorruption
                          ? 'App Needs Repair'
                          : 'Failed to Initialize'),
                  style: const material.TextStyle(
                    color: material.Colors.white,
                    fontSize: 24,
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
                const material.SizedBox(height: 16),
                material.ConstrainedBox(
                  constraints: const material.BoxConstraints(maxHeight: 300),
                  child: material.SingleChildScrollView(
                    child: material.Text(
                      error.toString(),
                      style: material.TextStyle(
                        color: material.Colors.white.withValues(alpha: 0.7),
                      ),
                      textAlign: material.TextAlign.center,
                    ),
                  ),
                ),
                const material.SizedBox(height: 32),
                material.ElevatedButton(
                  onPressed: () async {
                    material.debugPrint('User requested app repair/reset');
                    try {
                      // Clear image cache
                      CachedNetworkImage.evictFromCache('');
                      DefaultCacheManager().emptyCache();
                    } catch (_) {}
                    try {
                      // Clear SharedPreferences cache
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                    } catch (_) {}
                    try {
                      // Clear Supabase session to force fresh auth
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {}
                    // Re-initialize the app from scratch
                    main();
                  },
                  child: material.Text(
                    isCorruption ? 'Repair & Reset App' : 'Try Again',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// callingMain: Lightweight entry point for incoming calls
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void callingMain() async {
  material.WidgetsFlutterBinding.ensureInitialized();

  // Try to load env but don't block
  await AppInitializer.loadEnv();

  // Minimal services for calling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    material.debugPrint('Firebase init failed in callingMain: $e');
  }

  // We fetch intent data using a dedicated method channel we defined in OasisCallActivity
  const channel = services.MethodChannel('oasis/call_intent');

  String callerName = 'Unknown';
  String callId = '';
  String callerAvatar = '';

  try {
    final data = await channel.invokeMapMethod<String, dynamic>(
      'getIncomingCallData',
    );
    if (data != null) {
      callerName = data['callerName'] ?? 'Unknown';
      callId = data['callId'] ?? '';
      callerAvatar = data['callerAvatar'] ?? '';
    }
  } catch (e) {
    material.debugPrint('Failed to get intent data: $e');
  }

  runApp(
    material.MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: IncomingCallOverlayScreen(
        callerName: callerName,
        callId: callId,
        callerAvatar: callerAvatar,
        channel: channel,
      ),
    ),
  );
}
