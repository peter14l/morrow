import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/core/config/r2_config.dart';

/// Chat background image with opacity and brightness control.
/// Extracted from the Positioned.fill background in chat_screen.dart.
class ChatBackground extends StatelessWidget {
  const ChatBackground({
    super.key,
    this.backgroundUrl,
    this.bgOpacity = 1.0,
    this.bgBrightness = 0.7,
  });

  final String? backgroundUrl;
  final double bgOpacity;
  final double bgBrightness;

  String? get _normalizedUrl {
    if (backgroundUrl == null) return null;
    
    // Fix legacy URLs that point to the private S3 endpoint instead of public R2 domain
    if (backgroundUrl!.contains('cloudflarestorage.com')) {
      // S3 URL: https://<id>.r2.cloudflarestorage.com/oasis/<userId>/<fileId>
      // Public URL: https://pub-xxx.r2.dev/<userId>/<fileId>
      final parts = backgroundUrl!.split('/oasis/');
      if (parts.length > 1) {
        return '${R2Config.r2PublicBaseUrl}/${parts.last}';
      }
    }
    
    return backgroundUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final url = _normalizedUrl;

    return Positioned.fill(
      child: Stack(
        children: [
          // Base background color
          Container(color: colorScheme.surface),
          // Background image overlay
          if (url != null)
            Positioned.fill(
              child: Opacity(
                opacity: bgOpacity,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(
                    alpha: (1 - bgBrightness).clamp(0.0, 1.0),
                  ),
                  colorBlendMode: BlendMode.darken,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
