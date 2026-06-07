import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/wellness/presentation/providers/study_session_provider.dart';
import 'package:oasis/features/wellness/presentation/widgets/create_study_session_sheet.dart';
import 'package:oasis/features/wellness/presentation/screens/active_study_session_screen.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:oasis/widgets/custom_snackbar.dart';

class StudySessionsHubScreen extends StatefulWidget {
  const StudySessionsHubScreen({super.key});

  @override
  State<StudySessionsHubScreen> createState() => _StudySessionsHubScreenState();
}

class _StudySessionsHubScreenState extends State<StudySessionsHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudySessionProvider>().fetchActiveSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<StudySessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Rooms'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => provider.fetchActiveSessions(),
          ),
        ],
      ),
      body: provider.isLoading && provider.activeSessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchActiveSessions(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildStatsBanner(theme, colorScheme),
                    const SizedBox(height: 24),
                    Text(
                      'Live Study Rooms',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (provider.activeSessions.isEmpty)
                      _buildEmptyState(theme, colorScheme)
                    else
                      ...provider.activeSessions.map((session) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              session.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Duration: ${session.durationMinutes} min • Status: ${session.status}',
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                try {
                                  await provider.joinSession(session);
                                  if (context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ActiveStudySessionScreen(),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    CustomSnackbar.showError(
                                      context,
                                      'Failed to join session: $e',
                                    );
                                  }
                                }
                              },
                              child: const Text('Join'),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            builder: (context) => const CreateStudySessionSheet(),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Room'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildStatsBanner(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OasisColors.moss,
            OasisColors.sage,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Together',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: OasisColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join collaborative timer spaces. Timers synchronize automatically, rewarding you with XP for completing focus sessions alongside friends.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: OasisColors.mist,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No active study rooms',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to launch a room and invite your friends!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
