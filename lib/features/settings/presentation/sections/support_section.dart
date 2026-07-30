import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/settings/presentation/screens/help_support_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

class SupportSection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const SupportSection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  Future<void> _launchEmail(String label, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isPro = authService.currentUser?.isPro == true;
    final prefix = isPro ? '[PRO] ' : '';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'oasis.officialsupport@gmail.com',
      query: 'subject=${Uri.encodeComponent('${prefix}Oasis App Feedback: $label')}',
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint('Could not launch email client: $e');
    }
  }

  void _showFeedbackDialog(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).useFluentUI;

    if (useFluent) {
      fluent.showDialog(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const fluent.Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              fluent.ListTile(
                leading: const material.Icon(
                  material.Icons.bug_report_outlined,
                  color: material.Colors.red,
                ),
                title: const fluent.Text('Report a Bug'),
                onPressed: () {
                  Navigator.pop(context);
                  _launchEmail('Bug Report', context);
                },
              ),
              fluent.ListTile(
                leading: const material.Icon(
                  material.Icons.lightbulb_outline,
                  color: material.Colors.amber,
                ),
                title: const fluent.Text('Suggest a Feature'),
                onPressed: () {
                  Navigator.pop(context);
                  _launchEmail('Feature Suggestion', context);
                },
              ),
            ],
          ),
          actions: [
            fluent.Button(
              child: const fluent.Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    context.showResponsiveSheet(
      backgroundColor: material.Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: material.Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: material.Text(
                    'Send Feedback',
                    style: material.Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                material.ListTile(
                  leading: const material.Icon(
                    material.Icons.bug_report_outlined,
                    color: material.Colors.red,
                  ),
                  title: const material.Text('Report a Bug'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchEmail('Bug Report', context);
                  },
                ),
                material.ListTile(
                  leading: const material.Icon(
                    material.Icons.lightbulb_outline,
                    color: material.Colors.amber,
                  ),
                  title: const material.Text('Suggest a Feature'),
                  onTap: () {
                    Navigator.pop(context);
                    _launchEmail('Feature Suggestion', context);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      index: index,
      children: [
        SettingsTile(
          icon: material.Icons.feedback_outlined,
          title: 'Send Feedback',
          subtitle: 'Report a bug or suggest a feature',
          iconColor: material.Colors.orange,
          onTap: () => _showFeedbackDialog(context),
        ),
        SettingsTile(
          icon: material.Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help with Oasis',
          iconColor: material.Colors.green,
          onTap: () => onNavigateToSubPage('Help & Support', const HelpSupportScreen()),
        ),
        SettingsTile(
          icon: material.Icons.system_update_outlined,
          title: 'App Updates',
          subtitle: 'Check for software updates',
          iconColor: material.Colors.blue,
          onTap: () => context.push('/settings/update'),
        ),
        SettingsTile(
          icon: material.Icons.info_outline,
          title: 'About Oasis',
          subtitle: 'Version 1.1.14',
          iconColor: material.Colors.grey,
          onTap: () => context.push('/settings/about'),
        ),
      ],
    );
  }
}
