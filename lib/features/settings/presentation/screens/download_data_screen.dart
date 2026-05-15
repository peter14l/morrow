import 'package:flutter/material.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/services/data_export_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DownloadDataScreen extends StatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _error;
  final _exportService = DataExportService();

  Future<void> _requestDataExport() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isSuccess = false;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('You must be logged in to request your data');
      }

      await _exportService.requestDataExport(userId: user.id);

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Request submitted! Check your email within 48 hours.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final content = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.download, size: 80, color: Colors.teal),
          const SizedBox(height: 24),
          const Text(
            'Get a copy of your Oasis info',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'We will email you a link to a file with your photos, comments, profile information and more. It may take up to 48 hours to collect this data and send it to you.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_isSuccess)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your request has been submitted. You will receive an email link within 48 hours.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ElevatedButton(
              onPressed: _isLoading ? null : _requestDataExport,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Request Download'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );

    if (isDesktop) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Your Data'),
        centerTitle: true,
      ),
      body: content,
    );
  }
}
