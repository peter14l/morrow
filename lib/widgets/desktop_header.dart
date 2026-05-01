import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/responsive_layout.dart';

class DesktopHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final double? maxWidth;

  const DesktopHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.onBack,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    final Widget headerContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(FluentIcons.chevron_left_24_regular),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isM3E ? 12 : 16),
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.w800,
                    letterSpacing: isM3E ? -1.5 : -0.5,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 20),
            ...actions!
                .expand((widget) => [widget, const SizedBox(width: 12)])
                .toList()
              ..removeLast(),
          ],
        ],
      ),
    );

    return ClipRRect(
      child:
          disableTransparency
              ? Container(
                width: double.infinity,
                color: theme.scaffoldBackgroundColor,
                child: MaxWidthContainer(
                  maxWidth: maxWidth ?? ResponsiveLayout.maxContentWidth,
                  child: headerContent,
                ),
              )
              : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: double.infinity,
                  color: theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                  child: MaxWidthContainer(
                    maxWidth: maxWidth ?? ResponsiveLayout.maxContentWidth,
                    child: headerContent,
                  ),
                ),
              ),
    );
  }
}
