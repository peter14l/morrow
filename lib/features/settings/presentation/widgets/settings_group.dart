import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final int index;

  const SettingsGroup({
    super.key,
    required this.children,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return Column(children: children);
    }

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderRadius = BorderRadius.circular(12);
    final bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          children: List.generate(children.length * 2 - 1, (idx) {
            if (idx.isOdd) {
              return material.Divider(
                height: 1,
                indent: 48,
                color: colorScheme.outlineVariant.withValues(alpha: 0.1),
              );
            }
            return children[idx ~/ 2];
          }),
        ),
      ),
    );
  }
}
