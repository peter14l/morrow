import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:oasis/features/wellness/presentation/screens/wellness_center_screen.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';

class GeneralSection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const GeneralSection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      index: index,
      children: [
        SettingsTile(
          icon: material.Icons.spa_outlined,
          title: 'Wellness Center',
          subtitle: 'Mindful usage, sessions and limits',
          iconColor: material.Colors.green,
          onTap: () => onNavigateToSubPage('Wellness Center', const WellnessCenterScreen()),
        ),
      ],
    );
  }
}
