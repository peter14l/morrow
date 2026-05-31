import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/themes/theme_provider.dart';
// For ThemeProvider
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:oasis/features/settings/presentation/screens/subscription_screen.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        Provider.of<ProfileProvider>(
          context,
          listen: false,
        ).loadCurrentProfile(authService.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: MaxWidthContainer(
            maxWidth: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(context),
                const SizedBox(height: 32),
                // _buildSubscriptionSection(context),
                // const SizedBox(height: 32),
                _buildSecuritySection(context),
                const SizedBox(height: 32),
                _buildDangerZone(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.currentProfile;
    final user = authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profileProvider.isLoading && profile == null)
          const Center(child: CircularProgressIndicator())
        else if (profile != null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: isM3E
                  ? LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.tertiaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(isM3E ? 32 : 20),
              border: isM3E
                  ? Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: isM3E
                          ? const EdgeInsets.all(3)
                          : EdgeInsets.zero,
                      decoration: isM3E
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.onPrimaryContainer,
                                width: 2,
                              ),
                            )
                          : null,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: profile.avatarUrl != null
                            ? CachedNetworkImageProvider(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                profile.username.substring(0, 1).toUpperCase(),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: isM3E ? FontWeight.w600 : null,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    profile.username,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ),
                              /* if (profile.isPro)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ), */
                            ],
                          ),
                          if (profile.fullName != null)
                            Text(
                              profile.fullName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      color: colorScheme.onPrimaryContainer,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        '${profile.postsCount}',
                        'Posts',
                        colorScheme.onPrimaryContainer,
                      ),
                      _buildDivider(colorScheme.onPrimaryContainer),
                      _buildStatItem(
                        context,
                        '${profile.followersCount}',
                        'Followers',
                        colorScheme.onPrimaryContainer,
                      ),
                      _buildDivider(colorScheme.onPrimaryContainer),
                      _buildStatItem(
                        context,
                        '${profile.followingCount}',
                        'Following',
                        colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubscriptionSection(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile = profileProvider.currentProfile;

    if (profile == null) return const SizedBox.shrink();

    return profile.isPro
        ? _buildProMemberTile(context)
        : _buildPremiumTile(context);
  }

  Widget _buildProMemberTile(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isM3E ? 28 : 16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Member',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Thank you for upgrading to Oasis Pro. You are a Pro member now.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse(AppConfig.getWebUrl('/profile'))),
                      icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                      label: const Text('Web Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _handleCancelSubscription,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Subscription'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTile(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isM3E
              ? [Colors.amber.shade600, Colors.deepOrange.shade700]
              : [Colors.amber.shade700, Colors.orange.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isM3E ? 28 : 16),
        border: isM3E
            ? Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: ListTile(
        leading: const Icon(
          Icons.workspace_premium,
          color: Colors.white,
          size: 32,
        ),
        title: const Text(
          'Oasis Pro',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Unlock premium features & go ad-free',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        ),
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Security',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(isM3E ? 28 : 16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: ListTile(
            leading: Icon(
              Icons.password,
              color: theme.colorScheme.onSurface,
            ),
            title: Text(
              'Change Password',
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Update your password'),
            trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface),
            onTap: () => context.push('/settings/change-password'),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Danger Zone',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(isM3E ? 28 : 16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Permanently remove your account and data'),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => context.push('/settings/delete-account'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your Pro features will remain active until the end of your current billing period. Automatic renewal will be disabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Pro'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing cancellation...')),
      );

      try {
        final supabase = SupabaseService().client;
        final response = await supabase.functions.invoke(
          'razorpay-cancel-subscription',
        );

        if (response.status != 200) {
          throw Exception(
            response.data['error'] ?? 'Failed to cancel subscription',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription cancelled. Auto-renewal disabled.'),
              backgroundColor: Colors.orange,
            ),
          );

          final authService = Provider.of<AuthService>(context, listen: false);
          if (authService.currentUser != null) {
            Provider.of<ProfileProvider>(
              context,
              listen: false,
            ).loadCurrentProfile(authService.currentUser!.id);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 30, width: 1, color: color.withValues(alpha: 0.3));
  }
}
