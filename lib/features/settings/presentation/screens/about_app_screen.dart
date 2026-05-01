import 'package:flutter/material.dart';
import 'package:oasis/core/constants/app_strings.dart';
import 'package:oasis/routes/route_paths.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.flutter_dash_rounded,
                          size: 80,
                          color: colorScheme.primary,
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ).animate().fadeIn(delay: 400.ms).moveY(begin: 10, end: 0),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Version 1.1.1',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 32),
                  _buildCard(
                    context,
                    child: Column(
                      children: [
                        Text(
                          AppStrings.appTagline,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildInfoTile(
                          context,
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          onTap: () => context.push(RoutePaths.termsOfService),
                        ),
                        _buildInfoTile(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () => context.push(RoutePaths.privacyPolicy),
                        ),
                        _buildInfoTile(
                          context,
                          icon: Icons.history_rounded,
                          title: 'Changelog',
                          onTap: () => context.push(RoutePaths.changelog),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildCard(
                    context,
                    title: 'Connect with Us',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialIcon(
                          context,
                          icon: Icons.language_rounded,
                          label: 'Website',
                          url: 'https://oasisapp.com',
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.alternate_email_rounded,
                          label: 'Twitter',
                          url: 'https://twitter.com/oasisapp',
                        ),
                        _buildSocialIcon(
                          context,
                          icon: Icons.camera_alt_outlined,
                          label: 'Instagram',
                          url: 'https://instagram.com/oasisapp',
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 48),
                  Text(
                    'Made with ❤️ by Oasis Team',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ).animate().fadeIn(delay: 1200.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {String? title, required Widget child}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Attempt to use surfaceContainerLow if available (M3), else fallback to surfaceVariant or surface
    final cardColor = colorScheme.surfaceContainerLow;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSocialIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.8)),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
