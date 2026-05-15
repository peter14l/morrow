import 'package:oasis/services/subscription_service.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';

/// Creator Tools Suite - Analytics service for creators
class CreatorAnalyticsService {
  final _supabase = SupabaseService().client;

  /// Get overall creator stats
  Future<CreatorStats> getCreatorStats(String userId) async {
    try {
      // Get follower count
      final followersResponse = await _supabase
          .from('followers')
          .select()
          .eq('following_id', userId);

      // Get posts stats
      final postsResponse = await _supabase
          .from('posts')
          .select('id, likes_count, comments_count, shares_count, created_at')
          .eq('user_id', userId);

      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;

      for (final post in postsResponse) {
        totalLikes += (post['likes_count'] ?? 0) as int;
        totalComments += (post['comments_count'] ?? 0) as int;
        totalShares += (post['shares_count'] ?? 0) as int;
      }

      final totalPosts = postsResponse.length;
      final totalEngagements = totalLikes + totalComments + totalShares;
      final followerCount = followersResponse.length;

      final engagementRate = followerCount > 0 && totalPosts > 0
          ? (totalEngagements / (followerCount * totalPosts)) * 100
          : 0.0;

      return CreatorStats(
        followerCount: followerCount,
        totalPosts: totalPosts,
        totalLikes: totalLikes,
        totalComments: totalComments,
        totalShares: totalShares,
        engagementRate: engagementRate,
      );
    } catch (e) {
      debugPrint('Error getting creator stats: $e');
      return CreatorStats.empty();
    }
  }

  /// Get post performance data for last 30 days
  Future<List<PostPerformance>> getPostPerformance(
    String userId, {
    int days = 30,
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      final effectiveDays = isPro ? days : (days > 7 ? 7 : days);
      final startDate = DateTime.now().subtract(Duration(days: effectiveDays));

      final response = await _supabase
          .from('posts')
          .select(
            'id, content, image_urls, likes_count, comments_count, shares_count, views_count, created_at',
          )
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false);

      return response
          .map<PostPerformance>((post) => PostPerformance.fromJson(post))
          .toList();
    } catch (e) {
      debugPrint('Error getting post performance: $e');
      return [];
    }
  }

  /// Get follower growth data
  Future<List<GrowthDataPoint>> getFollowerGrowth(
    String userId, {
    int days = 30,
  }) async {
    try {
      final isPro = SubscriptionService().isPro;
      final effectiveDays = isPro ? days : (days > 7 ? 7 : days);
      final startDate = DateTime.now().subtract(Duration(days: effectiveDays));

      final response = await _supabase
          .from('followers')
          .select('created_at')
          .eq('following_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: true);

      // Group by day
      final Map<String, int> dailyCounts = {};
      int runningTotal = 0;

      for (final follower in response) {
        final date = DateTime.parse(
          follower['created_at'],
        ).toIso8601String().substring(0, 10);
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      final List<GrowthDataPoint> dataPoints = [];
      for (var i = 0; i < effectiveDays; i++) {
        final date = DateTime.now().subtract(
          Duration(days: effectiveDays - i - 1),
        );
        final dateKey = date.toIso8601String().substring(0, 10);
        runningTotal += dailyCounts[dateKey] ?? 0;
        dataPoints.add(
          GrowthDataPoint(
            date: date,
            value: runningTotal,
            change: dailyCounts[dateKey] ?? 0,
          ),
        );
      }

      return dataPoints;
    } catch (e) {
      debugPrint('Error getting follower growth: $e');
      return [];
    }
  }

  /// Get best posting times based on engagement
  Future<Map<String, double>> getBestPostingTimes(String userId) async {
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      throw Exception(
        'Upgrade to Oasis Pro to access personalized best posting times heatmap.',
      );
    }
    try {
      final response = await _supabase
          .from('posts')
          .select('created_at, likes_count, comments_count')
          .eq('user_id', userId)
          .limit(100);

      final Map<int, List<double>> hourlyEngagement = {};

      for (final post in response) {
        final createdAt = DateTime.parse(post['created_at']);
        final hour = createdAt.hour;
        final engagement =
            ((post['likes_count'] ?? 0) + (post['comments_count'] ?? 0))
                .toDouble();

        hourlyEngagement.putIfAbsent(hour, () => []);
        hourlyEngagement[hour]!.add(engagement);
      }

      final Map<String, double> bestTimes = {};
      hourlyEngagement.forEach((hour, engagements) {
        final avg = engagements.reduce((a, b) => a + b) / engagements.length;
        final timeKey = '${hour.toString().padLeft(2, '0')}:00';
        bestTimes[timeKey] = avg;
      });

      return bestTimes;
    } catch (e) {
      debugPrint('Error getting best posting times: $e');
      return {};
    }
  }

  /// Get audience demographics (simplified)
  Future<AudienceDemographics> getAudienceDemographics(String userId) async {
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      throw Exception('Upgrade to Oasis Pro to access audience demographics.');
    }
    try {
      // Get followers with their profile data
      final response = await _supabase
          .from('followers')
          .select('''
            users:user_id (
              profiles:id (location)
            )
          ''')
          .eq('following_id', userId)
          .limit(500);

      // Process locations
      final Map<String, int> locationCounts = {};
      for (final follower in response) {
        final location = follower['users']?['profiles']?['location'] as String?;
        if (location != null && location.isNotEmpty) {
          locationCounts[location] = (locationCounts[location] ?? 0) + 1;
        }
      }

      // Get top locations
      final sortedLocations = locationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topLocations = Map.fromEntries(sortedLocations.take(10));

      return AudienceDemographics(
        totalFollowers: response.length,
        topLocations: topLocations,
      );
    } catch (e) {
      debugPrint('Error getting audience demographics: $e');
      return AudienceDemographics.empty();
    }
  }

  /// Get content performance by type
  Future<Map<String, ContentTypeStats>> getContentTypeStats(
    String userId,
  ) async {
    final isPro = SubscriptionService().isPro;
    if (!isPro) {
      throw Exception(
        'Upgrade to Oasis Pro to access content-type performance breakdown.',
      );
    }
    try {
      final response = await _supabase
          .from('posts')
          .select(
            'id, image_urls, video_url, likes_count, comments_count, shares_count',
          )
          .eq('user_id', userId);

      int imagePostsCount = 0;
      int videoPostsCount = 0;
      int textPostsCount = 0;
      int imageEngagement = 0;
      int videoEngagement = 0;
      int textEngagement = 0;

      for (final post in response) {
        final likes = (post['likes_count'] ?? 0) as int;
        final comments = (post['comments_count'] ?? 0) as int;
        final shares = (post['shares_count'] ?? 0) as int;
        final totalEngagement = likes + comments + shares;

        final hasImages = (post['image_urls'] as List?)?.isNotEmpty ?? false;
        final hasVideo = post['video_url'] != null;

        if (hasVideo) {
          videoPostsCount++;
          videoEngagement += totalEngagement;
        } else if (hasImages) {
          imagePostsCount++;
          imageEngagement += totalEngagement;
        } else {
          textPostsCount++;
          textEngagement += totalEngagement;
        }
      }

      return {
        'image': ContentTypeStats(
          count: imagePostsCount,
          totalEngagement: imageEngagement,
          avgEngagement: imagePostsCount > 0
              ? imageEngagement / imagePostsCount
              : 0,
        ),
        'video': ContentTypeStats(
          count: videoPostsCount,
          totalEngagement: videoEngagement,
          avgEngagement: videoPostsCount > 0
              ? videoEngagement / videoPostsCount
              : 0,
        ),
        'text': ContentTypeStats(
          count: textPostsCount,
          totalEngagement: textEngagement,
          avgEngagement: textPostsCount > 0
              ? textEngagement / textPostsCount
              : 0,
        ),
      };
    } catch (e) {
      debugPrint('Error getting content type stats: $e');
      return {};
    }
  }
}

