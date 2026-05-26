import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

import 'package:oasis/themes/theme_provider.dart';
// For ThemeProvider
import 'package:provider/provider.dart';

class CanvasListTile extends StatelessWidget {
  final OasisCanvas canvas;
  final VoidCallback onTap;
  final bool isDesktop;

  const CanvasListTile({
    super.key,
    required this.canvas,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    final coverHex = canvas.coverColor.replaceAll('#', '');
    final coverColor = Color(int.parse('FF$coverHex', radix: 16));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isM3E ? 28 : 20),
          gradient: disableTransparency
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    coverColor.withValues(alpha: 0.5),
                    coverColor.withValues(alpha: 0.2),
                  ],
                ),
          color: disableTransparency ? coverColor.withValues(alpha: 0.8) : null,
          border: Border.all(
            color: coverColor.withValues(alpha: isM3E ? 0.5 : 0.35),
            width: isM3E ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: isM3E ? BorderRadius.circular(12) : null,
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                ),
                child: const Icon(
                  FluentIcons.whiteboard_24_regular,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Spacer(),
              Text(
                canvas.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                  letterSpacing: isM3E ? -0.5 : 0,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${canvas.memberIds.length} member${canvas.memberIds.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: isM3E ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
