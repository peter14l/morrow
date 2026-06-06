import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/services/instagram_migration_service.dart';
import 'package:oasis/widgets/app_button.dart';
import 'package:oasis/core/theme/oasis_colors.dart';

class InstagramImportSettingsScreen extends StatefulWidget {
  const InstagramImportSettingsScreen({super.key});

  @override
  State<InstagramImportSettingsScreen> createState() => _InstagramImportSettingsScreenState();
}

class _InstagramImportSettingsScreenState extends State<InstagramImportSettingsScreen> {
  final _migrationService = InstagramMigrationService();
  bool _isProcessingZip = false;
  String? _zipPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasisColors.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Import from Instagram', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_zipPath == null) ...[
              const Text(
                'Upload your Instagram data export (ZIP) to import your posts directly into Oasis.',
                style: TextStyle(color: OasisColors.mist, fontSize: 16),
              ),
              const SizedBox(height: 32),
              AppButton.primary(
                text: 'Select Instagram ZIP',
                onPressed: _isProcessingZip ? null : _pickAndProcessZip,
                isLoading: _isProcessingZip,
              ),
            ] else ...[
              const Text(
                'Select Posts to Migrate',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Type a Circle name below a post to auto-create a private Circle for it, or leave blank for your main feed.',
                style: TextStyle(color: OasisColors.mist),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _migrationService.availablePosts.length,
                  itemBuilder: (context, index) {
                    final post = _migrationService.availablePosts[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: OasisColors.sage.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: post.isSelected ? OasisColors.glow : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              child: Image.file(post.tempMediaFile, fit: BoxFit.cover),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: post.isSelected,
                                      activeColor: OasisColors.glow,
                                      onChanged: (val) {
                                        setState(() => post.isSelected = val ?? false);
                                      },
                                    ),
                                    const Expanded(child: Text('Import', style: TextStyle(color: Colors.white, fontSize: 12))),
                                  ],
                                ),
                                SizedBox(
                                  height: 32,
                                  child: TextField(
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: const InputDecoration(
                                      hintText: 'Circle Name (Optional)',
                                      hintStyle: TextStyle(color: OasisColors.mist, fontSize: 10),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (val) => post.targetCircleName = val.trim(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              AppButton.primary(
                text: 'Start Import',
                onPressed: () async {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    _migrationService.startBackgroundPostMigration(user.id, _migrationService.availablePosts);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Import started in background!')),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _zipPath = null;
                    _migrationService.reset();
                  });
                },
                child: const Text('Reset / Change File', style: TextStyle(color: OasisColors.mist)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessZip() async {
    setState(() => _isProcessingZip = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        _zipPath = result.files.single.path;
        final success = await _migrationService.preProcessZip(_zipPath!);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_migrationService.currentStatus)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingZip = false);
    }
  }
}
