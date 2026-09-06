import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oasis/widgets/liquid_glass_wrapper.dart';

/// File preview bar shown above the input area when a file is selected.
class FilePreview extends StatelessWidget {
  const FilePreview({super.key, required this.file, required this.onDismiss});

  final PlatformFile file;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String formatBytes(int bytes) {
      if (bytes <= 0) return '0 B';
      const suffixes = ['B', 'KB', 'MB', 'GB'];
      int i = 0;
      double size = bytes.toDouble();
      while (size >= 1024 && i < suffixes.length - 1) {
        size /= 1024;
        i++;
      }
      return '${size.toStringAsFixed(1)} ${suffixes[i]}';
    }

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
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.insert_drive_file_rounded,
              color: colorScheme.primary,
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
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatBytes(file.size),
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
