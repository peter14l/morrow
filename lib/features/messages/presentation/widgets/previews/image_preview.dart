import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/media_view_mode_selector.dart';

/// Image preview bar shown above the input area when an image is selected.
/// Extracted from _buildImagePreview() + _buildMediaViewModeSelector() in chat_screen.dart.
class ImagePreview extends StatelessWidget {
  const ImagePreview({
    super.key,
    required this.imagePath,
    required this.mediaViewMode,
    required this.onDismiss,
    required this.onViewModeChanged,
  });

  final String imagePath;
  final String mediaViewMode;
  final VoidCallback onDismiss;
  final Function(String) onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath),
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Image selected'),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
            ],
          ),
          const SizedBox(height: 8),
          MediaViewModeSelector(
            currentMode: mediaViewMode,
            onModeChanged: onViewModeChanged,
          ),
        ],
      ),
    );
  }
}
