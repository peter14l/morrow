import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/domain/repositories/feed_repository.dart';
import 'package:oasis/features/feed/data/datasources/feed_remote_datasource.dart';

/// Implementation of FeedRepository.
///
/// Combines remote data (Supabase RPC) with local caching
/// and handles ad injection for non-Pro users.
class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDatasource _remoteDatasource;

  FeedRepositoryImpl({FeedRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? FeedRemoteDatasource();

  @override
  Future<List<Post>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    final rawPosts = await _remoteDatasource.getFeedPosts(
      userId: userId,
      limit: limit,
      cursor: cursor,
    );

    final posts = rawPosts.map((json) => Post.fromJson(json)).toList();
    return _injectAdsIfFreeUser(posts);
  }

  @override
  Future<List<Post>> getFollowingFeedPosts({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    final rawPosts = await _remoteDatasource.getFollowingFeedPosts(
      userId: userId,
      limit: limit,
      cursor: cursor,
    );

    final posts = rawPosts.map((json) => Post.fromJson(json)).toList();
    return _injectAdsIfFreeUser(posts);
  }

  @override
  Future<List<Post>> getUnifiedFeed({
    required String userId,
    int limit = 20,
    String? cursor,
  }) async {
    final rawPosts = await _remoteDatasource.getUnifiedFeed(
      userId: userId,
      limit: limit,
      cursor: cursor,
    );

    final posts = rawPosts.map((json) => Post.fromJson(json)).toList();
    return _injectAdsIfFreeUser(posts);
  }

  @override
  Stream<List<Post>> watchFeedPosts({required String userId, int limit = 20}) {
    return _remoteDatasource
        .watchFeedPosts(userId: userId, limit: limit)
        .map(
          (rawPosts) => rawPosts.map((json) => Post.fromJson(json)).toList(),
        );
  }

  /// Inject ad posts every 5th position for non-Pro users.
  List<Post> _injectAdsIfFreeUser(List<Post> posts) {
    final isPro = SubscriptionService().isPro;

    if (isPro) return posts;

    final feedWithAds = <Post>[];
    for (int i = 0; i < posts.length; i++) {
      feedWithAds.add(posts[i]);
      if ((i + 1) % 5 == 0) {
        feedWithAds.add(
          Post(
            id: 'ad_${DateTime.now().millisecondsSinceEpoch}_$i',
            userId: 'ad_system',
            username: 'Sponsored',
            userAvatar: 'https://ui-avatars.com/api/?name=Ad&background=random',
            content:
                'Get Oasis Pro to enjoy an ad-free experience, unlimited time capsules, advanced analytics, and more.',
            timestamp: DateTime.now(),
            isAd: true,
          ),
        );
      }
    }
    return feedWithAds;
  }
}
