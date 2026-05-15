import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oasis/services/curation_tracking_service.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Key for sync preference in SharedPreferences
const String _kCurationSyncEnabled = 'curation_sync_enabled';

class PrivacyTransparencyCard extends material.StatefulWidget {
  const PrivacyTransparencyCard({super.key});

  @override
  material.State<PrivacyTransparencyCard> createState() =>
      _PrivacyTransparencyCardState();
}

class _PrivacyTransparencyCardState
    extends material.State<PrivacyTransparencyCard> {
  bool _isSyncEnabled = false;
  bool _isLoading = true;
  bool _isSyncing = false;

  bool get _isDesktop {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _loadSyncPreference();
  }

  Future<void> _loadSyncPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isSyncEnabled = prefs.getBool(_kCurationSyncEnabled) ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSync(bool newValue) async {
    if (newValue == true) {
      // Turning ON - sync existing local data to server
      await _syncLocalToServer();
    } else if (_isSyncEnabled == true) {
      // Turning OFF from ON - show warning
      final confirmed = await _showTurnOffWarning();
      if (!confirmed) return; // User cancelled
      // Delete from server
      await _deleteServerAnalytics();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCurationSyncEnabled, newValue);
    if (mounted) setState(() => _isSyncEnabled = newValue);
  }

  Future<void> _syncLocalToServer() async {
    if (_isSyncing) return;

    final supabase = SupabaseService();
    if (!supabase.isAuthenticated) {
      material.debugPrint(
        '[PrivacyTransparency] User not authenticated, skipping sync',
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final service = context.read<CurationTrackingService>();
      final syncData = await service.getSyncData();

      for (final data in syncData) {
        await supabase.client.rpc('sync_user_analytics', params: data);
      }

      material.debugPrint(
        '[PrivacyTransparency] Sync to server completed: ${syncData.length} categories',
      );
    } catch (e) {
      material.debugPrint('[PrivacyTransparency] Sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<bool> _showTurnOffWarning() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.useFluentUI && _isDesktop) {
      return await fluent.showDialog<bool>(
            context: context,
            builder: (context) => fluent.ContentDialog(
              title: const material.Text('Disable Cloud Sync?'),
              content: const material.Text(
                'Disabling sync will return your data to local-only storage. '
                'You won\'t receive curated recommendations on new devices, and your '
                'analytics will be deleted from our servers.\n\n'
                'Are you sure you want to disable?',
              ),
              actions: [
                fluent.Button(
                  onPressed: () => material.Navigator.pop(context, false),
                  child: const material.Text('Cancel'),
                ),
                fluent.FilledButton(
                  onPressed: () => material.Navigator.pop(context, true),
                  style: fluent.ButtonStyle(
                    backgroundColor: fluent.WidgetStateProperty.all(
                      material.Colors.red,
                    ),
                  ),
                  child: const material.Text('Disable Sync'),
                ),
              ],
            ),
          ) ??
          false;
    }

    return await material.showDialog<bool>(
          context: context,
          builder: (context) => material.AlertDialog(
            title: const material.Text('Disable Cloud Sync?'),
            content: const material.Text(
              'Disabling sync will return your data to local-only storage. '
              'You won\'t receive curated recommendations on new devices, and your '
              'analytics will be deleted from our servers.\n\n'
              'Are you sure you want to disable?',
            ),
            actions: [
              material.TextButton(
                onPressed: () => material.Navigator.pop(context, false),
                child: const material.Text('Cancel'),
              ),
              material.TextButton(
                onPressed: () => material.Navigator.pop(context, true),
                style: material.TextButton.styleFrom(
                  foregroundColor: material.Theme.of(context).colorScheme.error,
                ),
                child: const material.Text('Disable Sync'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteServerAnalytics() async {
    final supabase = SupabaseService();
    if (!supabase.isAuthenticated) return;

    try {
      await supabase.client.rpc('delete_user_analytics');
      material.debugPrint('[PrivacyTransparency] Deleted server analytics');
    } catch (e) {
      material.debugPrint('[PrivacyTransparency] Delete error: $e');
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final useFluent = themeProvider.useFluentUI && _isDesktop;

    return material.Container(
      padding: const material.EdgeInsets.all(20),
      decoration: material.BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: material.BorderRadius.circular(isM3E ? 28 : 16),
        border: material.Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isM3E ? 1.5 : 1,
        ),
      ),
      child: material.Column(
        crossAxisAlignment: material.CrossAxisAlignment.start,
        children: [
          material.Row(
            children: [
              material.Container(
                padding: const material.EdgeInsets.all(10),
                decoration: material.BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: material.BorderRadius.circular(12),
                ),
                child: material.Icon(
                  FluentIcons.shield_task_24_regular,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const material.SizedBox(width: 16),
              material.Expanded(
                child: material.Text(
                  'Privacy Transparency',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const material.SizedBox(height: 16),
          material.Text(
            'Oasis collects data on your interactions (likes, time spent, and categories) to provide personalized curation. This data is stored on your device by default and only synced to our secure servers if you enable Cloud Sync.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const material.SizedBox(height: 16),

          // "Your data is NEVER sold" assurance text
          material.Container(
            padding: const material.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: material.BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: material.BorderRadius.circular(8),
            ),
            child: material.Row(
              children: [
                material.Icon(
                  FluentIcons.checkmark_circle_24_regular,
                  color: colorScheme.primary,
                  size: 18,
                ),
                const material.SizedBox(width: 8),
                material.Expanded(
                  child: material.Text(
                    'Your data is NEVER sold to third parties and is SOLELY used to provide you with curated content.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: material.FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const material.SizedBox(height: 16),

          // Sync toggle
          if (!_isLoading) ...[
            const material.Divider(),
            const material.SizedBox(height: 8),
            if (useFluent)
              fluent.ListTile(
                title: const material.Text('Sync to Cloud'),
                subtitle: material.Text(
                  _isSyncEnabled
                      ? _isSyncing
                            ? 'Syncing your analytics...'
                            : 'Your analytics are backed up for new devices'
                      : 'Keep analytics local only',
                  style: theme.textTheme.bodySmall,
                ),
                leading: _isSyncing
                    ? const fluent.ProgressRing(strokeWidth: 2)
                    : material.Icon(
                        _isSyncEnabled
                            ? FluentIcons.cloud_checkmark_24_regular
                            : FluentIcons.cloud_dismiss_24_regular,
                        color: _isSyncEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                trailing: fluent.ToggleSwitch(
                  checked: _isSyncEnabled,
                  onChanged: _isSyncing ? null : _toggleSync,
                ),
              )
            else
              material.SwitchListTile(
                title: const material.Text('Sync to Cloud'),
                subtitle: material.Text(
                  _isSyncEnabled
                      ? _isSyncing
                            ? 'Syncing your analytics...'
                            : 'Your analytics are backed up for new devices'
                      : 'Keep analytics local only',
                  style: theme.textTheme.bodySmall,
                ),
                value: _isSyncEnabled,
                onChanged: _isSyncing ? null : _toggleSync,
                contentPadding: material.EdgeInsets.zero,
                secondary: _isSyncing
                    ? const material.SizedBox(
                        width: 24,
                        height: 24,
                        child: material.CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : material.Icon(
                        _isSyncEnabled
                            ? FluentIcons.cloud_checkmark_24_regular
                            : FluentIcons.cloud_dismiss_24_regular,
                        color: _isSyncEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
              ),
          ],

          const material.SizedBox(height: 8),
          material.FutureBuilder<Map<String, dynamic>>(
            future: context
                .read<CurationTrackingService>()
                .getTrackingSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const material.SizedBox.shrink();
              final data = snapshot.data!;
              return material.Column(
                children: [
                  _buildSummaryItem(
                    context,
                    'Tracked Categories',
                    '${data['tracked_categories']}',
                  ),
                  _buildSummaryItem(
                    context,
                    'Likes Recorded',
                    '${data['total_likes_recorded']}',
                  ),
                  _buildSummaryItem(
                    context,
                    'Data Location',
                    _isSyncEnabled
                        ? 'Local + Cloud'
                        : '${data['data_location']}',
                  ),
                  const material.SizedBox(height: 12),
                  material.TextButton.icon(
                    onPressed: () => _confirmClearData(context),
                    icon: const material.Icon(
                      FluentIcons.delete_24_regular,
                      size: 18,
                    ),
                    label: const material.Text('Clear Local Tracking Data'),
                    style: material.TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      visualDensity: material.VisualDensity.compact,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  material.Widget _buildSummaryItem(
    material.BuildContext context,
    String label,
    String value,
  ) {
    final theme = material.Theme.of(context);
    return material.Padding(
      padding: const material.EdgeInsets.symmetric(vertical: 4),
      child: material.Row(
        mainAxisAlignment: material.MainAxisAlignment.spaceBetween,
        children: [
          material.Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          material.Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: material.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(material.BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.useFluentUI && _isDesktop) {
      fluent.showDialog(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const material.Text('Clear Tracking Data?'),
          content: const material.Text(
            'This will remove all locally stored curation data. Your recommendations may become less personalized.',
          ),
          actions: [
            fluent.Button(
              onPressed: () => material.Navigator.pop(context),
              child: const material.Text('Cancel'),
            ),
            fluent.FilledButton(
              onPressed: () async {
                await context.read<CurationTrackingService>().clearAllData();
                if (context.mounted) material.Navigator.pop(context);
              },
              style: fluent.ButtonStyle(
                backgroundColor: fluent.WidgetStateProperty.all(
                  material.Colors.red,
                ),
              ),
              child: const material.Text('Clear Data'),
            ),
          ],
        ),
      );
      return;
    }

    material.showDialog(
      context: context,
      builder: (context) => material.AlertDialog(
        title: const material.Text('Clear Tracking Data?'),
        content: const material.Text(
          'This will remove all locally stored curation data. Your recommendations may become less personalized.',
        ),
        actions: [
          material.TextButton(
            onPressed: () => material.Navigator.pop(context),
            child: const material.Text('Cancel'),
          ),
          material.TextButton(
            onPressed: () async {
              await context.read<CurationTrackingService>().clearAllData();
              if (context.mounted) material.Navigator.pop(context);
            },
            child: material.Text(
              'Clear Data',
              style: material.TextStyle(
                color: material.Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
