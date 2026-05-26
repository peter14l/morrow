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
              _buildSettingsGroup(context, [
                _buildSettingsTile(
                  context,
                  icon: material.Icons.person_outline,
                  title: 'Account Details',
                  subtitle: 'Manage profile and account',
                  onTap: () => context.push('/settings/account'),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'General'),
              _buildGeneralSection(context, index: 0),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Privacy & Security'),
              _buildPrivacySection(context, index: 1),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Appearance'),
              _buildAppearanceSection(context, index: 2),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Data & Storage'),
              _buildDataSection(context, index: 3),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Accessibility'),
              _buildAccessibilitySection(context, index: 4),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Support & About'),
              _buildSupportSection(context, index: 5),
              const SizedBox(height: 24),
              _buildSignOutButton(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    return PopScope(child: layout);
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
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
              ),
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
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              material.Icon(
                material.Icons.account_circle_outlined,
                size: 64,
                color: material.Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              material.Text(
                'Account Management',
                style: material.Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const material.Text(
                'Manage your profile and account security in a dedicated view.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton.primary(
                onPressed: () => context.push('/settings/account'),
                icon: const material.Icon(material.Icons.open_in_new),
                text: 'Open Account Details',
              ),
            ],
          ),
        );
      case SettingsCategory.general:
        return _buildGeneralSection(context, index: 0);
      case SettingsCategory.privacy:
        return _buildPrivacySection(context, index: 1);
      case SettingsCategory.appearance:
        return _buildAppearanceSection(context, index: 2);
      case SettingsCategory.data:
        return _buildDataSection(context, index: 3);
      case SettingsCategory.accessibility:
        return _buildAccessibilitySection(context, index: 4);
      case SettingsCategory.support:
        return _buildSupportSection(context, index: 5);
    }
  }

  Widget _buildGeneralSection(BuildContext context, {int index = 0}) {
    return _buildSettingsGroup(context, index: index, [
      _buildSettingsTile(
        context,
        icon: material.Icons.spa_outlined,
        title: 'Wellness Center',
        subtitle: 'Mindful usage, sessions and limits',
        iconColor: material.Colors.green,
        onTap: () =>
            _navigateToSubPage('Wellness Center', const WellnessCenterScreen()),
      ),
    ]);
  }

  Widget _buildPrivacySection(BuildContext context, {int index = 0}) {
    final colorScheme = material.Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildSettingsGroup(context, index: index, [
          _buildSettingsTile(
            context,
            icon: material.Icons.shield_outlined,
            title: 'Vault',
            subtitle: 'Manage hidden content and security',
            iconColor: colorScheme.primary,
            onTap: () =>
                _navigateToSubPage('Vault', const VaultSettingsScreen()),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.lock_outline,
            title: 'Encryption',
            subtitle: 'Manage End-to-End Encryption keys',
            iconColor: material.Colors.purple,
            onTap: () =>
                _navigateToSubPage('Encryption', const EncryptionSetupScreen()),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.lock_outlined,
            title: 'Account Privacy',
            subtitle: 'Control who can see your content',
            iconColor: material.Colors.green,
            onTap: () => _navigateToSubPage(
              'Account Privacy',
              const AccountPrivacyScreen(),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.block_outlined,
            title: 'Blocked Accounts',
            subtitle: 'Manage blocked users',
            iconColor: material.Colors.red,
            onTap: () => _navigateToSubPage(
              'Blocked Accounts',
              const BlockedUsersScreen(),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.security_outlined,
            title: 'Two-Factor Authentication',
            subtitle: 'Add extra security',
            iconColor: material.Colors.indigo,
            onTap: () => _navigateToSubPage(
              'Two-Factor Auth',
              const TwoFactorAuthScreen(),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.favorite_border_outlined,
            title: 'Privacy Heartbeat',
            subtitle: 'View your data access logs',
            iconColor: material.Colors.red,
            onTap: () => _navigateToSubPage(
              'Privacy Heartbeat',
              const PrivacyHeartbeatScreen(),
            ),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.home_outlined,
            title: 'Home Location',
            subtitle: 'Set your home address for safe check-in',
            iconColor: material.Colors.blue,
            onTap: () => context.push('/settings/home-location'),
          ),
          _buildSettingsTile(
            context,
            icon: material.Icons.download_outlined,
            title: 'Download Your Data',
            subtitle: 'Request a copy of your data',
            iconColor: material.Colors.teal,
            onTap: () =>
                _navigateToSubPage('Download Data', const DownloadDataScreen()),
          ),
        ]),
        const SizedBox(height: 24),
        const PrivacyTransparencyCard(),
      ],
    );
  }

  static const List<String> _fonts = [
    'System',
    'Outfit',
    'Inter',
    'Comfortaa',
    'Lexend',
    'Times New Roman',
    'Arial',
    'Verdana',
    'Georgia',
    'Garamond',
    'Courier New',
    'Lucida Console',
    'Monaco',
    'Open Dyslexic',
    'Comic Sans',
    // 'Roboto Flex',
    // 'Plus Jakarta Sans',
    // 'Space Grotesk',
    // 'Syne',
    // 'Montserrat',
    // 'Lora',
    // 'Playfair Display',
    // 'Work Sans',
  ];

  Widget _buildAppearanceSection(BuildContext context, {int index = 0}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userSettingsProvider = Provider.of<UserSettingsProvider>(context);
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useFluent = themeProvider.useFluentUI;

    return _buildSettingsGroup(context, index: index, [
      _buildSettingsTile(
        context,
        icon: material.Icons.palette_outlined,
        title: 'Theme',
        subtitle: _getThemeModeName(themeProvider.themeMode),
        iconColor: material.Colors.blue,
        trailing: useFluent
            ? fluent.ComboBox<material.ThemeMode>(
                value: themeProvider.themeMode,
                items: const [
                  fluent.ComboBoxItem(
                    value: material.ThemeMode.system,
                    child: fluent.Text('System'),
                  ),
                  fluent.ComboBoxItem(
                    value: material.ThemeMode.light,
                    child: fluent.Text('Light'),
                  ),
                  fluent.ComboBoxItem(
                    value: material.ThemeMode.dark,
                    child: fluent.Text('Dark'),
                  ),
                ],
                onChanged: (mode) =>
                    mode != null ? themeProvider.setTheme(mode) : null,
              )
            : material.DropdownButton<material.ThemeMode>(
                value: themeProvider.themeMode,
                dropdownColor: colorScheme.surfaceContainerHigh,
                underline: const SizedBox(),
                onChanged: (mode) =>
                    mode != null ? themeProvider.setTheme(mode) : null,
                items: const [
                  material.DropdownMenuItem(
                    value: material.ThemeMode.system,
                    child: material.Text('System'),
                  ),
                  material.DropdownMenuItem(
                    value: material.ThemeMode.light,
                    child: material.Text('Light'),
                  ),
                  material.DropdownMenuItem(
                    value: material.ThemeMode.dark,
                    child: material.Text('Dark'),
                  ),
                ],
              ),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.font_download_outlined,
        title: 'App Font',
        subtitle: userSettingsProvider.fontFamily,
        iconColor: material.Colors.teal,
        trailing: useFluent
            ? fluent.ComboBox<String>(
                value: userSettingsProvider.fontFamily,
                onChanged: (font) => font != null
                    ? userSettingsProvider.setFontFamily(font)
                    : null,
                items: _fonts
                    .map(
                      (font) => fluent.ComboBoxItem(
                        value: font,
                        child: fluent.Text(
                          font,
                          style: TextStyle(
                            fontFamily: font == 'System' ? null : font,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              )
            : material.DropdownButton<String>(
                value: userSettingsProvider.fontFamily,
                dropdownColor: colorScheme.surfaceContainerHigh,
                underline: const SizedBox(),
                onChanged: (font) {
                  if (font != null) {
                    userSettingsProvider.setFontFamily(font);
                  }
                },
                items: _fonts.map((font) {
                  return material.DropdownMenuItem(
                    value: font,
                    child: material.Text(
                      font,
                      style: TextStyle(
                        fontFamily: font == 'System' ? null : font,
                      ),
                    ),
                  );
                }).toList(),
              ),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.rocket_launch_outlined,
        title: 'M3 Expressive',
        subtitle: 'Vibrant & high-contrast design.',
        iconColor: material.Colors.pink,
        trailing: useFluent
            ? fluent.ToggleSwitch(
                checked: themeProvider.isM3EEnabled,
                onChanged: (v) {
                  themeProvider.setM3EEnabled(v);
                },
              )
            : material.Switch(
                value: themeProvider.isM3EEnabled,
                onChanged: (v) {
                  themeProvider.setM3EEnabled(v);
                },
              ),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.blur_on_outlined,
        title: 'Transparency Effects',
        subtitle: 'Glassmorphism and blur effects.',
        iconColor: material.Colors.cyan,
        trailing: useFluent
            ? fluent.ToggleSwitch(
                checked: !themeProvider.isM3ETransparencyDisabled,
                onChanged: (v) => themeProvider.setM3ETransparencyDisabled(!v),
              )
            : material.Switch(
                value: !themeProvider.isM3ETransparencyDisabled,
                onChanged: (v) => themeProvider.setM3ETransparencyDisabled(!v),
              ),
      ),
      if (themeProvider.isM3ETransparencyDisabled && (kIsWeb || !Platform.isAndroid && !Platform.isIOS))
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: material.Text(
            'Note: Transparency is disabled on this platform for performance.',
            style: TextStyle(fontSize: 11, color: material.Colors.orange),
          ),
        ),
      if (themeProvider.isM3EEnabled)
        _buildSettingsTile(
          context,
          icon: material.Icons.color_lens_outlined,
          title: 'Dynamic Theme',
          subtitle: 'Use system colors (Material You).',
          iconColor: material.Colors.orange,
          trailing: useFluent
              ? fluent.ToggleSwitch(
                  checked: themeProvider.useMaterialYou,
                  onChanged: (v) => themeProvider.setMaterialYou(v),
                )
              : material.Switch(
                  value: themeProvider.useMaterialYou,
                  onChanged: (v) => themeProvider.setMaterialYou(v),
                ),
        ),
      if (themeProvider.isM3EEnabled && !themeProvider.useMaterialYou)
        _buildSettingsTile(
          context,
          icon: material.Icons.palette_outlined,
          title: 'Color Palette',
          subtitle: _getPaletteName(themeProvider.colorPalette),
          iconColor: _getPaletteColor(themeProvider.colorPalette),
          trailing: useFluent
              ? fluent.ComboBox<ColorPalette>(
                  value: themeProvider.colorPalette,
                  onChanged: (p) =>
                      p != null ? themeProvider.setColorPalette(p) : null,
                  items: ColorPalette.values
                      .map(
                        (p) => fluent.ComboBoxItem(
                          value: p,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _getPaletteColor(p),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              fluent.Text(_getPaletteName(p)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                )
              : material.DropdownButton<ColorPalette>(
                  value: themeProvider.colorPalette,
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  underline: const SizedBox(),
                  onChanged: (palette) {
                    if (palette != null) {
                      themeProvider.setColorPalette(palette);
                    }
                  },
                  items: ColorPalette.values.map((palette) {
                    return material.DropdownMenuItem(
                      value: palette,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _getPaletteColor(palette),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          material.Text(_getPaletteName(palette)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      // Liquid Glass Effect (cross-platform)
      const SizedBox(height: 24),
      _buildSectionHeader(context, 'Visual Effects'),
      _buildSettingsGroup(context, index: 11, [
        _buildSettingsTile(
          context,
          icon: material.Icons.auto_awesome_outlined,
          title: 'Liquid Glass',
          subtitle: _getLiquidGlassModeName(
            userSettingsProvider.liquidGlassMode,
          ),
          iconColor: material.Colors.purple,
          trailing: useFluent
              ? fluent.ComboBox<LiquidGlassMode>(
                  value: userSettingsProvider.liquidGlassMode,
                  onChanged: (mode) => mode != null
                      ? userSettingsProvider.setLiquidGlassMode(mode)
                      : null,
                  items: LiquidGlassMode.values
                      .map(
                        (mode) => fluent.ComboBoxItem(
                          value: mode,
                          child: fluent.Text(_getLiquidGlassModeName(mode)),
                        ),
                      )
                      .toList(),
                )
              : material.DropdownButton<LiquidGlassMode>(
                  value: userSettingsProvider.liquidGlassMode,
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  underline: const SizedBox(),
                  onChanged: (mode) {
                    if (mode != null) {
                      userSettingsProvider.setLiquidGlassMode(mode);
                    }
                  },
                  items: LiquidGlassMode.values.map((mode) {
                    return material.DropdownMenuItem(
                      value: mode,
                      child: material.Text(_getLiquidGlassModeName(mode)),
                    );
                  }).toList(),
                ),
        ),
        if (userSettingsProvider.liquidGlassMode != LiquidGlassMode.disabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: material.Text(
              userSettingsProvider.liquidGlassMode == LiquidGlassMode.real
                  ? 'Real liquid glass may affect battery life on mobile devices.'
                  : 'Fake glass uses less battery but has fewer visual effects.',
              style: material.TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ]),
      if (kIsWeb == false && Platform.isWindows) ...[
        const SizedBox(height: 24),
        _buildSectionHeader(context, 'Windows Effects'),
        _buildSettingsGroup(context, index: 10, [
          _buildSettingsTile(
            context,
            icon: FluentIcons.window_apps_24_regular,
            title: 'Window Transparency',
            subtitle: 'Enable Mica/Acrylic background effects.',
            iconColor: material.Colors.blue,
            trailing: useFluent
                ? fluent.ToggleSwitch(
                    checked: userSettingsProvider.micaEnabled,
                    onChanged: (v) => userSettingsProvider.setMicaEnabled(v),
                  )
                : material.Switch(
                    value: userSettingsProvider.micaEnabled,
                    onChanged: (v) => userSettingsProvider.setMicaEnabled(v),
                  ),
          ),
          if (userSettingsProvider.micaEnabled)
            _buildSettingsTile(
              context,
              icon: FluentIcons.blur_24_regular,
              title: 'Effect Type',
              subtitle: userSettingsProvider.windowEffect.toUpperCase(),
              iconColor: material.Colors.teal,
              trailing: useFluent
                  ? fluent.ComboBox<String>(
                      value: userSettingsProvider.windowEffect,
                      onChanged: (v) => v != null
                          ? userSettingsProvider.setWindowEffect(v)
                          : null,
                      items: const [
                        fluent.ComboBoxItem(
                          value: 'mica',
                          child: fluent.Text('Mica (Default)'),
                        ),
                        fluent.ComboBoxItem(
                          value: 'acrylic',
                          child: fluent.Text('Acrylic'),
                        ),
                      ],
                    )
                  : material.DropdownButton<String>(
                      value: userSettingsProvider.windowEffect,
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      underline: const SizedBox(),
                      onChanged: (v) => v != null
                          ? userSettingsProvider.setWindowEffect(v)
                          : null,
                      items: const [
                        material.DropdownMenuItem(
                          value: 'mica',
                          child: material.Text('Mica'),
                        ),
                        material.DropdownMenuItem(
                          value: 'acrylic',
                          child: material.Text('Acrylic'),
                        ),
                      ],
                    ),
            ),
        ]),
      ],
    ]);
  }

  Widget _buildDataSection(BuildContext context, {int index = 0}) {
    final userSettingsProvider = Provider.of<UserSettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    return _buildSettingsGroup(context, index: index, [
      _buildSettingsTile(
        context,
        icon: material.Icons.storage_outlined,
        title: 'Storage Usage',
        subtitle: 'Manage app storage',
        iconColor: material.Colors.amber,
        onTap: () =>
            _navigateToSubPage('Storage Usage', const StorageUsageScreen()),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.data_usage_outlined,
        title: 'Data Saver',
        subtitle: 'Reduce data usage',
        iconColor: material.Colors.cyan,
        trailing: useFluent
            ? fluent.ToggleSwitch(
                checked: userSettingsProvider.dataSaver,
                onChanged: (v) => userSettingsProvider.setDataSaver(v),
              )
            : material.Switch(
                value: userSettingsProvider.dataSaver,
                onChanged: (v) => userSettingsProvider.setDataSaver(v),
              ),
      ),
    ]);
  }

  Widget _buildAccessibilitySection(BuildContext context, {int index = 0}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    return _buildSettingsGroup(context, index: index, [
      _buildSettingsTile(
        context,
        icon: material.Icons.text_fields_outlined,
        title: 'Font Size',
        subtitle: 'Adjust text size',
        iconColor: material.Theme.of(context).colorScheme.primary,
        onTap: () => _navigateToSubPage('Font Size', const FontSizeScreen()),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.contrast_outlined,
        title: 'High Contrast',
        subtitle: 'Improve visibility',
        iconColor: material.Theme.of(context).colorScheme.tertiary,
        trailing: useFluent
            ? fluent.ToggleSwitch(
                checked: themeProvider.highContrast,
                onChanged: (v) => themeProvider.setHighContrast(v),
              )
            : material.Switch(
                value: themeProvider.highContrast,
                onChanged: (v) => themeProvider.setHighContrast(v),
              ),
      ),
    ]);
  }

  Widget _buildSupportSection(BuildContext context, {int index = 0}) {
    return _buildSettingsGroup(context, index: index, [
      _buildSettingsTile(
        context,
        icon: material.Icons.feedback_outlined,
        title: 'Send Feedback',
        subtitle: 'Report a bug or suggest a feature',
        iconColor: material.Colors.orange,
        onTap: () => _showFeedbackDialog(context),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.help_outline,
        title: 'Help & Support',
        subtitle: 'Get help with Oasis',
        iconColor: material.Colors.green,
        onTap: () =>
            _navigateToSubPage('Help & Support', const HelpSupportScreen()),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.system_update_outlined,
        title: 'App Updates',
        subtitle: 'Check for software updates',
        iconColor: material.Colors.blue,
        onTap: () => context.push('/settings/update'),
      ),
      _buildSettingsTile(
        context,
        icon: material.Icons.info_outline,
        title: 'About Oasis',
        subtitle: 'Version 1.1.1',
        iconColor: material.Colors.grey,
        onTap: () => context.push('/settings/about'),
      ),
    ]);
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
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context,
    List<Widget> children, {
    int index = 0,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return Column(children: children);
    }

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    BorderRadius borderRadius;
    if (isM3E) {
      switch (index % 3) {
        case 0:
          borderRadius = BorderRadius.circular(32);
          break;
        case 1:
          borderRadius = const BorderRadius.only(
            topLeft: Radius.circular(48),
            bottomRight: Radius.circular(48),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          );
          break;
        case 2:
          borderRadius = BorderRadius.circular(16);
          break;
        default:
          borderRadius = BorderRadius.circular(24);
      }
    } else {
      borderRadius = BorderRadius.circular(16);
    }

    final bgColor = isM3E
        ? (disableTransparency
              ? (index % 2 == 0
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surfaceContainerLow)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3))
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isM3E ? 0.3 : 0.5,
          ),
          width: isM3E ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          children: List.generate(children.length * 2 - 1, (idx) {
            if (idx.isOdd) {
              return material.Divider(
                height: 1,
                indent: 56,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              );
            }
            return children[idx ~/ 2];
          }),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required material.IconData icon,
    required String title,
    String? subtitle,
    material.Color? iconColor,
    material.Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return fluent.ListTile(
        leading: material.Icon(icon, color: iconColor, size: 20),
        title: fluent.Text(title),
        subtitle: subtitle != null ? fluent.Text(subtitle) : null,
        trailing: trailing,
        onPressed: onTap,
      );
    }

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isM3E = themeProvider.isM3EEnabled;

    return material.ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: EdgeInsets.all(isM3E ? 10 : 8),
        decoration: BoxDecoration(
          color: (iconColor ?? colorScheme.primary).withValues(
            alpha: isM3E ? 0.15 : 0.1,
          ),
          borderRadius: BorderRadius.circular(isM3E ? 16 : 10),
        ),
        child: material.Icon(
          icon,
          color: iconColor ?? colorScheme.primary,
          size: isM3E ? 22 : 24,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: isM3E ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? material.Icon(
                  material.Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                )
              : null),
      onTap: onTap,
    );
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

    material.showModalBottomSheet(
      context: context,
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
                  child: Text(
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

  Future<void> _launchEmail(String label, BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isPro = authService.currentUser?.isPro == true;
    final prefix = isPro ? '[PRO] ' : '';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'oasis.officialsupport@gmail.com',
      query:
          'subject=${Uri.encodeComponent('${prefix}Oasis App Feedback: $label')}',
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint('Could not launch email client: $e');
    }
  }

  String _getThemeModeName(material.ThemeMode mode) {
    switch (mode) {
      case material.ThemeMode.system:
        return 'System';
      case material.ThemeMode.light:
        return 'Light';
      case material.ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getPaletteName(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return 'None (Default)';
      case ColorPalette.emerald:
        return 'Emerald';
      case ColorPalette.ocean:
        return 'Ocean';
      case ColorPalette.sunset:
        return 'Sunset';
      case ColorPalette.lavender:
        return 'Lavender';
      case ColorPalette.rose:
        return 'Rose';
      case ColorPalette.teal:
        return 'Teal';
      case ColorPalette.aurora:
        return 'Aurora (Pro)';
      case ColorPalette.wildfire:
        return 'Wildfire (Pro)';
      case ColorPalette.neonDreams:
        return 'Neon Dreams (Pro)';
      case ColorPalette.oceanDepths:
        return 'Ocean Depths (Pro)';
    }
  }

  material.Color _getPaletteColor(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return material.Colors.grey;
      case ColorPalette.emerald:
        return const material.Color(0xFF1C6758);
      case ColorPalette.ocean:
        return const material.Color(0xFF0D47A1);
      case ColorPalette.sunset:
        return const material.Color(0xFFE65100);
      case ColorPalette.lavender:
        return const material.Color(0xFF7E57C2);
      case ColorPalette.rose:
        return const material.Color(0xFFC2185B);
      case ColorPalette.teal:
        return const material.Color(0xFF00796B);
      case ColorPalette.aurora:
        return const material.Color(0xFF00D9FF);
      case ColorPalette.wildfire:
        return const material.Color(0xFFFF6B35);
      case ColorPalette.neonDreams:
        return const material.Color(0xFFB967FF);
      case ColorPalette.oceanDepths:
        return const material.Color(0xFF0066FF);
    }
  }

  String _getLiquidGlassModeName(LiquidGlassMode mode) {
    switch (mode) {
      case LiquidGlassMode.disabled:
        return 'Disabled';
      case LiquidGlassMode.fake:
        return 'Fake (Low battery)';
      case LiquidGlassMode.real:
        return 'Real (Full effect)';
    }
  }
}
