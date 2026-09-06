import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show debugPrintThrottled;

import 'package:oasis/core/performance/power_manager.dart';
import 'package:oasis/services/screen_time_service.dart';
import 'package:oasis/services/energy_meter_service.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/providers/presence_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/storage/prefs_storage.dart';
import 'package:oasis/features/couples/data/home_checkin_repository.dart';
import 'package:oasis/services/home_checkin_service.dart';
import 'package:oasis/services/home_arrival_service.dart';
import 'package:oasis/widgets/verification_dialog.dart';
import 'package:flutter/services.dart' as services;
import 'package:oasis/features/wellness/presentation/providers/study_session_provider.dart';
import 'package:oasis/features/settings/presentation/providers/decoy_provider.dart';

class LifecycleManager extends StatefulWidget {
  final Widget child;
  const LifecycleManager({super.key, required this.child});

  @override
  State<LifecycleManager> createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager>
    with material.WidgetsBindingObserver {
  static const services.MethodChannel _memoryChannel =
      services.MethodChannel('oasis/memory');

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addObserver(this);
    _setupMemoryChannel();
    if (mounted) {
      context.read<ScreenTimeService>().startTracking();
    }
  }

  void _setupMemoryChannel() {
    _memoryChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTrimMemory') {
        final level = call.arguments as int? ?? 0;
        debugPrintThrottled(
          '[LifecycleManager] Native onTrimMemory received (level=$level). Purging image cache.',
        );
        material.PaintingBinding.instance.imageCache.clear();
        material.PaintingBinding.instance.imageCache.clearLiveImages();
      }
    });
  }

  @override
  void dispose() {
    material.WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    debugPrintThrottled(
      '[LifecycleManager] System didHaveMemoryPressure triggered. Purging image caches.',
    );
    material.PaintingBinding.instance.imageCache.clear();
    material.PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void didChangeAppLifecycleState(material.AppLifecycleState state) {
    if (!mounted) return;

    final screenTime = context.read<ScreenTimeService>();
    final energyMeter = context.read<EnergyMeterService>();
    final wellness = context.read<WellnessService>();
    final wellbeing = context.read<DigitalWellbeingService>();
    final ripples = context.read<RipplesProvider>();
    final presence = context.read<PresenceProvider>();
    final auth = context.read<AuthService>();
    final studySession = context.read<StudySessionProvider>();

    if (state == material.AppLifecycleState.paused ||
        state == material.AppLifecycleState.hidden ||
        state == material.AppLifecycleState.detached) {
      PowerManager.instance.setBackgrounded(true);
      screenTime.stopTracking();
      energyMeter.onPaused();
      wellness.onPaused();
      wellbeing.resetSession();
      ripples.onPaused();
      studySession.onPaused();

      // Clear in-memory decoded image caches when backgrounded
      material.PaintingBinding.instance.imageCache.clear();
      material.PaintingBinding.instance.imageCache.clearLiveImages();

      context.read<DecoyProvider>().lock();

      context.read<VaultService>().lockItemsWithInterval('app_close');

      final userId = auth.currentUser?.id;
      if (userId != null) {
        presence.updateUserPresence(userId, 'offline');
      }
      presence.pauseHeartbeat();
    } else if (state == material.AppLifecycleState.resumed) {
      PowerManager.instance.setBackgrounded(false);
      // Use a microtask to spread the resume load across frames
      Future.microtask(() {
        if (!mounted) return;

        screenTime.startTracking();
        energyMeter.onResumed();
        wellness.onResumed();
        ripples.onResumed();

        // Check home arrival on app resume
        _checkHomeArrival();

        final userId = auth.currentUser?.id;
        if (userId != null) {
          presence.updateUserPresence(userId, 'online');
        }
        presence.resumeHeartbeat();
      });
    }
  }

  void _checkHomeArrival() {
    // Initialize and check home arrival
    final homeArrivalService = HomeArrivalService();
    homeArrivalService.initialize();

    // Set up callback for home arrival notification
    homeArrivalService.onHomeArrived = () {
      // Check if there's a pending verification to avoid duplicate dialogs
      _handleHomeArrivalWithVerification();
    };

    // Check current state
    homeArrivalService.checkNow();
  }

  void _handleHomeArrivalWithVerification() async {
    // Get context safely
    final context = mounted ? this.context : null;
    if (context == null) return;

    try {
      // Initialize services
      final prefs = PrefsStorage();
      final repository = HomeCheckinRepository();
      final checkinService = HomeCheckinService(repository, prefs);

      // Check if there's already a pending verification
      final hasPending = await checkinService.hasPendingVerification();
      if (hasPending) {
        debugPrintThrottled('Verification already pending, skipping dialog');
        return;
      }

      // Mark that user arrived and verification is needed
      await checkinService.markHomeArrived();

      // Show verification dialog after a brief delay
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Show verification dialog
      await VerificationDialog.show(
        context,
        onConfirm: () async {
          // User confirmed "Yes, I'm home"
          await checkinService.checkIn();
          if (mounted) {
            material.ScaffoldMessenger.of(context).showSnackBar(
              const material.SnackBar(
                content: Text('❤️ Your partner has been notified!'),
                backgroundColor: material.Colors.green,
              ),
            );
          }
        },
        onDeny: () async {
          // User said "No, not yet"
          await checkinService.verifyCheckIn(wasAccurate: false);
          if (mounted) {
            material.ScaffoldMessenger.of(context).showSnackBar(
              const material.SnackBar(
                content: Text('⚠️ Your partner has been warned'),
                backgroundColor: material.Colors.orange,
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrintThrottled('Error in home arrival verification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
