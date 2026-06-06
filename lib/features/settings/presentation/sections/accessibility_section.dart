import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/settings/presentation/screens/font_size_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';

class AccessibilitySection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const AccessibilitySection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    return SettingsGroup(
      index: index,
      children: [
        SettingsTile(
          icon: material.Icons.text_fields_outlined,
          title: 'Font Size',
          subtitle: 'Adjust text size',
          iconColor: material.Theme.of(context).colorScheme.primary,
          onTap: () => onNavigateToSubPage('Font Size', const FontSizeScreen()),
        ),
        SettingsTile(
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
      ],
    );
  }
}
