import 'package:flutter/material.dart';
import 'package:oasis/services/privacy_audit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PrivacyHeartbeatScreen extends StatefulWidget {
  final SupabaseClient? client;
  final PrivacyAuditService? auditService;

  const PrivacyHeartbeatScreen({super.key, this.client, this.auditService});

  @override
  State<PrivacyHeartbeatScreen> createState() => _PrivacyHeartbeatScreenState();
}

class _PrivacyHeartbeatScreenState extends State<PrivacyHeartbeatScreen> {
  late final PrivacyAuditService _auditService;
  late final SupabaseClient _supabase;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _auditService = widget.auditService ?? PrivacyAuditService();
    _supabase = widget.client ?? Supabase.instance.client;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final logs = await _auditService.fetchLogs(userId);
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Heartbeat')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(child: Text('No privacy logs found.'))
          : ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final action = log['action'] as String;
                final resource = log['resource_type'] as String;
                final timestamp = log['timestamp'] != null
                    ? DateTime.parse(log['timestamp'] as String)
                    : DateTime.now();

                return ListTile(
                  leading: Icon(
                    _getIconForAction(action),
                    color: _getColorForAction(action),
                  ),
                  title: Text('$action on $resource'),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy HH:mm:ss').format(timestamp),
                  ),
                );
              },
            ),
    );
  }

  IconData _getIconForAction(String action) {
    switch (action) {
      case 'READ':
        return Icons.visibility;
      case 'WRITE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color _getColorForAction(String action) {
    switch (action) {
      case 'READ':
        return Colors.blue;
      case 'WRITE':
        return Colors.green;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
