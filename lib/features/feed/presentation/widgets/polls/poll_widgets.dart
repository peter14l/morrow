import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart'
    show
        Colors,
        Theme,
        ColorScheme,
        Icons,
        IconButton,
        TextButton,
        FilledButton,
        OutlinedButton,
        SingleChildScrollView,
        Column,
        Row,
        Padding,
        SizedBox,
        Widget,
        Stack,
        Positioned,
        ClipRRect,
        BackdropFilter,
        GestureDetector,
        Icon,
        Text,
        TextStyle,
        FontWeight,
        VisualDensity,
        MouseRegion,
        AnimatedScale,
        ScrollController,
        TextEditingController,
        DraggableScrollableSheet,
        ListView,
        TextField,
        InputDecoration,
        OutlineInputBorder,
        InputBorder,
        TextCapitalization,
        MediaQuery,
        ScaffoldMessenger,
        SnackBar,
        Offset,
        Navigator,
        VoidCallback,
        State,
        StatefulWidget,
        BuildContext,
        List,
        CrossAxisAlignment,
        MainAxisSize,
        MainAxisAlignment,
        Wrap,
        ChoiceChip,
        SwitchListTile,
        ListTile,
        TimeOfDay,
        showDatePicker,
        showTimePicker,
        StatelessWidget,
        Expanded,
        AnimatedContainer,
        Spacer,
        EdgeInsets,
        BorderRadius,
        BoxDecoration,
        Container,
        Border,
        TextAlign,
        IconData;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';

/// Widget for creating enhanced polls
class PollCreator extends StatefulWidget {
  final Function(EnhancedPoll) onPollCreated;
  final VoidCallback? onCancel;

  const PollCreator({super.key, required this.onPollCreated, this.onCancel});

  @override
  State<PollCreator> createState() => _PollCreatorState();
}

