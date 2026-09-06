import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/settings/presentation/screens/vault_settings_screen.dart';
import 'package:oasis/features/wellness/presentation/screens/wellness_center_screen.dart';
import 'package:oasis/features/settings/presentation/screens/account_privacy_screen.dart';
import 'package:oasis/screens/instagram_import_settings_screen.dart';
import 'package:oasis/features/settings/presentation/screens/privacy_heartbeat_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/privacy_transparency_card.dart';
import 'package:oasis/features/settings/presentation/screens/two_factor_auth_screen.dart';
import 'package:oasis/features/settings/presentation/screens/download_data_screen.dart';
import 'package:oasis/features/settings/presentation/screens/storage_usage_screen.dart';
import 'package:oasis/features/settings/presentation/screens/font_size_screen.dart';
import 'package:oasis/features/settings/presentation/screens/help_support_screen.dart';
import 'package:oasis/features/messages/presentation/screens/encryption_setup_screen.dart';
import 'package:oasis/screens/moderation/moderation_screens.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/providers/conversation_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:oasis/providers/community_provider.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_provider.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/widgets/desktop_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/widgets/adaptive/adaptive_dialog.dart';
import 'package:oasis/widgets/app_button.dart';
import 'dart:ui';
import 'package:oasis/services/instagram_migration_service.dart';
import 'package:oasis/features/settings/presentation/sections/general_section.dart';
import 'package:oasis/features/settings/presentation/sections/privacy_section.dart';
import 'package:oasis/features/settings/presentation/sections/appearance_section.dart';
import 'package:oasis/features/settings/presentation/sections/data_section.dart';
import 'package:oasis/features/settings/presentation/sections/accessibility_section.dart';
import 'package:oasis/features/settings/presentation/sections/support_section.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';
import 'package:oasis/features/profile/presentation/screens/account_management_screen.dart';

enum SettingsCategory {
  account,
  general,
  privacy,
  appearance,
  data,
  accessibility,
  support,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsCategory _selectedCategory = SettingsCategory.account;
  Widget? _selectedSubPage;
  String? _subPageTitle;

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
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final useFluent = themeProvider.useFluentUI;

