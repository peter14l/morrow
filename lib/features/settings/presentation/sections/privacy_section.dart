import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/settings/presentation/screens/vault_settings_screen.dart';
import 'package:oasis/features/settings/presentation/screens/account_privacy_screen.dart';
import 'package:oasis/features/settings/presentation/screens/privacy_heartbeat_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/privacy_transparency_card.dart';
import 'package:oasis/features/settings/presentation/screens/two_factor_auth_screen.dart';
import 'package:oasis/features/settings/presentation/screens/download_data_screen.dart';
import 'package:oasis/features/messages/presentation/screens/encryption_setup_screen.dart';
import 'package:oasis/screens/moderation/moderation_screens.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';
import 'package:oasis/features/settings/presentation/screens/stealth_settings_screen.dart';

class PrivacySection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const PrivacySection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = material.Theme.of(context).colorScheme;
    return Column(
      children: [
        SettingsGroup(
          index: index,
          children: [
            SettingsTile(
              icon: material.Icons.shield_outlined,
              title: 'Vault',
              subtitle: 'Manage hidden content and security',
              iconColor: colorScheme.primary,
              onTap: () => onNavigateToSubPage('Vault', const VaultSettingsScreen()),
            ),
            SettingsTile(
              icon: material.Icons.lock_outline,
              title: 'Encryption',
              subtitle: 'Manage End-to-End Encryption keys',
              iconColor: material.Colors.purple,
              onTap: () => onNavigateToSubPage('Encryption', const EncryptionSetupScreen()),
            ),
            SettingsTile(
              icon: material.Icons.lock_outlined,
              title: 'Account Privacy',
              subtitle: 'Control who can see your content',
              iconColor: material.Colors.green,
              onTap: () => onNavigateToSubPage('Account Privacy', const AccountPrivacyScreen()),
            ),
            SettingsTile(
              icon: material.Icons.block_outlined,
              title: 'Blocked Accounts',
              subtitle: 'Manage blocked users',
              iconColor: material.Colors.red,
              onTap: () => onNavigateToSubPage('Blocked Accounts', const BlockedUsersScreen()),
            ),
            SettingsTile(
              icon: material.Icons.security_outlined,
              title: 'Two-Factor Authentication',
              subtitle: 'Add extra security',
              iconColor: material.Colors.indigo,
              onTap: () => onNavigateToSubPage('Two-Factor Auth', const TwoFactorAuthScreen()),
            ),
            SettingsTile(
              icon: material.Icons.favorite_border_outlined,
              title: 'Privacy Heartbeat',
              subtitle: 'View your data access logs',
              iconColor: material.Colors.red,
              onTap: () => onNavigateToSubPage('Privacy Heartbeat', const PrivacyHeartbeatScreen()),
            ),
            SettingsTile(
              icon: material.Icons.home_outlined,
              title: 'Home Location',
              subtitle: 'Set your home address for safe check-in',
              iconColor: material.Colors.blue,
              onTap: () => context.push('/settings/home-location'),
            ),
            SettingsTile(
              icon: material.Icons.visibility_off_outlined,
              title: 'Stealth Mode',
              subtitle: 'Disguise Oasis as a calendar app',
              iconColor: material.Colors.blueGrey,
              onTap: () => onNavigateToSubPage('Stealth Mode', const StealthSettingsScreen()),
            ),
            SettingsTile(
              icon: material.Icons.download_outlined,
              title: 'Download Your Data',
              subtitle: 'Request a copy of your data',
              iconColor: material.Colors.teal,
              onTap: () => onNavigateToSubPage('Download Data', const DownloadDataScreen()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const PrivacyTransparencyCard(),
      ],
    );
  }
}
