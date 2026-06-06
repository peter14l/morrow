import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/features/settings/presentation/screens/storage_usage_screen.dart';
import 'package:oasis/screens/instagram_import_settings_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';

class DataSection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const DataSection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  @override
  Widget build(BuildContext context) {
    final userSettingsProvider = Provider.of<UserSettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    return SettingsGroup(
      index: index,
      children: [
        SettingsTile(
          icon: material.Icons.storage_outlined,
          title: 'Storage Usage',
          subtitle: 'Manage app storage',
          iconColor: material.Colors.amber,
          onTap: () => onNavigateToSubPage('Storage Usage', const StorageUsageScreen()),
        ),
        SettingsTile(
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
        SettingsTile(
          icon: material.Icons.import_export_outlined,
          title: 'Import from Instagram',
          subtitle: 'Migrate your posts and media',
          iconColor: material.Colors.pink,
          onTap: () => onNavigateToSubPage('Import from Instagram', const InstagramImportSettingsScreen()),
        ),
      ],
    );
  }
}
