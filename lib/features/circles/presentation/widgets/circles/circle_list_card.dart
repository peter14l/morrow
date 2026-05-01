import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/domain/models/circles_models.dart';

import 'package:oasis/services/app_initializer.dart'; // For ThemeProvider
import 'package:provider/provider.dart';

class CircleListCard extends StatelessWidget {
  final CircleEntity circle;
  final VoidCallback onTap;
  final bool isDesktop;

  const CircleListCard({
    super.key,
    required this.circle,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    // Desktop layout: card with vertical stack
    if (isDesktop) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isM3E ? 28 : 20),
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji avatar centered
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: isM3E ? BorderRadius.circular(20) : null,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      circle.emoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
                const Spacer(),
                // Circle name
                Text(
                  circle.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                    letterSpacing: isM3E ? -0.5 : 0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Member count
                Row(
                  children: [
                    Icon(
                      FluentIcons.people_24_regular,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${circle.memberIds.length} member${circle.memberIds.length == 1 ? '' : 's'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile layout: horizontal row (original)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isM3E ? 28 : 20),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Emoji avatar ───────────────────────────────────────
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isM3E ? BorderRadius.circular(16) : null,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: Text(circle.emoji, style: const TextStyle(fontSize: 28)),
              ),

              const SizedBox(width: 14),

              // ── Info ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
                        letterSpacing: isM3E ? -0.5 : 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          FluentIcons.people_24_regular,
                          size: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${circle.memberIds.length} member${circle.memberIds.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                FluentIcons.chevron_right_24_regular,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
