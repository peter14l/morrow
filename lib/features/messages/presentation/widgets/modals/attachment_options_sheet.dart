import 'package:universal_io/io.dart' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:oasis/features/messages/presentation/widgets/shared/attachment_option_card.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';

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

    // Check if platform supports google location (hide on web/desktop)
    final bool canShareLocation =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return SafeArea(
      child: LiquidGlassWrapper(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        borderRadius: 32,
        shape: const LiquidRoundedSuperellipse(borderRadius: 32),
        config: LiquidGlassConfig.Medium,
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
    );
  }
}