class CreatorStats {
  final int followerCount;
  final int totalPosts;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final double engagementRate;

  CreatorStats({
    required this.followerCount,
    required this.totalPosts,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.engagementRate,
  });

  factory CreatorStats.empty() => CreatorStats(
    followerCount: 0,
    totalPosts: 0,
    totalLikes: 0,
    totalComments: 0,
    totalShares: 0,
    engagementRate: 0,
  );

  int get totalEngagements => totalLikes + totalComments + totalShares;
}

class PostPerformance {
  final String id;
  final String? content;
  final List<String> imageUrls;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime createdAt;

  PostPerformance({
    required this.id,
    this.content,
    this.imageUrls = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
  });

  factory PostPerformance.fromJson(Map<String, dynamic> json) {
    return PostPerformance(
      id: json['id'],
      content: json['content'],
      imageUrls: (json['image_urls'] as List?)?.cast<String>() ?? [],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  int get totalEngagement => likesCount + commentsCount + sharesCount;
  double get engagementRate =>
      viewsCount > 0 ? (totalEngagement / viewsCount) * 100 : 0;
}

class GrowthDataPoint {
  final DateTime date;
  final int value;
  final int change;

  GrowthDataPoint({
    required this.date,
    required this.value,
    required this.change,
  });
}

class AudienceDemographics {
  final int totalFollowers;
  final Map<String, int> topLocations;

  AudienceDemographics({
    required this.totalFollowers,
    required this.topLocations,
  });

  factory AudienceDemographics.empty() =>
      AudienceDemographics(totalFollowers: 0, topLocations: {});
}

class ContentTypeStats {
  final int count;
  final int totalEngagement;
  final double avgEngagement;

  ContentTypeStats({
    required this.count,
    required this.totalEngagement,
    required this.avgEngagement,
  });
}
