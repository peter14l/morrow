import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post_mood.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

/// Widget for selecting mood when creating a post
class MoodSelector extends StatelessWidget {
  final PostMood? selectedMood;
  final ValueChanged<PostMood?> onMoodSelected;
  final bool showLabel;

  const MoodSelector({
    super.key,
    this.selectedMood,
    required this.onMoodSelected,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.mood, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'How are you feeling?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (selectedMood != null)
                  TextButton(
                    onPressed: () => onMoodSelected(null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PostMood.values.map((mood) {
            final isSelected = selectedMood == mood;
            return GestureDetector(
              onTap: () {
                HapticUtils.selectionClick();
                onMoodSelected(isSelected ? null : mood);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood.emoji,
                      style: TextStyle(fontSize: isSelected ? 18 : 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mood.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Compact mood chip for displaying on posts
class MoodChip extends StatelessWidget {
  final PostMood mood;
  final bool showLabel;

  const MoodChip({super.key, required this.mood, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mood.emoji, style: const TextStyle(fontSize: 12)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              mood.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Feed filter for mood-aware browsing
class MoodFeedFilter extends StatelessWidget {
  final bool isMatchMoodEnabled;
  final PostMood? currentMood;
  final ValueChanged<bool> onMatchMoodChanged;
  final ValueChanged<PostMood?> onMoodChanged;

  const MoodFeedFilter({
    super.key,
    required this.isMatchMoodEnabled,
    this.currentMood,
    required this.onMatchMoodChanged,
    required this.onMoodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Match My Mood',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: isMatchMoodEnabled,
                onChanged: (value) {
                  HapticUtils.selectionClick();
                  onMatchMoodChanged(value);
                },
              ),
            ],
          ),
          if (isMatchMoodEnabled) ...[
            const SizedBox(height: 16),
            Text(
              "I'm feeling...",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PostMood.values.map((mood) {
                  final isSelected = currentMood == mood;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${mood.emoji} ${mood.label}'),
                      selected: isSelected,
                      onSelected: (_) {
                        HapticUtils.selectionClick();
                        onMoodChanged(isSelected ? null : mood);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
