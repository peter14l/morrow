import 'package:flutter/material.dart';

/// Desktop context menu for attachment options.
/// Displays at cursor position when right-clicking the attachment button.
class AttachmentOptionsMenu extends StatelessWidget {
  const AttachmentOptionsMenu({
    super.key,
    required this.position,
    required this.onPhotoSelected,
    required this.onVideoSelected,
    required this.onFileSelected,
    required this.onAudioSelected,
  });

  final Offset position;
  final VoidCallback onPhotoSelected;
  final VoidCallback onVideoSelected;
  final VoidCallback onFileSelected;
  final VoidCallback onAudioSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: <PopupMenuEntry>[
        PopupMenuItem(
          onTap: onPhotoSelected,
          child: const Row(
            children: [
              Icon(
                Icons.image_rounded,
                size: 20,
                color: Color(0xFF3D8BFF),
              ),
              SizedBox(width: 12),
              Text('Photo'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onVideoSelected,
          child: const Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 20,
                color: Color(0xFFFF6B6B),
              ),
              SizedBox(width: 12),
              Text('Video'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onFileSelected,
          child: const Row(
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: 20,
                color: Color(0xFF51CF66),
              ),
              SizedBox(width: 12),
              Text('File'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: onAudioSelected,
          child: const Row(
            children: [
              Icon(
                Icons.audio_file_rounded,
                size: 20,
                color: Color(0xFFFFD43B),
              ),
              SizedBox(width: 12),
              Text('Audio'),
            ],
          ),
        ),
      ],
    );

    return const SizedBox.shrink();
  }
}
