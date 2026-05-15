import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/wellness_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/profile/data/datasources/profile_remote_datasource.dart';
import 'dart:ui';

class WellnessStatsScreen extends StatelessWidget {
  final String? userId;

  const WellnessStatsScreen({super.key, this.userId});

  bool get isOwnProfile {
    final currentUserId = AuthService().currentUser?.id;
    return userId == null || userId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wellness = Provider.of<WellnessService>(context);
    final user = AuthService().currentUser;
    final xp = user?.userMetadata?['xp'] ?? 0;

    // For non-own profile, we'll fetch their data
    return FutureBuilder<Map<String, dynamic>?>(
      future: isOwnProfile
          ? Future.value(null)
          : ProfileRemoteDatasource().getProfile(userId!),
      builder: (context, snapshot) {
        final targetUser = snapshot.data;
        final displayName = targetUser?['username'] ?? 'User';
        final displayXp = targetUser?['xp'] ?? 0;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              isOwnProfile
                  ? 'Wellness Achievements'
                  : "$displayName's Wellness",
            ),
            centerTitle: true,
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
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.1),
                  colorScheme.surface,
                ],
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 80,
                16,
                100,
              ),
              children: [
                // XP Summary Card
                _buildXPCard(
                  theme,
                  isOwnProfile ? wellness.totalXp : displayXp,
                ),
                const SizedBox(height: 24),

                // Focus Session Stats
                _buildSectionTitle(
                  theme,
                  isOwnProfile
                      ? 'Focus Mode Stats'
                      : "$displayName's Focus Stats",
                ),
                const SizedBox(height: 12),
                _buildStatGrid(theme, wellness),
                const SizedBox(height: 32),

                // Badges Section
                _buildSectionTitle(
                  theme,
                  isOwnProfile ? 'Your Badges' : "$displayName's Badges",
                ),
                const SizedBox(height: 16),
                if (wellness.achievements.isEmpty)
                  _buildEmptyState(
                    theme,
                    isOwnProfile
                        ? 'No badges earned yet. Complete a focus session to earn your first one!'
                        : 'This user hasn\'t earned any badges yet.',
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: wellness.achievements.length,
                    itemBuilder: (context, index) {
                      final achievement = wellness.achievements[index];
                      return _buildBadgeItem(theme, achievement);
                    },
                  ),

                const SizedBox(height: 32),

                // Rules/Rewards Card - only show for own profile
                if (isOwnProfile) _buildRulesCard(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildXPCard(ThemeData theme, dynamic xp) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            'Total Experience',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            '$xp XP',
            style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildStatGrid(ThemeData theme, WellnessService wellness) {
    final completed = wellness.achievements
        .where((a) => a.id.startsWith('focus_'))
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            theme,
            'Sessions Done',
            completed.toString(),
            Icons.timer,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            theme,
            'Points Gained',
            '${completed * 50}',
            Icons.add_circle_outline,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(ThemeData theme, WellnessAchievement achievement) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(achievement.icon, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 8),
        Text(
          achievement.name,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          style: BorderStyle.none,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Focus Rules',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            Icons.check_circle,
            'Complete 30 mins to earn 50 XP',
            theme,
          ),
          const SizedBox(height: 8),
          _buildRuleRow(Icons.cancel, 'Stop early and lose 35 XP', theme),
          const SizedBox(height: 8),
          _buildRuleRow(
            Icons.block,
            'Home and Search are blocked during Focus',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.secondary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
