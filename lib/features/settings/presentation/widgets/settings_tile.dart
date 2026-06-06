import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';

class SettingsTile extends StatelessWidget {
  final material.IconData icon;
  final String title;
  final String? subtitle;
  final material.Color? iconColor;
  final material.Color? textColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.textColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    if (useFluent) {
      return fluent.ListTile(
        leading: material.Icon(icon, color: iconColor, size: 20),
        title: fluent.Text(title),
        subtitle: subtitle != null ? fluent.Text(subtitle!) : null,
        trailing: trailing,
        onPressed: onTap,
      );
    }

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    return material.ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: material.Icon(
        icon,
        color: iconColor ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        size: 22,
      ),
      title: material.Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: textColor,
        ),
      ),
      subtitle: subtitle != null
          ? material.Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null
              ? material.Icon(
                  material.Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 20,
                )
              : null),
      onTap: onTap,
    );
  }
}
