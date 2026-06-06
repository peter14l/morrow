import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:oasis/routes/app_router.dart';
import 'package:oasis/features/calling/presentation/providers/call_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

class CallNavigator extends StatelessWidget {
  final Widget child;
  const CallNavigator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final userSettings = context.watch<UserSettingsProvider>();

    final hasActiveCall =
        callProvider.hasActiveCall || callProvider.hasIncomingCall;

    if (hasActiveCall) {
      String location = '';
      try {
        location =
            GoRouter.of(context).routeInformationProvider.value.uri.path;
      } catch (e) {
        location =
            AppRouter.router.routerDelegate.currentConfiguration.uri.path;
      }

      final onCallScreen = location.startsWith('/call');

      if (!onCallScreen && !callProvider.state.isMinimized) {
        material.WidgetsBinding.instance.addPostFrameCallback((_) {
          final activeCallId = callProvider.activeCall?.id;
          final incomingCallId = callProvider.incomingCall?.id;
          final callId = activeCallId ?? incomingCallId;

          if (callId != null) {
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
          }
        });
      }
    }

    final bool canUseTransparency =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS);
    final bool useTransparency = userSettings.micaEnabled && canUseTransparency;

    final isDark =
        material.Theme.of(context).brightness == material.Brightness.dark;

    return Container(
      color: useTransparency
          ? (isDark
                ? material.Colors.black.withValues(alpha: 0.0)
                : material.Colors.white.withValues(alpha: 0.0))
          : (isDark
                ? const material.Color(0xFF080A0E)
                : const material.Color(0xFFF8F9FA)),
      child: child,
    );
  }
}
