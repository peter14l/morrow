import 'package:flutter/material.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import 'package:oasis/widgets/pulse_picker_sheet.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ProfileStatusCard extends StatelessWidget {
  final UserProfileEntity profile;
  final bool isOwnProfile;
  final VoidCallback? onPulseTap;
  final VoidCallback? onCozyTap;
  final VoidCallback? onFortressTap;

  const ProfileStatusCard({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    this.onPulseTap,
    this.onCozyTap,
    this.onFortressTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusRow(
            context,
            icon:
                profile.moodEmoji ??
                (profile.pulseStatus != null
                    ? _getPulseEmoji(profile.pulseStatus!)
                    : '✨'),
            title: profile.pulseText ?? profile.currentMood ?? 'Set your vibe',
            subtitle: 'Daily Pulse',
            onTap: onPulseTap,
            isActive: profile.hasActivePulse || profile.currentMood != null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: _buildCompactStatus(
                  context,
                  icon: FluentIcons.shapes_24_regular,
                  label: profile.hasActiveCozyStatus
                      ? profile.cozyStatus!
                      : 'Cozy Mode',
                  isActive: profile.hasActiveCozyStatus,
                  onTap: onCozyTap,
                  activeColor: Colors.orange.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactStatus(
                  context,
                  icon: profile.fortressMode
                      ? FluentIcons.shield_lock_24_filled
                      : FluentIcons.shield_24_regular,
                  label: profile.fortressMode ? 'Fortress On' : 'Fortress',
                  isActive: profile.fortressMode,
                  onTap: onFortressTap,
                  activeColor: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (isOwnProfile)
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface,
            ),
        ],
      ),
    );
  }

  Widget _buildCompactStatus(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onTap,
    required Color activeColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.2)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? activeColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                  color: isActive
                      ? activeColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPulseEmoji(String status) {
    try {
      return PulseStatus.values.firstWhere((s) => s.name == status).emoji;
    } catch (_) {
      return '⚪';
    }
  }
}
