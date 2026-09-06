import 'package:flutter/material.dart';
import 'package:oasis/features/messages/presentation/widgets/previews/media_view_mode_selector.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';

/// Video preview bar shown above the input area when a video is selected.
class VideoPreview extends StatelessWidget {
  const VideoPreview({
    super.key,
    required this.mediaViewMode,
    required this.onDismiss,
    required this.onViewModeChanged,
  });

  final String mediaViewMode;
  final VoidCallback onDismiss;
  final Function(String) onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LiquidGlassWrapper(
      borderRadius: 24,
      shape: const LiquidRoundedSuperellipse(borderRadius: 24),
      config: LiquidGlassConfig.Medium,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Attached',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready to send',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.onSurface.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(32, 32),
                ),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 10),
          MediaViewModeSelector(
            currentMode: mediaViewMode,
            onModeChanged: onViewModeChanged,
          ),
        ],
      ),
    );
  }
}
