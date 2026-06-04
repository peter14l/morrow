import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/b2_config.dart';
import 'package:oasis/services/s3_storage_service.dart';
import 'package:oasis/services/subscription_service.dart';

/// Service to enforce media retention policies:
/// - Free users: 14-day retention (server-side media deleted after 14 days)
/// - Pro users: Unlimited retention (media kept indefinitely)
///
/// Note: This handles server-side storage retention.
/// Local cached media is a separate concern handled by MediaCacheService.
class MediaRetentionService {
  static MediaRetentionService? _instance;
  final S3StorageService _s3Service = S3StorageService();

  MediaRetentionService._();

  factory MediaRetentionService() {
    _instance ??= MediaRetentionService._();
    return _instance!;
  }

  /// Check if media should be retained based on user tier
  bool shouldRetainMedia(DateTime mediaCreatedAt) {
    final subscriptionService = SubscriptionService();

    // Pro users have unlimited retention
    if (subscriptionService.isPro) {
      return true;
    }

    // Free users: 14-day retention policy
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
    return mediaCreatedAt.isAfter(fourteenDaysAgo);
  }

  /// Cleanup old media for free users
  /// Should be called periodically (e.g., daily or on app startup)
  /// Returns the number of files deleted
  Future<int> cleanupExpiredMedia() async {
    final subscriptionService = SubscriptionService();

    // Pro users don't need cleanup
    if (subscriptionService.isPro) {
      debugPrint('[MediaRetentionService] Pro user - skipping cleanup');
      return 0;
    }

    debugPrint('[MediaRetentionService] Starting cleanup for free user...');

    try {
      final supabase = SupabaseService().client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('[MediaRetentionService] No authenticated user');
        return 0;
      }

      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      // Query messages with old media attachments
      // Note: This requires the messages table to have created_at and media_url fields
      final oldMessages = await supabase
          .from('messages')
          .select('id, media_urls, created_at')
          .eq('sender_id', userId)
          .lt('created_at', fourteenDaysAgo.toIso8601String())
          .not('media_urls', 'is', null);

      int deletedCount = 0;

      for (final message in oldMessages) {
        final mediaUrls = message['media_urls'] as List<dynamic>?;
        if (mediaUrls == null || mediaUrls.isEmpty) continue;

        for (final url in mediaUrls) {
          try {
            await _deleteMediaFromR2(url.toString());
            deletedCount++;
          } catch (e) {
            debugPrint('[MediaRetentionService] Error deleting media: $e');
          }
        }
      }

      debugPrint(
        '[MediaRetentionService] Deleted $deletedCount expired media files',
      );
      return deletedCount;
    } catch (e) {
      debugPrint('[MediaRetentionService] Cleanup error: $e');
      return 0;
    }
  }

  /// Delete a single media file from R2
  Future<void> _deleteMediaFromR2(String url) async {
    if (!url.startsWith('http')) return;

    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2) {
        // Extract type and fileId from URL path
        // URL format: https://.../bucket/type/userId/filename
        final type = pathSegments.length > 2
            ? pathSegments[pathSegments.length - 3]
            : 'images';
        final userId = pathSegments.length > 1
            ? pathSegments[pathSegments.length - 2]
            : '';
        final fileName = pathSegments.last;
        final fileId = '$userId/$fileName';

        await _s3Service.deleteFile(
          bucket: B2Config.b2BucketName,
          fileId: fileId,
          type: type,
        );
        debugPrint('[MediaRetentionService] Deleted: $fileId');
      }
    } catch (e) {
      debugPrint('[MediaRetentionService] Error parsing URL $url: $e');
    }
  }

  /// Get remaining days for a media file (null if Pro or doesn't exist)
  int? getRemainingDays(DateTime mediaCreatedAt) {
    final subscriptionService = SubscriptionService();

    if (subscriptionService.isPro) {
      return null; // Unlimited
    }

    final expiresAt = mediaCreatedAt.add(const Duration(days: 14));
    final remaining = expiresAt.difference(DateTime.now()).inDays;

    return remaining > 0 ? remaining : 0;
  }

  /// Check if media is about to expire (within 7 days)
  bool isExpiringSoon(DateTime mediaCreatedAt) {
    final days = getRemainingDays(mediaCreatedAt);
    return days != null && days <= 7 && days > 0;
  }

  /// Get retention status for display
  String getRetentionStatus(DateTime mediaCreatedAt) {
    final subscriptionService = SubscriptionService();

    if (subscriptionService.isPro) {
      return 'Unlimited (Pro)';
    }

    final days = getRemainingDays(mediaCreatedAt);
    if (days == null || days > 7) {
      return 'Available';
    } else if (days > 0) {
      return 'Expires in $days day${days == 1 ? '' : 's'}';
    } else {
      return 'Expired';
    }
  }
}
