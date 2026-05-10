import 'package:supabase_flutter/supabase_flutter.dart';

/// Image transformation options for Supabase CDN
class ImageTransform {
  final int? width;
  final int? height;
  final String format;
  final int quality;
  final String resizeMode; // 'cover', 'contain', 'fill'

  const ImageTransform({
    this.width,
    this.height,
    this.format = 'webp',
    this.quality = 80,
    this.resizeMode = 'cover',
  });
}

/// Preset transformations
class ImagePresets {
  static const thumbnail = ImageTransform(width: 150, height: 150);
  static const card = ImageTransform(width: 500);
  static const avatar = ImageTransform(width: 200, height: 200);
  static const full = ImageTransform(quality: 90);
}

class ImageService {
  final SupabaseClient _client;

  ImageService(this._client);

  /// Get optimized image URL from Supabase Storage using CDN transformations
  String getOptimizedUrl({
    required String bucket,
    required String path,
    ImageTransform transform = const ImageTransform(),
  }) {
    // If the path is already a full URL, we might need to parse it
    // but usually we store the path in DB.
    
    return _client.storage.from(bucket).getPublicUrl(
      path,
      transform: TransformOptions(
        width: transform.width,
        height: transform.height,
        format: transform.format,
        quality: transform.quality,
        resize: transform.resizeMode,
      ),
    );
  }

  /// Convenience helpers
  String getAvatar(String userId) => getOptimizedUrl(
        bucket: 'avatars',
        path: '$userId/profile.png',
        transform: ImagePresets.avatar,
      );

  String getPostImage(String path) => getOptimizedUrl(
        bucket: 'posts',
        path: path,
        transform: ImagePresets.card,
      );
}
