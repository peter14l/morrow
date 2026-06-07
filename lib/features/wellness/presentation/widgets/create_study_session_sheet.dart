import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/wellness/presentation/providers/study_session_provider.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import 'package:oasis/features/wellness/presentation/screens/active_study_session_screen.dart';

class CreateStudySessionSheet extends StatefulWidget {
  const CreateStudySessionSheet({super.key});

  @override
  State<CreateStudySessionSheet> createState() => _CreateStudySessionSheetState();
}

class _CreateStudySessionSheetState extends State<CreateStudySessionSheet> {
  final _titleController = TextEditingController();
  int _durationMinutes = 25;
  bool _isLockedIn = true;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<StudySessionProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start Focus Room',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Session Title',
                hintText: 'e.g., Deep Work, Silent Reading',
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Duration: $_durationMinutes minutes',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [15, 25, 45, 60, 90].map((mins) {
                final isSelected = _durationMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: isSelected,
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _durationMinutes = mins;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Strict Lock-in Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Backgrounding or exiting the app during study session will result in XP penalties.',
                style: TextStyle(fontSize: 12),
              ),
              value: _isLockedIn,
              onChanged: (val) {
                setState(() {
                  _isLockedIn = val;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        CustomSnackbar.showError(
                          context,
                          'Please enter a session title',
                        );
                        return;
                      }

                      try {
                        await provider.createSession(
                          title: title,
                          durationMinutes: _durationMinutes,
                          isLockedIn: _isLockedIn,
                        );
                        if (mounted) {
                          Navigator.pop(context); // Close bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ActiveStudySessionScreen(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to start session: $e',
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Launch Session',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