    final userSettingsProvider = Provider.of<UserSettingsProvider>(context);
    final Widget layout;
    if (useFluent) {
      layout = _buildFluentSettings(
        context,
        themeProvider,
        userSettingsProvider,
        colorScheme,
      );
    } else if (isDesktop) {
      layout = _buildMaterialDesktopSettings(
        context,
        themeProvider,
        colorScheme,
        isM3E,
      );
    } else {
      // Mobile Layout
      layout = MaxWidthContainer(
        maxWidth: ResponsiveLayout.maxFormWidth,
        child: material.Scaffold(
          backgroundColor: material.Colors.transparent,
          appBar: material.AppBar(
            backgroundColor: material.Colors.transparent,
            title: const material.Text('Settings'),
            centerTitle: true,
            elevation: 0,
          ),
          body: material.ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSupportEmailNote(),
              _buildInstagramMigrationProgress(),
              SettingsGroup(children: [
                SettingsTile(
                  icon: material.Icons.person_outline,
                  title: 'Account Details',
                  subtitle: 'Manage profile and account',
                  onTap: () => _navigateToSubPage('Account Management', const AccountManagementScreen()),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'General'),
              GeneralSection(index: 0, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Privacy & Security'),
              PrivacySection(index: 1, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Appearance'),
              AppearanceSection(index: 2, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Data & Storage'),
              DataSection(index: 3, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Accessibility'),
              AccessibilitySection(index: 4, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Support & About'),
              SupportSection(index: 5, onNavigateToSubPage: _navigateToSubPage),
              const SizedBox(height: 24),
              _buildSignOutButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    final bool canPop = _selectedSubPage == null;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedSubPage != null) {
          setState(() {
            _selectedSubPage = null;
            _subPageTitle = null;
          });
        }
      },
      child: layout,
    );
  }

  Widget _buildFluentSettings(
    BuildContext context,
    ThemeProvider themeProvider,
    UserSettingsProvider userSettingsProvider,
    material.ColorScheme colorScheme,
  ) {
    final bodyContent = _selectedSubPage != null
        ? _selectedSubPage!
        : fluent.ScaffoldPage.scrollable(
            header: fluent.PageHeader(
              title: Text(_getCategoryTitle(_selectedCategory)),
            ),
            children: [_buildSelectedCategoryContent(context)],
          );

    return fluent.NavigationView(
      key: ValueKey(
        'settings_fluent_${userSettingsProvider.micaEnabled}_${userSettingsProvider.windowEffect}',
      ),
      pane: fluent.NavigationPane(
        selected: _selectedCategory.index,
        onChanged: (index) {
          setState(() {
            _selectedCategory = SettingsCategory.values[index];
            _selectedSubPage = null;
            _subPageTitle = null;
          });
        },
        displayMode: fluent.PaneDisplayMode.auto,
        header: fluent.Container(
          height: material.kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Settings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              fluent.IconButton(
                icon: const Icon(FluentIcons.dismiss_24_regular, size: 18),
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
        items: [
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.person_24_regular),
            title: const Text('Account'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.timer_24_regular),
            title: const Text('General'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.shield_24_regular),
            title: const Text('Privacy & Security'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.paint_brush_24_regular),
            title: const Text('Appearance'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.storage_24_regular),
            title: const Text('Data & Storage'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.text_font_24_regular),
            title: const Text('Accessibility'),
            body: bodyContent,
          ),
          fluent.PaneItem(
            icon: const material.Icon(FluentIcons.question_circle_24_regular),
            title: const Text('Support & About'),
            body: bodyContent,
          ),
        ],
        footerItems: [
          fluent.PaneItemSeparator(),
          fluent.PaneItemAction(
            icon: const material.Icon(
              FluentIcons.sign_out_24_regular,
              color: material.Colors.red,
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: material.Colors.red),
            ),
            onTap: _handleSignOut,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialDesktopSettings(
    BuildContext context,
    ThemeProvider themeProvider,
    material.ColorScheme colorScheme,
    bool isM3E,
  ) {
    final Widget settingsContent = Row(
      children: [
        // Sidebar
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(
              alpha: 0.2,
            ),
            border: Border(
              right: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesktopHeader(
                title: 'Settings',
                showBackButton: true,
                onBack: () {
                  if (_selectedSubPage != null) {
                    setState(() {
                      _selectedSubPage = null;
                      _subPageTitle = null;
                    });
                  } else if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/profile');
                  }
                },
              ),
              Expanded(
                child: material.ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildSidebarItem(
                      icon: FluentIcons.person_24_regular,
                      selectedIcon: FluentIcons.person_24_filled,
                      label: 'Account',
                      category: SettingsCategory.account,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.timer_24_regular,
                      selectedIcon: FluentIcons.timer_24_filled,
                      label: 'General',
                      category: SettingsCategory.general,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.shield_24_regular,
                      selectedIcon: FluentIcons.shield_24_filled,
                      label: 'Privacy & Security',
                      category: SettingsCategory.privacy,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.paint_brush_24_regular,
                      selectedIcon: FluentIcons.paint_brush_24_filled,
                      label: 'Appearance',
                      category: SettingsCategory.appearance,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.storage_24_regular,
                      selectedIcon: FluentIcons.storage_24_filled,
                      label: 'Data & Storage',
                      category: SettingsCategory.data,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.text_font_24_regular,
                      selectedIcon: FluentIcons.text_font_24_filled,
                      label: 'Accessibility',
                      category: SettingsCategory.accessibility,
                    ),
                    _buildSidebarItem(
                      icon: FluentIcons.question_circle_24_regular,
                      selectedIcon:
                          FluentIcons.question_circle_24_filled,
                      label: 'Support & About',
                      category: SettingsCategory.support,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildSignOutButton(context, isDesktop: true),
              ),
            ],
          ),
        ),
        // Content Area
        Expanded(
          child: Column(
            children: [
              DesktopHeader(
                title: _selectedSubPage != null
                    ? _subPageTitle ?? ''
                    : _getCategoryTitle(_selectedCategory),
                showBackButton: _selectedSubPage != null,
                onBack: () => setState(() {
                  _selectedSubPage = null;
                  _subPageTitle = null;
                }),
              ),
              const material.Divider(height: 1),
              Expanded(
                child: _selectedSubPage != null
                    ? _selectedSubPage!
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 32,
                        ),
                        child: MaxWidthContainer(
                          maxWidth: 1000,
                          child: _buildSelectedCategoryContent(
                            context,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );

    return material.Scaffold(
      backgroundColor: material.Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(isM3E ? 32 : 24),
            border: Border.all(
              color: material.Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isM3E ? 32 : 24),
            child: kIsWeb
                ? settingsContent
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: settingsContent,
                  ),
          ),
        ),
      ),
    );
  }

  bool _showSupportEmailNote = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSupportEmailNoteState();
  }

  Future<void> _loadSupportEmailNoteState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showSupportEmailNote =
            !(prefs.getBool('support_email_note_dismissed') ?? false);
      });
    }
  }

  Future<void> _dismissSupportEmailNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('support_email_note_dismissed', true);
    if (mounted) {
      setState(() {
        _showSupportEmailNote = false;
      });
    }
  }

  Widget _buildInstagramMigrationProgress() {
    final migrationService = InstagramMigrationService();
    return ListenableBuilder(
      listenable: migrationService,
      builder: (context, _) {
        if (!migrationService.isMigrating && migrationService.progress == 0.0) {
          return const SizedBox.shrink();
        }

        final theme = material.Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const material.Icon(
                    material.Icons.sync,
                    color: material.Colors.pinkAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: material.Text(
                      'Instagram Sync Status',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              material.Text(
                migrationService.currentStatus,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (migrationService.isMigrating) ...[
                const SizedBox(height: 12),
                material.LinearProgressIndicator(
                  value: migrationService.progress,
                  backgroundColor: colorScheme.surfaceContainer,
                  valueColor: material.AlwaysStoppedAnimation<material.Color>(colorScheme.primary),
                ),
                const SizedBox(height: 8),
                material.Text(
                  '${(migrationService.progress * 100).toStringAsFixed(0)}% Completed (${migrationService.processedPosts}/${migrationService.totalPosts})',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportEmailNote() {
    if (!_showSupportEmailNote) return const SizedBox.shrink();

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              material.Icon(
                material.Icons.info_outline,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: material.Text(
                  'Important Note',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              material.IconButton(
                icon: const material.Icon(material.Icons.close, size: 20),
                onPressed: _dismissSupportEmailNote,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const material.Text(
            'All feedback, bugs, and reports will be sent to oasis.officialsupport@gmail.com. This is subject to change when our official domain is available.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _navigateToSubPage(String title, Widget page) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    if (isDesktop) {
      setState(() {
        _selectedSubPage = page;
        _subPageTitle = title;
      });
    } else {
      Navigator.of(
        context,
      ).push(material.MaterialPageRoute(builder: (context) => page));
    }
  }

  Widget _buildSidebarItem({
    required material.IconData icon,
    required material.IconData selectedIcon,
    required String label,
    required SettingsCategory category,
  }) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedCategory == category;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: material.Material(
        color: material.Colors.transparent,
        child: material.InkWell(
          onTap: () => setState(() {
            _selectedCategory = category;
            _selectedSubPage = null;
            _subPageTitle = null;
          }),
          borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : material.Colors.transparent,
              borderRadius: BorderRadius.circular(isM3E ? 16 : 12),
              border: isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                material.Icon(
                  isSelected ? selectedIcon : icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                material.Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryTitle(SettingsCategory category) {
    switch (category) {
      case SettingsCategory.account:
        return 'Account';
      case SettingsCategory.general:
        return 'General';
      case SettingsCategory.privacy:
        return 'Privacy & Security';
      case SettingsCategory.appearance:
        return 'Appearance';
      case SettingsCategory.data:
        return 'Data & Storage';
      case SettingsCategory.accessibility:
        return 'Accessibility';
      case SettingsCategory.support:
        return 'Support & About';
    }
  }

  Widget _buildSelectedCategoryContent(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).useFluentUI;

    switch (_selectedCategory) {
      case SettingsCategory.account:
        return const AccountManagementScreen();
      case SettingsCategory.general:
        return GeneralSection(index: 0, onNavigateToSubPage: _navigateToSubPage);
      case SettingsCategory.privacy:
        return PrivacySection(index: 1, onNavigateToSubPage: _navigateToSubPage);
      case SettingsCategory.appearance:
        return AppearanceSection(index: 2, onNavigateToSubPage: _navigateToSubPage);
      case SettingsCategory.data:
        return DataSection(index: 3, onNavigateToSubPage: _navigateToSubPage);
      case SettingsCategory.accessibility:
        return AccessibilitySection(index: 4, onNavigateToSubPage: _navigateToSubPage);
      case SettingsCategory.support:
        return SupportSection(index: 5, onNavigateToSubPage: _navigateToSubPage);
    }
  }


  Widget _buildSignOutButton(BuildContext context, {bool isDesktop = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return fluent.Button(
        onPressed: _handleSignOut,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            material.Icon(
              FluentIcons.sign_out_24_regular,
              color: material.Colors.red,
              size: 20,
            ),
            SizedBox(width: 8),
            fluent.Text(
              'Sign Out',
              style: TextStyle(color: material.Colors.red),
            ),
          ],
        ),
      );
    }

    final button = material.ListTile(
      leading: const material.Icon(
        material.Icons.logout,
        color: material.Colors.red,
      ),
      title: const material.Text(
        'Sign Out',
        style: TextStyle(
          color: material.Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: _handleSignOut,
    );

    if (isDesktop) {
      return material.Material(
        color: material.Colors.transparent,
        child: button,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: material.Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: material.Colors.red.withValues(alpha: 0.2)),
      ),
      child: button,
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await AdaptiveDialog.showConfirm(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      _clearProviders(context);
      await authService.signOut(context: context);
      if (mounted) {
        if (authService.currentUser == null) {
          context.go('/login');
        }
      }
    }
  }

  void _clearProviders(BuildContext context) {
    context.read<ConversationProvider>().clear();
    context.read<ProfileProvider>().clear();
    context.read<FeedProvider>().clear();
    context.read<CommunityProvider>().clear();
    context.read<NotificationProvider>().init(null);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = material.Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }

  void _navigateToSubPage(String title, Widget page) {
    if (ResponsiveLayout.isDesktop(context) || Provider.of<ThemeProvider>(context, listen: false).useFluentUI) {
      setState(() {
        _selectedSubPage = page;
        _subPageTitle = title;
      });
    } else {
      Navigator.of(context).push(
        material.MaterialPageRoute(
          builder: (context) => page,
        ),
      );
    }
  }
}
