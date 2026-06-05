import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post_mood.dart';
import 'package:oasis/widgets/pulse_picker_sheet.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

class UnifiedVibePickerSheet extends StatefulWidget {
  final String? currentMood;
  final String? currentMoodEmoji;
  final PulseStatus? currentPulse;
  final String? currentPulseText;
  final Function(String? mood, String? emoji) onMoodSelect;
  final Function(PulseStatus status, String? text) onPulseSelect;
  final VoidCallback onClearMood;
  final VoidCallback onClearPulse;

  const UnifiedVibePickerSheet({
    super.key,
    this.currentMood,
    this.currentMoodEmoji,
    this.currentPulse,
    this.currentPulseText,
    required this.onMoodSelect,
    required this.onPulseSelect,
    required this.onClearMood,
    required this.onClearPulse,
  });

  @override
  State<UnifiedVibePickerSheet> createState() => _UnifiedVibePickerSheetState();
}

class _UnifiedVibePickerSheetState extends State<UnifiedVibePickerSheet> {
  final TextEditingController _pulseTextController = TextEditingController();
  PulseStatus? _selectedPulse;

  @override
  void initState() {
    super.initState();
    _selectedPulse = widget.currentPulse;
    if (widget.currentPulseText != null) {
      _pulseTextController.text = widget.currentPulseText!;
    }
  }

  @override
  void dispose() {
    _pulseTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final isSolid = ContextX(context).shouldUseSolidBackground;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        (keyboardPadding > 0 ? keyboardPadding + 16 : bottomPadding + 24),
      ),
      decoration: BoxDecoration(
        color: isSolid
            ? (isDark ? const Color(0xFF1A1D24) : Colors.white)
            : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Text(
              'Your Daily Pulse',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Update your vibe and what you\'re up to.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Mood Section
            _buildSectionHeader(
              context,
              'Current Vibe',
              widget.currentMood != null,
              widget.onClearMood,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: PostMood.values.map((mood) {
                  final isSelected = widget.currentMood == mood.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(mood.emoji),
                          const SizedBox(width: 4),
                          Text(mood.label),
                        ],
                      ),
                      onSelected: (selected) {
                        HapticUtils.selectionClick();
                        widget.onMoodSelect(mood.name, mood.emoji);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 32),

            // Pulse Section
            _buildSectionHeader(
              context,
              'Check-in Pulse',
              widget.currentPulse != null,
              widget.onClearPulse,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PulseStatus.values.map((status) {
                final isSelected = _selectedPulse == status;
                return ChoiceChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(status.emoji),
                      const SizedBox(width: 8),
                      Text(status.label),
                    ],
                  ),
                  onSelected: (selected) {
                    HapticUtils.selectionClick();
                    setState(() => _selectedPulse = selected ? status : null);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),

            if (_selectedPulse == PulseStatus.withFriend ||
                _selectedPulse == PulseStatus.atLocation) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _pulseTextController,
                decoration: InputDecoration(
                  hintText: _selectedPulse == PulseStatus.withFriend
                      ? 'Who are you with?'
                      : 'Where are you?',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],

            const SizedBox(height: 32),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_selectedPulse != null) {
                    String? customText;
                    if (_selectedPulse == PulseStatus.withFriend ||
                        _selectedPulse == PulseStatus.atLocation) {
                      customText = _pulseTextController.text.trim();
                      if (customText.isEmpty) {
                        return; // Prevent setting empty custom pulse
                      }
                    }
                    widget.onPulseSelect(_selectedPulse, customText);
                  }
                  Navigator.pop(context);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Confirm Status'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool hasValue,
    VoidCallback onClear,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        const Spacer(),
        if (hasValue)
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showUnifiedVibePicker({
  required BuildContext context,
  String? currentMood,
  String? currentMoodEmoji,
  PulseStatus? currentPulse,
  String? currentPulseText,
  required Function(String? mood, String? emoji) onMoodSelect,
  required Function(PulseStatus status, String? text) onPulseSelect,
  required VoidCallback onClearMood,
  required VoidCallback onClearPulse,
}) {
  return context.showResponsiveSheet(
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UnifiedVibePickerSheet(
      currentMood: currentMood,
      currentMoodEmoji: currentMoodEmoji,
      currentPulse: currentPulse,
      currentPulseText: currentPulseText,
      onMoodSelect: onMoodSelect,
      onPulseSelect: onPulseSelect,
      onClearMood: onClearMood,
      onClearPulse: onClearPulse,
    ),
  );
}
