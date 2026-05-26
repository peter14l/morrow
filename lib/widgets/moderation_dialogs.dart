import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/moderation_service.dart';
import 'package:oasis/models/moderation.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportDialog extends StatefulWidget {
  final String? userId;
  final String? postId;
  final String? commentId;
  final String? messageId;

  const ReportDialog({
    super.key,
    this.userId,
    this.postId,
    this.commentId,
    this.messageId,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? userId,
    String? postId,
    String? commentId,
    String? messageId,
  }) {
    final useFluent = context.read<ThemeProvider>().useFluentUI;
    if (useFluent) {
      return fluent.showDialog<bool>(
        context: context,
        builder: (context) => FluentReportDialog(
          userId: userId,
          postId: postId,
          commentId: commentId,
          messageId: messageId,
        ),
      );
    }

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportDialog(
        userId: userId,
        postId: postId,
        commentId: commentId,
        messageId: messageId,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _moderationService = ModerationService();
  final _descriptionController = TextEditingController();

  String _selectedCategory = ReportCategory.spam;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final categoryName = ReportCategory.getDisplayName(_selectedCategory);
      final details = _descriptionController.text.trim();

      final reportId = await _moderationService.submitReport(
        reportedUserId: widget.userId,
        postId: widget.postId,
        commentId: widget.commentId,
        messageId: widget.messageId,
        category: _selectedCategory,
        reason: categoryName,
        description: details.isEmpty ? null : details,
      );

      if (reportId != null && mounted) {
        // Launch email for support notification as requested
        await _launchSupportEmail(categoryName, details);

        if (mounted) {
          Navigator.of(context).pop(true);
          CustomSnackbar.showSuccess(context, 'Report submitted successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _launchSupportEmail(String category, String details) async {
    final type = widget.messageId != null
        ? 'Message'
        : widget.postId != null
        ? 'Post'
        : widget.commentId != null
        ? 'Comment'
        : 'User';

    final id =
        widget.messageId ??
        widget.postId ??
        widget.commentId ??
        widget.userId ??
        'N/A';

    final body =
        '''
New Report Submitted:
--------------------
Type: $type
Target ID: $id
Reported User ID: ${widget.userId ?? 'N/A'}
Category: $category
Details: ${details.isEmpty ? 'None provided' : details}

This report was also submitted to our moderation system.
''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'oasis.officialsupport@gmail.com',
      query:
          'subject=${Uri.encodeComponent('New Report: $category ($type)')}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      debugPrint('Could not launch email client: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appTheme = theme.extension<AppThemeExtension>();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Report',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Scrollable content
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    children: [
                      const Text(
                        'Why are you reporting this?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      ...ReportCategory.all.map((category) {
                        return RadioListTile<String>(
                          value: category,
                          groupValue: _selectedCategory,
                          title: Text(ReportCategory.getDisplayName(category)),
                          onChanged: (value) {
                            setState(() => _selectedCategory = value!);
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Details (Optional)',
                          hintText: 'Provide more context for our team...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerLow,
                        ),
                        maxLines: 3,
                        maxLength: 500,
                      ),
                      if (appTheme != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appTheme.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: appTheme.info.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: appTheme.info,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Note: Report details will be shared with Oasis Support via email for further review.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Action buttons
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submitReport,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Submit Report'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BlockUserDialog extends StatelessWidget {
  final String userId;
  final String username;

  const BlockUserDialog({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final moderationService = ModerationService();

    return AlertDialog(
      title: const Text('Block User'),
      content: Text(
        'Are you sure you want to block @$username? They won\'t be able to see your posts or contact you.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final success = await moderationService.blockUser(userId);
            if (context.mounted) {
              Navigator.of(context).pop(success);
              if (success) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Blocked @$username')));
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Block'),
        ),
      ],
    );
  }
}

class MuteUserDialog extends StatefulWidget {
  final String userId;
  final String username;

  const MuteUserDialog({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<MuteUserDialog> createState() => _MuteUserDialogState();
}

class _MuteUserDialogState extends State<MuteUserDialog> {
  Duration? _duration;

  final List<MapEntry<String, Duration?>> _durationOptions = [
    const MapEntry('24 hours', Duration(hours: 24)),
    const MapEntry('7 days', Duration(days: 7)),
    const MapEntry('30 days', Duration(days: 30)),
    const MapEntry('Forever', null),
  ];

  @override
  Widget build(BuildContext context) {
    final moderationService = ModerationService();

    return AlertDialog(
      title: const Text('Mute User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You won\'t see posts from @${widget.username} in your feed.'),
          const SizedBox(height: 16),
          const Text(
            'Duration:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._durationOptions.map((option) {
            return RadioListTile<Duration?>(
              value: option.value,
              groupValue: _duration,
              title: Text(option.key),
              onChanged: (value) {
                setState(() => _duration = value);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _duration == null && _durationOptions.last.value != null
              ? null
              : () async {
                  final success = await moderationService.muteUser(
                    widget.userId,
                    duration: _duration,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(success);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Muted @${widget.username}')),
                      );
                    }
                  }
                },
          child: const Text('Mute'),
        ),
      ],
    );
  }
}

class FluentReportDialog extends StatefulWidget {
  final String? userId;
  final String? postId;
  final String? commentId;
  final String? messageId;

  const FluentReportDialog({
    super.key,
    this.userId,
    this.postId,
    this.commentId,
    this.messageId,
  });

  @override
  State<FluentReportDialog> createState() => _FluentReportDialogState();
}

class _FluentReportDialogState extends State<FluentReportDialog> {
  final _moderationService = ModerationService();
  final _descriptionController = TextEditingController();

  String _selectedCategory = ReportCategory.spam;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    try {
      final categoryName = ReportCategory.getDisplayName(_selectedCategory);
      final details = _descriptionController.text.trim();

      final reportId = await _moderationService.submitReport(
        reportedUserId: widget.userId,
        postId: widget.postId,
        commentId: widget.commentId,
        messageId: widget.messageId,
        category: _selectedCategory,
        reason: categoryName,
        description: details.isEmpty ? null : details,
      );

      if (reportId != null && mounted) {
        await _launchSupportEmail(categoryName, details);

        if (mounted) {
          Navigator.of(context).pop(true);
          fluent.displayInfoBar(
            context,
            builder: (context, close) {
              return const fluent.InfoBar(
                title: Text('Success'),
                content: Text('Report submitted successfully'),
                severity: fluent.InfoBarSeverity.success,
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        fluent.displayInfoBar(
          context,
          builder: (context, close) {
            return fluent.InfoBar(
              title: const Text('Error'),
              content: Text(e.toString()),
              severity: fluent.InfoBarSeverity.error,
            );
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _launchSupportEmail(String category, String details) async {
    final type = widget.messageId != null
        ? 'Message'
        : widget.postId != null
        ? 'Post'
        : widget.commentId != null
        ? 'Comment'
        : 'User';

    final id =
        widget.messageId ??
        widget.postId ??
        widget.commentId ??
        widget.userId ??
        'N/A';

    final body =
        '''
New Report Submitted:
--------------------
Type: $type
Target ID: $id
Reported User ID: ${widget.userId ?? 'N/A'}
Category: $category
Details: ${details.isEmpty ? 'None provided' : details}

This report was also submitted to our moderation system.
''';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'oasis.officialsupport@gmail.com',
      query:
          'subject=${Uri.encodeComponent('New Report: $category ($type)')}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (e) {
      debugPrint('Could not launch email client: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return fluent.ContentDialog(
      title: const Text('Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why are you reporting this?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          fluent.RadioGroup<String>(
            groupValue: _selectedCategory,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCategory = value);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...ReportCategory.all.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: fluent.RadioButton<String>(
                      value: category,
                      content: Text(ReportCategory.getDisplayName(category)),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          fluent.InfoLabel(
            label: 'Details (Optional)',
            child: fluent.TextBox(
              controller: _descriptionController,
              placeholder: 'Provide more context for our team...',
              maxLines: 3,
              minLines: 3,
              maxLength: 500,
            ),
          ),
          const SizedBox(height: 16),
          const fluent.InfoBar(
            title: Text('Note'),
            content: Text(
              'Report details will be shared with Oasis Support via email for further review.',
            ),
            severity: fluent.InfoBarSeverity.info,
            isLong: false,
          ),
        ],
      ),
      actions: [
        fluent.Button(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        fluent.FilledButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: fluent.ButtonStyle(
            backgroundColor: fluent.WidgetStateProperty.all(fluent.Colors.red),
          ),
          child: _isSubmitting
              ? const fluent.ProgressRing()
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
