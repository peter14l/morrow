import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/update_service.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/widgets/app_button.dart';
import 'package:oasis/widgets/desktop_header.dart';
import 'package:oasis/core/utils/responsive_layout.dart';

class UpdateSettingsScreen extends StatefulWidget {
  const UpdateSettingsScreen({super.key});

  @override
  State<UpdateSettingsScreen> createState() => _UpdateSettingsScreenState();
}

class _UpdateSettingsScreenState extends State<UpdateSettingsScreen> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Consumer<UpdateService>(
      builder: (context, updateService, _) {
        final progress = updateService.currentProgress;

        // Auto-scroll logs
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return Scaffold(
          backgroundColor: isDesktop
              ? Colors.transparent
              : theme.scaffoldBackgroundColor,
          appBar: isDesktop
              ? null
              : AppBar(title: const Text('Software Update'), centerTitle: true),
          body: Column(
            children: [
              if (isDesktop)
                DesktopHeader(
                  title: 'Software Update',
                  showBackButton: true,
                  onBack: () => Navigator.of(context).pop(),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: MaxWidthContainer(
                    maxWidth: 600,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // App Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 60,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Oasis',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current Version: ${AppConfig.appVersion}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Status Card
                        _buildStatusCard(context, updateService),

                        const SizedBox(height: 32),

                        // Action Buttons
                        if (progress.status == UpdateStatus.idle ||
                            progress.status == UpdateStatus.upToDate ||
                            progress.status == UpdateStatus.failed)
                          AppButton.primary(
                            onPressed: () =>
                                updateService.checkForUpdates(manual: true),
                            text: 'Check for Updates',
                            icon: const Icon(Icons.refresh),
                            width: double.infinity,
                          ),

                        if (progress.status == UpdateStatus.available)
                          AppButton.primary(
                            onPressed: () {
                              if (updateService.cachedUpdateInfo != null) {
                                updateService.downloadAndInstallUpdate(
                                  updateService.cachedUpdateInfo!,
                                );
                              }
                            },
                            text: 'Update Now',
                            icon: const Icon(Icons.download),
                            width: double.infinity,
                          ),

                        const SizedBox(height: 32),

                        // Logs Section
                        if (progress.logs.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Update Logs',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 200,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: ListView.builder(
                              controller: _logScrollController,
                              itemCount: progress.logs.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    progress.logs[index],
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, UpdateService updateService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = updateService.currentProgress;

    String title = 'Up to Date';
    String message = 'You are using the latest version of Oasis.';
    IconData icon = Icons.check_circle_outline;
    Color iconColor = Colors.green;

    switch (progress.status) {
      case UpdateStatus.checking:
        title = 'Checking...';
        message = 'Looking for the latest version...';
        icon = Icons.search;
        iconColor = colorScheme.primary;
        break;
      case UpdateStatus.available:
        title = 'Update Available';
        message =
            'Version ${updateService.cachedUpdateInfo?.latestVersion} is ready to download.';
        icon = Icons.file_download_outlined;
        iconColor = colorScheme.secondary;
        break;
      case UpdateStatus.downloading:
        title = 'Downloading Update';
        message = 'Fetching the latest APK...';
        icon = Icons.downloading;
        iconColor = colorScheme.primary;
        break;
      case UpdateStatus.installing:
        title = 'Installing Update';
        message = 'Preparing the installation package...';
        icon = Icons.settings_suggest;
        iconColor = colorScheme.primary;
        break;
      case UpdateStatus.completed:
        title = 'Update Ready';
        message = 'Installation started. The app will restart shortly.';
        icon = Icons.verified_outlined;
        iconColor = Colors.green;
        break;
      case UpdateStatus.failed:
        title = 'Update Failed';
        message = progress.error ?? 'An unexpected error occurred.';
        icon = Icons.error_outline;
        iconColor = colorScheme.error;
        break;
      case UpdateStatus.upToDate:
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress.status == UpdateStatus.downloading ||
              progress.status == UpdateStatus.installing) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.status == UpdateStatus.installing
                    ? null
                    : progress.progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            if (progress.status == UpdateStatus.downloading)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(progress.progress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
