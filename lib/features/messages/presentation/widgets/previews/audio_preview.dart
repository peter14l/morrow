import 'package:flutter/material.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';

/// Audio preview bar shown above the input area when audio is selected.
class AudioPreview extends StatelessWidget {
  const AudioPreview({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LiquidGlassWrapper(
      borderRadius: 20,
      shape: const LiquidRoundedSuperellipse(borderRadius: 20),
      config: LiquidGlassConfig.Medium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD43B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.audio_file_rounded,
              color: Color(0xFFFFD43B),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Audio Clip Attached',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ready to send',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
    );
  }
}
