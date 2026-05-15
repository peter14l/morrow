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
                      version: '1.1.9',
                      date: 'May 9, 2026',
                      features: [
                        'Post-Quantum Security (PQ-DR) - Integrated Rust-based Hybrid PQ-Aura E2EE and visual security indicators.',
                        'Liquid Glass Rendering - Experimental glassmorphism for headers and navigation bars.',
                        'Liquid FAB Cluster - Morphing interaction cluster for organic, fluid animations.',
                        'Experimental Feed Layouts - Added Spatial Glider, Focused Flow, and Living Canvas engines.',
                        'Circles V2 - Full profile resolution (Names/Avatars) and private community feeds.',
                        'Smart In-App Updater - Secure one-tap APK installation via FileProvider and system prompts.',
                        'WebRTC Calling V2 - Hardware-optimized rendering and advanced ICE candidate buffering.',
                      ],
                      fixes: [
                        'Hardened Row Level Security (RLS) and backend permissions.',
                        'Optimized media loading with CachedNetworkImage and parallel decryption.',
                        'Resolved GoRouter assertion errors for full-screen transitions.',
                        'Unified secure storage for multi-account isolation.',
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
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
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
