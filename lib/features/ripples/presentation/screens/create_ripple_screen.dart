import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/ripples/presentation/providers/ripples_provider.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/services/app_initializer.dart';

class CreateRippleScreen extends StatefulWidget {
  const CreateRippleScreen({super.key});

  @override
  State<CreateRippleScreen> createState() => _CreateRippleScreenState();
}

class _CreateRippleScreenState extends State<CreateRippleScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isLoading = false;

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _videoController?.dispose();
      final file = File(video.path);
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
        if (mounted) {
          setState(() {
            _videoFile = file;
            _videoController = controller;
          });
          controller.setLooping(true);
          controller.play();
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play this video: $e')),
          );
        }
      }
    }
  }

  Future<void> _uploadRipple() async {
    if (_videoFile == null) return;

    setState(() => _isLoading = true);

    try {
      await context.read<RipplesProvider>().uploadAndCreateRipple(
        videoFile: _videoFile!,
        caption: _captionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ripple shared!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;

    final content = SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickVideo,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child:
                      _videoController != null &&
                              _videoController!.value.isInitialized
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: VideoPlayer(_videoController!),
                          )
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                FluentIcons.video_add_24_regular,
                                color: Colors.white54,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Select a video',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (useFluent && isDesktop)
              fluent.TextBox(
                controller: _captionController,
                placeholder: 'Add a caption...',
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              )
            else
              TextField(
                controller: _captionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (isDesktop && _videoFile != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: useFluent
                    ? fluent.FilledButton(
                      onPressed: _isLoading ? null : _uploadRipple,
                      child:
                          _isLoading
                              ? const fluent.ProgressRing(strokeWidth: 2)
                              : const Text('Share Ripple'),
                    )
                    : FilledButton(
                      onPressed: _isLoading ? null : _uploadRipple,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Share Ripple',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                    ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isDesktop) {
      if (useFluent) {
        return AdaptiveScaffold(
          title: Row(
            children: [
              fluent.IconButton(
                icon: const Icon(fluent.FluentIcons.back),
                onPressed:
                    () => context.canPop() ? context.pop() : context.go('/feed'),
              ),
              const SizedBox(width: 8),
              const Text('New Ripple'),
            ],
          ),
          actions: [
            fluent.FilledButton(
              onPressed: _isLoading || _videoFile == null ? null : _uploadRipple,
              child:
                  _isLoading
                      ? const fluent.ProgressRing(strokeWidth: 2)
                      : const Text('Share'),
            ),
          ],
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: content,
            ),
          ),
        );
      }

      return AdaptiveScaffold(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed:
                  () => context.canPop() ? context.pop() : context.go('/feed'),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
            const Text('New Ripple'),
          ],
        ),
        actions: [
          if (_videoFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: FilledButton(
                  onPressed: _isLoading ? null : _uploadRipple,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Share'),
                ),
              ),
            ),
        ],
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FluentIcons.dismiss_24_filled, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New Ripple',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_videoFile != null)
            TextButton(
              onPressed: _isLoading ? null : _uploadRipple,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
            ),
        ],
      ),
      body: content,
    );
  }
}
