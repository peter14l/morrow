import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:oasis/features/wellness/presentation/providers/study_session_provider.dart';
import 'package:oasis/themes/app_colors.dart';

class ActiveStudySessionScreen extends StatelessWidget {
  const ActiveStudySessionScreen({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<StudySessionProvider>();
    final session = provider.currentSession;

    // Prevent popping back accidentally (using PopScope)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showAbandonDialog(context, provider);
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.primary.withValues(alpha: 0.08),
                colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Minimal header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: session?.isLockedIn == true
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              session?.isLockedIn == true
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              color: session?.isLockedIn == true
                                  ? Colors.red
                                  : Colors.teal,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              session?.isLockedIn == true
                                  ? 'LOCK-IN ACTIVE'
                                  : 'FLEXIBLE MODE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: session?.isLockedIn == true
                                    ? Colors.red
                                    : Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _showAbandonDialog(context, provider),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),

                // Giant interactive timer
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress dial
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: CircularProgressIndicator(
                          value: provider.progress,
                          strokeWidth: 6,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            session?.isLockedIn == true
                                ? Colors.redAccent
                                : colorScheme.primary,
                          ),
                        ),
                      ),
                      // Core details
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(provider.remainingSeconds),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ).animate(
                            onPlay: (controller) => controller.repeat(reverse: true),
                          ).shimmer(
                            duration: 2.seconds,
                            color: colorScheme.primaryContainer,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            session?.title ?? 'Study Session',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '+${provider.xpEarned} XP accumulated',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Subtitle instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      Text(
                        'Keep this screen open to focus.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (session?.isLockedIn == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Leaving this screen, locking the device, or opening other apps will trigger an automatic failure and deduct XP.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAbandonDialog(BuildContext context, StudySessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Focus?'),
        content: Text(
          provider.currentSession?.isLockedIn == true
              ? 'Abandoning this session early will deduct 25 XP due to lock-in policy.'
              : 'Are you sure you want to end this focus room early? you will lose accumulated XP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Focusing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              provider.abandonSession();
              Navigator.pop(context); // exit screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }
}
