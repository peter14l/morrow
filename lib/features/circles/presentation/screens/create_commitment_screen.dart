import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';

class CreateCommitmentScreen extends StatefulWidget {
  final String circleId;
  const CreateCommitmentScreen({super.key, required this.circleId});

  @override
  State<CreateCommitmentScreen> createState() => _CreateCommitmentScreenState();
}

class _CreateCommitmentScreenState extends State<CreateCommitmentScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  // Quick-pick suggestions
  static const _suggestions = [
    'Read for 20 min 📚',
    'Walk or stretch 🚶',
    'No phone before 9am 📵',
    'Drink 8 glasses of water 💧',
    'Meditate for 10 min 🧘',
    'Write 3 things I\'m grateful for ✍️',
    'Call a friend or family 📞',
    'No social media after 10pm 🌙',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final userId = context.read<ProfileProvider>().currentProfile?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<CircleProvider>().addCommitment(
        createdBy: userId,
        title: title,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        dueDate: DateTime.now(),
      );
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Add Commitment'),
        leading: IconButton(
          icon: const Icon(FluentIcons.dismiss_24_regular),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main input ───────────────────────────────────────────────
            Text(
              "What's the commitment?",
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Read for 20 minutes',
              ),
            ),

            const SizedBox(height: 24),

            // ── Quick suggestions ────────────────────────────────────────
            Text(
              'Quick picks',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  onPressed: () {
                    _titleController.text = s;
                    setState(() {});
                  },
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  labelStyle: theme.textTheme.bodySmall,
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Optional note ────────────────────────────────────────────
            Text(
              'Details (optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Any extra context for the group...',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // ── Post Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _create,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(FluentIcons.send_24_regular),
                label: Text(_isLoading ? 'Posting...' : 'Post to Circle'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
