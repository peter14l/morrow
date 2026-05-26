import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:oasis/services/subscription_service.dart';

/// Cross-posting service for sharing content to other platforms
class CrossPostingService {
  /// Available platforms for cross-posting
  static const List<CrossPostPlatform> platforms = [
    CrossPostPlatform(
      id: 'twitter',
      name: 'X (Twitter)',
      icon: 'twitter',
      maxLength: 280,
      supportsImages: true,
      supportsVideo: true,
    ),
    CrossPostPlatform(
      id: 'facebook',
      name: 'Facebook',
      icon: 'facebook',
      maxLength: 63206,
      supportsImages: true,
      supportsVideo: true,
    ),
    CrossPostPlatform(
      id: 'linkedin',
      name: 'LinkedIn',
      icon: 'linkedin',
      maxLength: 3000,
      supportsImages: true,
      supportsVideo: true,
    ),
    CrossPostPlatform(
      id: 'threads',
      name: 'Threads',
      icon: 'threads',
      maxLength: 500,
      supportsImages: true,
      supportsVideo: true,
    ),
    CrossPostPlatform(
      id: 'copy',
      name: 'Copy Link',
      icon: 'link',
      maxLength: 0,
      supportsImages: false,
      supportsVideo: false,
    ),
    CrossPostPlatform(
      id: 'more',
      name: 'More Options',
      icon: 'more',
      maxLength: 0,
      supportsImages: true,
      supportsVideo: true,
    ),
  ];

  /// Share content to a specific platform
  static Future<CrossPostResult> shareToPlatiorm({
    required String platformId,
    required String content,
    String? postUrl,
    List<String>? imageUrls,
    String? videoUrl,
  }) async {
    try {
      final platform = platforms.firstWhere(
        (p) => p.id == platformId,
        orElse: () => platforms.last,
      );

      // Truncate content if needed
      String shareText = content;
      if (platform.maxLength > 0 && content.length > platform.maxLength) {
        shareText = '${content.substring(0, platform.maxLength - 25)}... ';
      }

      // Add post URL if available
      if (postUrl != null && postUrl.isNotEmpty) {
        shareText = '$shareText\n\n$postUrl';
      }

      final isPro = SubscriptionService().isPro;

      switch (platformId) {
        case 'twitter':
        case 'linkedin':
          if (!isPro) {
            // Free users fall back to generic native share
            return await _shareGeneric(shareText, imageUrls);
          }
          if (platformId == 'twitter') {
            return await _shareToTwitter(shareText, imageUrls);
          }
          return await _shareToLinkedIn(shareText, postUrl);
        case 'facebook':
          return await _shareToFacebook(shareText, postUrl);
        case 'threads':
          return await _shareToThreads(shareText);
        case 'copy':
          return await _copyToClipboard(postUrl ?? shareText);
        case 'more':
        default:
          return await _shareGeneric(shareText, imageUrls);
      }
    } catch (e) {
      debugPrint('Cross-posting error: $e');
      return CrossPostResult(
        success: false,
        platformId: platformId,
        error: e.toString(),
      );
    }
  }

  static Future<CrossPostResult> _shareToTwitter(
    String text,
    List<String>? images,
  ) async {
    // Use share_plus for now (in production would use Twitter API)
    await Share.share(text);
    return CrossPostResult(success: true, platformId: 'twitter');
  }

  static Future<CrossPostResult> _shareToFacebook(
    String text,
    String? url,
  ) async {
    final shareContent = url != null ? '$text\n$url' : text;
    await Share.share(shareContent);
    return CrossPostResult(success: true, platformId: 'facebook');
  }

  static Future<CrossPostResult> _shareToLinkedIn(
    String text,
    String? url,
  ) async {
    final shareContent = url != null ? '$text\n$url' : text;
    await Share.share(shareContent);
    return CrossPostResult(success: true, platformId: 'linkedin');
  }

  static Future<CrossPostResult> _shareToThreads(String text) async {
    await Share.share(text);
    return CrossPostResult(success: true, platformId: 'threads');
  }

  static Future<CrossPostResult> _copyToClipboard(String text) async {
    await Share.share(text);
    return CrossPostResult(success: true, platformId: 'copy');
  }

  static Future<CrossPostResult> _shareGeneric(
    String text,
    List<String>? images,
  ) async {
    await Share.share(text);
    return CrossPostResult(success: true, platformId: 'more');
  }

  /// Format content for different platforms
  static String formatForPlatform(
    String platformId,
    String originalContent, {
    List<String>? hashtags,
    String? postUrl,
  }) {
    final platform = platforms.firstWhere(
      (p) => p.id == platformId,
      orElse: () => platforms.last,
    );

    String formattedContent = originalContent;

    // Add hashtags if space allows
    if (hashtags != null && hashtags.isNotEmpty) {
      final hashtagString = hashtags.take(5).join(' ');
      final withHashtags = '$formattedContent\n\n$hashtagString';

      if (platform.maxLength == 0 ||
          withHashtags.length <= platform.maxLength) {
        formattedContent = withHashtags;
      }
    }

    // Add URL for Twitter/LinkedIn
    if (postUrl != null &&
        (platformId == 'twitter' || platformId == 'linkedin')) {
      formattedContent = '$formattedContent\n$postUrl';
    }

    // Truncate if needed
    if (platform.maxLength > 0 &&
        formattedContent.length > platform.maxLength) {
      formattedContent =
          '${formattedContent.substring(0, platform.maxLength - 3)}...';
    }

    return formattedContent;
  }

  /// Get character count status
  static CharacterCountStatus getCharacterCount(
    String platformId,
    String content,
  ) {
    final platform = platforms.firstWhere(
      (p) => p.id == platformId,
      orElse: () => platforms.last,
    );

    if (platform.maxLength == 0) {
      return CharacterCountStatus(
        current: content.length,
        max: 0,
        remaining: 0,
        isOverLimit: false,
      );
    }

    final remaining = platform.maxLength - content.length;
    return CharacterCountStatus(
      current: content.length,
      max: platform.maxLength,
      remaining: remaining,
      isOverLimit: remaining < 0,
    );
  }
}

class CrossPostPlatform {
  final String id;
  final String name;
  final String icon;
  final int maxLength;
  final bool supportsImages;
  final bool supportsVideo;

  const CrossPostPlatform({
    required this.id,
    required this.name,
    required this.icon,
    required this.maxLength,
    required this.supportsImages,
    required this.supportsVideo,
  });
}

class CrossPostResult {
  final bool success;
  final String platformId;
  final String? error;
  final String? postId;

  CrossPostResult({
    required this.success,
    required this.platformId,
    this.error,
    this.postId,
  });
}

class CharacterCountStatus {
  final int current;
  final int max;
  final int remaining;
  final bool isOverLimit;

  CharacterCountStatus({
    required this.current,
    required this.max,
    required this.remaining,
    required this.isOverLimit,
  });

  double get percentUsed => max > 0 ? (current / max) : 0;
}
