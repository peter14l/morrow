import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:provider/provider.dart';
import 'package:oasis/services/digital_wellbeing_service.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:oasis/features/wellness/presentation/screens/study_sessions_hub_screen.dart';

class WellnessCenterScreen extends StatelessWidget {
  const WellnessCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wellbeing = context.watch<DigitalWellbeingService>();
    final wellness = context.watch<WellnessService>();
    final profileProvider = context.watch<ProfileProvider>();
    final isPro = profileProvider.currentProfile?.isPro ?? false;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Wellness Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 70,
            20,
            40,
          ),
          children: [
            _buildSessionCard(context, wellbeing),
            const SizedBox(height: 24),
            _buildFocusSessionCard(context, wellness),
            const SizedBox(height: 24),
            _buildLockoutSection(context, wellbeing, isPro),
            const SizedBox(height: 24),
            _buildQuickActions(context, wellness),
            const SizedBox(height: 24),
            _buildConsolidatedFeatures(context, wellness),
          ],
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    DigitalWellbeingService wellbeing,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Current Session',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatItem(
                context,
                'Feed',
                '${wellbeing.feedMinutes}m',
                Icons.art_track_rounded,
                Colors.blue,
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                context,
                'Ripples',
                '${wellbeing.ripplesMinutes}m',
                Icons.blur_on_rounded,
                Colors.purple,
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _buildStatItem(
                context,
                'Total',
                '${wellbeing.totalMinutes}m',
                Icons.timer_rounded,
                colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSessionCard(
    BuildContext context,
    WellnessService wellness,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = wellness.isFocusSessionActive;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isActive ? 0.5 : 0.1),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.timer_rounded : Icons.timer_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Focus Session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isActive) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: wellness.focusProgress,
                minHeight: 8,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Goal: ${wellness.focusTargetMinutes} minutes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => wellness.stopFocusSession(completed: false),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('End Early'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Lock yourself into deep focus. Browsing distracting features will penalize your XP.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [25, 45, 60, 90].map((mins) {
                return InkWell(
                  onTap: () => wellness.startFocusSession(mins),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$mins',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'min',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutSection(
    BuildContext context,
    DigitalWellbeingService wellbeing,
    bool isPro,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final threshold = wellbeing.lockoutThresholdMinutes;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Intentional Limit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isPro)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRO FEATURE',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The app will lock your Feed and Ripples after this many minutes of use.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '$threshold',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'minutes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isPro)
            Slider(
              value: threshold.toDouble().clamp(60, 180),
              min: 60,
              max: 180,
              divisions: 12,
              onChanged: (value) {
                wellbeing.setLockoutThreshold(value.toInt());
              },
            )
          else
            GestureDetector(
              onTapDown: (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Limit changing feature is available only for Pro users.',
                    ),
                  ),
                );
              },
              child: Slider(
                value: 60,
                min: 60,
                max: 180,
                divisions: 12,
                onChanged: (_) {}, // No-op for free users
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WellnessService wellness) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = wellness.zenModeEnabled;
    final color = isActive ? Colors.teal : Colors.teal.withValues(alpha: 0.5);

    String subtitle = 'Silence everything';
    if (isActive) {
      final minutes = wellness.zenRemainingSeconds ~/ 60;
      final seconds = wellness.zenRemainingSeconds % 60;
      subtitle =
          'Active - ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              wellness.setZenModeEnabled(!wellness.zenModeEnabled);
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive
                      ? color.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.spa_rounded, color: color, size: 28),
                        const SizedBox(height: 16),
                        const Text(
                          'Zen Mode',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: wellness.zenProgress,
                            strokeWidth: 4,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.2),
                          ),
                          Icon(
                            Icons.self_improvement_rounded,
                            color: color,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsolidatedFeatures(
    BuildContext context,
    WellnessService wellness,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildListTile(
            context,
            'Study Sessions',
            'Focus with your community',
            Icons.menu_book_rounded,
            Colors.teal,
            () => Navigator.push(
              context,
              material.MaterialPageRoute(
                builder: (context) => const StudySessionsHubScreen(),
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 70,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _buildListTile(
            context,
            'Digital Badges',
            'Your wellbeing achievements',
            Icons.verified_rounded,
            Colors.amber,
            () => context.push('/wellness-stats'),
          ),
          Divider(
            height: 1,
            indent: 70,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _buildListTile(
            context,
            'Sleep Wind-down',
            wellness.isWindDownActive
                ? 'Wind-down active'
                : 'Prepare for a restful night',
            Icons.nights_stay_rounded,
            wellness.isWindDownActive
                ? Colors.indigo
                : Colors.indigo.withValues(alpha: 0.5),
            () => wellness.setWindDownEnabled(!wellness.windDownEnabled),
          ),
          Divider(
            height: 1,
            indent: 70,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_enabled_rounded,
                color: Colors.green,
                size: 22,
              ),
            ),
            title: const Text(
              'Allow Calls in Zen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Incoming calls will still ring',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: wellness.allowCallsDuringZen,
            onChanged: (v) => wellness.setAllowCallsDuringZen(v),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.outline,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
