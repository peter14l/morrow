import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:oasis/routes/app_router.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

class CallNavigator extends StatefulWidget {
  final Widget child;
  const CallNavigator({super.key, required this.child});

  @override
  State<CallNavigator> createState() => _CallNavigatorState();
}

class _CallNavigatorState extends State<CallNavigator> {
  String? _lastPushedCallId;

  @override
  Widget build(BuildContext context) {
    final hasActiveCall = context.select<CallProvider, bool>((p) => p.hasActiveCall);
    final hasIncomingCall = context.select<CallProvider, bool>((p) => p.hasIncomingCall);
    final isMinimized = context.select<CallProvider, bool>((p) => p.state.isMinimized);
    final activeCallId = context.select<CallProvider, String?>((p) => p.activeCall?.id);
    final incomingCallId = context.select<CallProvider, String?>((p) => p.incomingCall?.id);
    final userSettings = context.watch<UserSettingsProvider>();

    final hasCall = hasActiveCall || hasIncomingCall;
    final callId = activeCallId ?? incomingCallId;

    if (!hasCall) {
      _lastPushedCallId = null;
    }

    if (hasCall && callId != null && _lastPushedCallId != callId) {
      String location = '';
      try {
        location =
            GoRouter.of(context).routeInformationProvider.value.uri.path;
      } catch (e) {
        location =
            AppRouter.router.routerDelegate.currentConfiguration.uri.path;
      }

      final onCallScreen = location.startsWith('/call');
      final onAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/splash' ||
          location == '/onboarding';

      if (!onCallScreen && !isMinimized && !onAuthRoute) {
        _lastPushedCallId = callId;
        material.WidgetsBinding.instance.addPostFrameCallback((_) {
          final navContext =
              AppRouter.router.configuration.navigatorKey.currentContext;
          if (navContext != null) {
            GoRouter.of(
              navContext,
            ).pushNamed('active_call', pathParameters: {'callId': callId});
          } else {
            AppRouter.router.pushNamed(
              'active_call',
              pathParameters: {'callId': callId},
            );
          }
        });
      }
    }

    final bool canUseTransparency =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS);
    final bool useTransparency = userSettings.micaEnabled && canUseTransparency;

    final theme = material.Theme.of(context);
    final isDark = theme.brightness == material.Brightness.dark;

    return Container(
      color: useTransparency
          ? (isDark
                ? material.Colors.black.withValues(alpha: 0.0)
                : material.Colors.white.withValues(alpha: 0.0))
          : theme.scaffoldBackgroundColor,
      child: widget.child,
    );
  }
}
