import 'package:universal_io/io.dart' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oasis/features/messages/presentation/widgets/shared/attachment_option_card.dart';

import 'package:oasis/core/extensions/context_extensions.dart';

/// Attachment options bottom sheet.
/// Extracted from _showAttachmentOptions() in chat_screen.dart.
class AttachmentOptionsSheet extends StatelessWidget {
  const AttachmentOptionsSheet({
    super.key,
    required this.onPhotoSelected,
    required this.onVideoSelected,
    required this.onFileSelected,
    required this.onAudioSelected,
    required this.onLocationSelected,
  });

  final VoidCallback onPhotoSelected;
  final VoidCallback onVideoSelected;
  final VoidCallback onFileSelected;
  final VoidCallback onAudioSelected;
  final VoidCallback onLocationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSolid = ContextX(context).shouldUseSolidBackground;

    // Check if platform supports google location (hide on web/desktop)
    final bool canShareLocation =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: isSolid
              ? colorScheme.surface
              : colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Share content',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.onSurface.withValues(
                          alpha: 0.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Grid of options
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AttachmentOptionCard(
                      icon: Icons.image_rounded,
                      label: 'Photo',
                      iconColor: const Color(0xFF3D8BFF),
                      bgColor: const Color(0xFF3D8BFF).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(context);
                        onPhotoSelected();
                      },
                    ),
                    AttachmentOptionCard(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      iconColor: const Color(0xFFFF6B6B),
                      bgColor: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(context);
                        onVideoSelected();
                      },
                    ),
                    AttachmentOptionCard(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'File',
                      iconColor: const Color(0xFF51CF66),
                      bgColor: const Color(0xFF51CF66).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(context);
                        onFileSelected();
                      },
                    ),
                    AttachmentOptionCard(
                      icon: Icons.audio_file_rounded,
                      label: 'Audio',
                      iconColor: const Color(0xFFFFD43B),
                      bgColor: const Color(0xFFFFD43B).withValues(alpha: 0.1),
                      onTap: () {
                        Navigator.pop(context);
                        onAudioSelected();
                      },
                    ),
                    if (canShareLocation)
                      AttachmentOptionCard(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        iconColor: const Color(0xFF20C997),
                        bgColor: const Color(0xFF20C997).withValues(alpha: 0.1),
                        onTap: () {
                          Navigator.pop(context);
                          onLocationSelected();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
