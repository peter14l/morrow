import 'package:flutter/material.dart';
import 'package:oasis/models/chat_theme.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

/// Widget for selecting chat theme
class ChatThemeSelector extends StatelessWidget {
  final ChatThemePreset? selectedPreset;
  final ValueChanged<ChatThemePreset> onPresetSelected;
  final VoidCallback? onCustomTheme;

  const ChatThemeSelector({
    super.key,
    this.selectedPreset,
    required this.onPresetSelected,
    this.onCustomTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chat Theme',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a theme for this conversation',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: ChatThemePreset.values.length,
            itemBuilder: (context, index) {
              final preset = ChatThemePreset.values[index];
              final isSelected = selectedPreset == preset;

              return GestureDetector(
                onTap: () {
                  HapticUtils.selectionClick();
                  onPresetSelected(preset);
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: preset.backgroundColor ?? colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.2),
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: preset == ChatThemePreset.defaultTheme
                          ? Icon(
                              Icons.brightness_auto,
                              color: colorScheme.onSurface,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (onCustomTheme != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCustomTheme,
                icon: const Icon(Icons.palette),
                label: const Text('Custom Colors'),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Preview widget showing how messages look with selected theme
class ChatThemePreview extends StatelessWidget {
  final ChatTheme theme;

  const ChatThemePreview({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final defaultBg = Theme.of(context).colorScheme.surface;
    final defaultBubble = Theme.of(context).colorScheme.primaryContainer;
    final defaultText = Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.backgroundColor ?? defaultBg,
        image: theme.backgroundImageUrl != null
            ? DecorationImage(
                image: NetworkImage(theme.backgroundImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Received message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (theme.bubbleColor ?? defaultBubble).withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Hey! How are you?',
              style: TextStyle(color: theme.textColor ?? defaultText),
            ),
          ),
          const Spacer(),
          // Sent message
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.bubbleColor ?? defaultBubble,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "I'm doing great! 🎉",
                style: TextStyle(color: theme.textColor ?? defaultText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
