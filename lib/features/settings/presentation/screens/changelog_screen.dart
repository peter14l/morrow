import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Changelog',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              centerTitle: true,
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildVersionCard(
                      context,
                      version: '1.1.1',
                      date: 'May 1, 2026',
                      features: [
                        'Major Overhaul of Circles - Transitioned to a restricted, feed-centric group conversation system.',
                        'Private Circle Feeds - Only circle members can view and interact with circle posts.',
                        'Dedicated Post FAB - Create posts directly within your specific circles.',
                        'Member-Only Security - Shared circle posts are now protected by a privacy overlay for non-members.',
                        'Curated Circles - Authors can now explicitly select members from their following list when creating a circle.',
                        'Real-time Interactions - Like and comment buttons are now always visible for circle posts with instant updates.',
                      ],
                      fixes: [
                        'Removed legacy Group Task and Commitment logic for a cleaner, conversation-focused experience.',
                        'Improved Row Level Security (RLS) for circle-specific content.',
                        'Separated circle content from the main application feed.',
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 24),
                    _buildVersionCard(
                      context,
                      version: '1.0.0+1',
                      date: 'April 30, 2026',
                      features: [
                        'Initial Release - Welcome to Oasis!',
                        'End-to-End Encrypted Messaging (Whisper Mode)',
                        'Privacy-Centric Communities (Circles)',
                        'Live Audio Hangouts (Spaces)',
                        'Short-form Content Interaction (Ripples)',
                        'Digital Wellbeing Engine',
                        'Multi-platform Support (Android, iOS, Windows)',
                      ],
                      fixes: [],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(
    BuildContext context, {
    required String version,
    required String date,
    required List<String> features,
    required List<String> fixes,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
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
                'v$version',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'NEW FEATURES',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((f) => _buildBulletPoint(context, f)),
          ],
          if (fixes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'FIXES & IMPROVEMENTS',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ...fixes.map((f) => _buildBulletPoint(context, f)),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