class _PollCreatorState extends State<PollCreator> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  PollType _selectedType = PollType.single;
  bool _isAnonymous = false;
  DateTime? _endsAt;
  int? _correctAnswerIndex; // For quiz type

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 6) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
        if (_correctAnswerIndex == index) {
          _correctAnswerIndex = null;
        } else if (_correctAnswerIndex != null &&
            _correctAnswerIndex! > index) {
          _correctAnswerIndex = _correctAnswerIndex! - 1;
        }
      });
    }
  }

  void _createPoll() {
    if (_questionController.text.isEmpty) return;

    final validOptions =
        _optionControllers.where((c) => c.text.isNotEmpty).toList();

    if (validOptions.length < 2) return;

    // Create poll object (ID would be generated server-side)
    final poll = EnhancedPoll(
      id: '', // Will be set by server
      question: _questionController.text,
      pollType: _selectedType,
      isAnonymous: _isAnonymous,
      endsAt: _endsAt,
      createdAt: DateTime.now(),
      options:
          validOptions.asMap().entries.map((entry) {
            return PollOption(
              id: '',
              pollId: '',
              text: entry.value.text,
              order: entry.key,
              isCorrect:
                  _selectedType == PollType.quiz &&
                  _correctAnswerIndex == entry.key,
            );
          }).toList(),
    );

    widget.onPollCreated(poll);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useFluent = context.read<ThemeProvider>().useFluentUI;

    if (useFluent) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poll Type',
              style: fluent.FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  PollType.values.map((type) {
                    final isSelected = _selectedType == type;
                    if (isSelected) {
                      return fluent.FilledButton(
                        onPressed: () {
                          HapticUtils.selectionClick();
                          setState(() => _selectedType = type);
                        },
                        child: Text(type.label),
                      );
                    }
                    return fluent.Button(
                      onPressed: () {
                        HapticUtils.selectionClick();
                        setState(() => _selectedType = type);
                      },
                      child: Text(type.label),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            fluent.TextBox(
              controller: _questionController,
              placeholder:
                  _selectedType == PollType.thisOrThat
                      ? 'Which do you prefer?'
                      : 'Ask your question...',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Options',
              style: fluent.FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_selectedType == PollType.quiz)
                      fluent.Checkbox(
                        checked: _correctAnswerIndex == index,
                        onChanged: (v) {
                          HapticUtils.selectionClick();
                          setState(() => _correctAnswerIndex = index);
                        },
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: fluent.TextBox(
                        controller: _optionControllers[index],
                        placeholder: 'Option ${index + 1}',
                        suffix:
                            _optionControllers.length > 2
                                ? fluent.IconButton(
                                  icon: const Icon(fluent.FluentIcons.clear),
                                  onPressed: () => _removeOption(index),
                                )
                                : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 6)
              fluent.Button(
                onPressed: _addOption,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(fluent.FluentIcons.add, size: 12),
                    const SizedBox(width: 8),
                    const Text('Add Option'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            fluent.Checkbox(
              checked: _isAnonymous,
              onChanged: (v) {
                HapticUtils.selectionClick();
                setState(() => _isAnonymous = v ?? false);
              },
              content: const Text('Anonymous Voting'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.onCancel != null) ...[
                  Expanded(
                    child: fluent.Button(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: fluent.FilledButton(
                    onPressed: _createPoll,
                    child: const Text('Create Poll'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll Type Selector
          Text('Poll Type', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                PollType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (_) {
                      HapticUtils.selectionClick();
                      setState(() => _selectedType = type);
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),

          // Question
          TextField(
            controller: _questionController,
            decoration: InputDecoration(
              labelText: 'Question',
              hintText:
                  _selectedType == PollType.thisOrThat
                      ? 'Which do you prefer?'
                      : 'Ask your question...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // Options
          Text('Options', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...List.generate(_optionControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (_selectedType == PollType.quiz)
                    IconButton(
                      icon: Icon(
                        _correctAnswerIndex == index
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color:
                            _correctAnswerIndex == index
                                ? Colors.green
                                : colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        HapticUtils.selectionClick();
                        setState(() => _correctAnswerIndex = index);
                      },
                      tooltip: 'Mark as correct answer',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon:
                            _optionControllers.length > 2
                                ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _removeOption(index),
                                )
                                : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_optionControllers.length < 6)
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Add Option'),
            ),
          const SizedBox(height: 16),

          // Settings
          SwitchListTile(
            title: const Text('Anonymous Voting'),
            subtitle: const Text("Voters' names won't be shown"),
            value: _isAnonymous,
            onChanged: (value) {
              HapticUtils.selectionClick();
              setState(() => _isAnonymous = value);
            },
          ),

          ListTile(
            title: const Text('End Time (Optional)'),
            subtitle: Text(
              _endsAt != null
                  ? '${_endsAt!.day}/${_endsAt!.month}/${_endsAt!.year} ${_endsAt!.hour}:${_endsAt!.minute.toString().padLeft(2, '0')}'
                  : 'No end time',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_endsAt != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _endsAt = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _endsAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (widget.onCancel != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _createPoll,
                  child: const Text('Create Poll'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying and voting on polls
class PollDisplay extends StatelessWidget {
  final EnhancedPoll poll;
  final Function(String optionId)? onVote;
  final bool showResults;

  const PollDisplay({
    super.key,
    required this.poll,
    this.onVote,
    this.showResults = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useFluent = context.read<ThemeProvider>().useFluentUI;
    final showResultsNow = showResults || poll.hasVoted || poll.isExpired;

    if (useFluent) {
      return fluent.Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPollTypeIcon(true),
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  poll.pollType.label,
                  style: fluent.FluentTheme.of(
                    context,
                  ).typography.caption?.copyWith(color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              poll.question,
              style: fluent.FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 12),
            if (poll.pollType == PollType.thisOrThat)
              _buildThisOrThatOptions(context, showResultsNow, true)
            else
              ...poll.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildOptionTile(context, option, showResultsNow, true),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${poll.totalVotes} votes',
              style: fluent.FluentTheme.of(context).typography.caption,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll type indicator
          Row(
            children: [
              Icon(_getPollTypeIcon(), size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                poll.pollType.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              if (poll.isAnonymous) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.visibility_off,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Anonymous',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Question
          Text(
            poll.question,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Options
          if (poll.pollType == PollType.thisOrThat)
            _buildThisOrThatOptions(context, showResultsNow)
          else
            ...poll.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildOptionTile(context, option, showResultsNow),
              ),
            ),

          // Footer
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (poll.endsAt != null) ...[
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color:
                      poll.isExpired
                          ? Colors.red
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  poll.isExpired ? 'Ended' : _getTimeRemaining(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        poll.isExpired
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    PollOption option,
    bool showResults, [
    bool useFluent = false,
  ]) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = poll.userVotedOptionId == option.id;

    if (useFluent) {
      return fluent.Button(
        onPressed:
            (!poll.hasVoted && !poll.isExpired && onVote != null)
                ? () {
                  HapticUtils.selectionClick();
                  onVote!(option.id);
                }
                : null,
        style: fluent.ButtonStyle(
          backgroundColor:
              isSelected
                  ? fluent.WidgetStateProperty.all(colorScheme.primaryContainer)
                  : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: fluent.FluentTheme.of(
                  context,
                ).typography.bodyStrong?.copyWith(
                  fontWeight: isSelected ? FontWeight.w900 : null,
                ),
              ),
            ),
            if (showResults)
              Text(
                '${option.percentage.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap:
          (!poll.hasVoted && !poll.isExpired && onVote != null)
              ? () {
                HapticUtils.selectionClick();
                onVote!(option.id);
              }
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (showResults) ...[
              const SizedBox(width: 8),
              Text(
                '${option.percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (poll.pollType == PollType.quiz &&
                showResults &&
                option.isCorrect)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThisOrThatOptions(
    BuildContext context,
    bool showResults, [
    bool useFluent = false,
  ]) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (poll.options.length < 2) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _buildThisOrThatOption(
            context,
            poll.options[0],
            showResults,
            isLeft: true,
            useFluent: useFluent,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'VS',
            style: (useFluent
                ? fluent.FluentTheme.of(context).typography.bodyStrong
                : theme.textTheme.labelLarge)?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _buildThisOrThatOption(
            context,
            poll.options[1],
            showResults,
            isLeft: false,
            useFluent: useFluent,
          ),
        ),
      ],
    );
  }

  Widget _buildThisOrThatOption(
    BuildContext context,
    PollOption option,
    bool showResults, {
    required bool isLeft,
    bool useFluent = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = poll.userVotedOptionId == option.id;

    if (useFluent) {
      return fluent.Button(
        onPressed:
            (!poll.hasVoted && !poll.isExpired && onVote != null)
                ? () {
                  HapticUtils.selectionClick();
                  onVote!(option.id);
                }
                : null,
        style: fluent.ButtonStyle(
          backgroundColor:
              isSelected
                  ? fluent.WidgetStateProperty.all(colorScheme.primaryContainer)
                  : null,
        ),
        child: Column(
          children: [
            Text(
              option.text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (showResults)
              Text(
                '${option.percentage.toStringAsFixed(0)}%',
                style: fluent.FluentTheme.of(context).typography.subtitle,
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap:
          (!poll.hasVoted && !poll.isExpired && onVote != null)
              ? () {
                HapticUtils.selectionClick();
                onVote!(option.id);
              }
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              option.text,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (showResults) ...[
              const SizedBox(height: 8),
              Text(
                '${option.percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getPollTypeIcon([bool useFluent = false]) {
    if (useFluent) {
      switch (poll.pollType) {
        case PollType.single:
          return fluent.FluentIcons.radio_bullet;
        case PollType.multiple:
          return fluent.FluentIcons.checkbox_composite;
        case PollType.thisOrThat:
          return fluent.FluentIcons.compare;
        case PollType.quiz:
          return fluent.FluentIcons.questionnaire;
      }
    }
    switch (poll.pollType) {
      case PollType.single:
        return Icons.radio_button_checked;
      case PollType.multiple:
        return Icons.check_box;
      case PollType.thisOrThat:
        return Icons.compare_arrows;
      case PollType.quiz:
        return Icons.quiz;
    }
  }

  String _getTimeRemaining() {
    if (poll.endsAt == null) return '';
    final remaining = poll.endsAt!.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d left';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h left';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m left';
    }
    return 'Ending soon';
  }
}
