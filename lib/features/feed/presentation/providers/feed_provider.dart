import 'package:flutter/foundation.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/domain/models/comment.dart';
import 'package:oasis/features/feed/domain/repositories/feed_repository.dart';
import 'package:oasis/features/feed/domain/repositories/post_repository.dart';
import 'package:oasis/features/feed/domain/repositories/comment_repository.dart';
import 'package:oasis/features/feed/data/datasources/feed_local_datasource.dart';
import 'package:oasis/features/feed/presentation/providers/feed_state.dart';
import 'package:oasis/services/ad_service.dart';
import 'package:oasis/services/subscription_service.dart';
import 'package:oasis/services/curation_tracking_service.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

export 'package:oasis/features/feed/presentation/providers/feed_state.dart'
    show FeedType;

/// Feed feature provider managing unified feed state, posts, and comments.
class FeedProvider with ChangeNotifier, SafeChangeNotifier {
  final FeedRepository _feedRepository;
  final PostRepository _postRepository;
  final CommentRepository _commentRepository;
  final FeedLocalDatasource _localDatasource;
  final AdService _adService;
  final SubscriptionService _subscriptionService;
  final CurationTrackingService _curationTrackingService;

  FeedState _state = const FeedState();
  FeedState get state => _state;

  // Proxy getters for convenience
  List<Post> get posts => _state.posts;
  bool get isLoading => _state.isLoading;
  bool get isLoadingMore => _state.isLoadingMore;
  bool get hasMore => _state.hasMore;
  String? get error => _state.error;

  FeedProvider({
    required FeedRepository feedRepository,
    required PostRepository postRepository,
    required CommentRepository commentRepository,
    FeedLocalDatasource? localDatasource,
    AdService? adService,
    SubscriptionService? subscriptionService,
    CurationTrackingService? curationTrackingService,
  }) : _feedRepository = feedRepository,
       _postRepository = postRepository,
       _commentRepository = commentRepository,
       _localDatasource = localDatasource ?? FeedLocalDatasource(),
       _adService = adService ?? AdService(),
       _subscriptionService = subscriptionService ?? SubscriptionService(),
       _curationTrackingService =
           curationTrackingService ?? CurationTrackingService() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await _localDatasource.getFeed();
      if (cached.isNotEmpty) {
        final cachedPosts = cached.map((e) => Post.fromJson(e)).toList();
        _state = _state.copyWith(
          posts: cachedPosts,
          cursor: cachedPosts.isNotEmpty
              ? cachedPosts.last.timestamp.toIso8601String()
              : null,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FeedProvider] Cache load error: $e');
    }
  }

  // ─── Feed Operations ──────────────────────────────────────────────

  /// Load initial unified feed.
  Future<void> loadFeed({required String userId, bool refresh = false}) async {
    if (isDisposed || _state.isLoading) return;

    _state = _state.copyWith(isLoading: true, error: null);
    if (refresh) {
      _state = _state.copyWith(cursor: null, hasMore: true);
    }
    notifyListeners();

    try {
      final effectiveCursor = refresh ? null : _state.cursor;
      List<Post> newPosts = await _feedRepository.getUnifiedFeed(
        userId: userId,
        limit: 20,
        cursor: effectiveCursor,
      );
      if (isDisposed) return;

      newPosts = await _injectAds(newPosts);
      if (isDisposed) return;

      if (refresh || _state.posts.isEmpty) {
        _state = _state.copyWith(posts: newPosts);
        _localDatasource.saveFeed(newPosts.map((e) => e.toJson()).toList());
      } else {
        final existingIds = _state.posts.map((p) => p.id).toSet();
        final uniqueNewPosts = newPosts
            .where((p) => !existingIds.contains(p.id))
            .toList();

        _state = _state.copyWith(posts: [..._state.posts, ...uniqueNewPosts]);
      }

      // Filter out ad posts when determining the cursor for database pagination
      final realPosts = _state.posts.where((p) => !p.isAd).toList();

      _state = _state.copyWith(
        cursor: realPosts.isNotEmpty
            ? realPosts.last.timestamp.toIso8601String()
            : null,
        hasMore: newPosts.length >= 20,
      );
      // Track category for curation
      _trackCategories(newPosts);
    } catch (e) {
      if (isDisposed) return;
      _state = _state.copyWith(error: e.toString());
      debugPrint('[FeedProvider] Load feed error: $e');
    } finally {
      if (!isDisposed) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
      }
    }
  }

  /// Load more posts (pagination).
  Future<void> loadMore({required String userId}) async {
    if (isDisposed || _state.isLoadingMore || !_state.hasMore || _state.isLoading) return;

    _state = _state.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      List<Post> newPosts = await _feedRepository.getUnifiedFeed(
        userId: userId,
        limit: 20,
        cursor: _state.cursor,
      );
      if (isDisposed) return;
      
      newPosts = await _injectAds(newPosts);
      if (isDisposed) return;

      final updatedPosts = [..._state.posts, ...newPosts];
      final realPosts = updatedPosts.where((p) => !p.isAd).toList();

      _state = _state.copyWith(
        posts: updatedPosts,
        cursor: realPosts.isNotEmpty
            ? realPosts.last.timestamp.toIso8601String()
            : null,
        hasMore: newPosts.length >= 20,
      );
    } catch (e) {
      if (isDisposed) return;
      _state = _state.copyWith(error: e.toString());
      debugPrint('[FeedProvider] Load more error: $e');
    } finally {
      if (!isDisposed) {
        _state = _state.copyWith(isLoadingMore: false);
        notifyListeners();
      }
    }
  }

  /// Refresh feed.
  Future<void> refresh({required String userId}) async {
    return loadFeed(userId: userId, refresh: true);
  }

  Future<List<Post>> _injectAds(List<Post> posts) async {
    if (_subscriptionService.isPro) return posts;

    final ads = await _adService.getHouseAds();
    if (ads.isEmpty) return posts;

    final List<Post> result = [];
    int adIndex = 0;
    for (int i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      if ((i + 1) % 5 == 0 && adIndex < ads.length) {
        result.add(ads[adIndex]);
        adIndex++;
      }
    }
    return result;
  }

  // ─── Post Operations ──────────────────────────────────────────────

  Future<void> likePost({
    required String userId,
    required String postId,
    String? communityName,
  }) async {
    _updatePostLikeStatus(postId, true);
    notifyListeners();
    _localDatasource.saveFeed(_state.posts.map((e) => e.toJson()).toList());

    if (communityName != null && communityName.isNotEmpty) {
      _trackPostLike(postId, communityName);
    }

    try {
      await _postRepository.likePost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostLikeStatus(postId, false);
      notifyListeners();
      debugPrint('[FeedProvider] Like post error: $e');
      rethrow;
    }
  }

  Future<void> unlikePost({
    required String userId,
    required String postId,
  }) async {
    _updatePostLikeStatus(postId, false);
    notifyListeners();
    _localDatasource.saveFeed(_state.posts.map((e) => e.toJson()).toList());

    try {
      await _postRepository.unlikePost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostLikeStatus(postId, true);
      notifyListeners();
      debugPrint('[FeedProvider] Unlike post error: $e');
      rethrow;
    }
  }

  Future<void> bookmarkPost({
    required String userId,
    required String postId,
  }) async {
    _updatePostBookmarkStatus(postId, true);
    notifyListeners();
    try {
      await _postRepository.bookmarkPost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostBookmarkStatus(postId, false);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unbookmarkPost({
    required String userId,
    required String postId,
  }) async {
    _updatePostBookmarkStatus(postId, false);
    notifyListeners();
    try {
      await _postRepository.unbookmarkPost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostBookmarkStatus(postId, true);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _postRepository.deletePost(postId, '');
      _state = _state.copyWith(
        posts: _state.posts.where((p) => p.id != postId).toList(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[FeedProvider] Delete post error: $e');
      rethrow;
    }
  }

  void addPost(Post post) {
    _state = _state.copyWith(posts: [post, ..._state.posts]);
    notifyListeners();
  }

  void updatePost(Post updatedPost) {
    _state = _state.copyWith(
      posts: _state.posts
          .map((p) => p.id == updatedPost.id ? updatedPost : p)
          .toList(),
    );
    notifyListeners();
  }

  Future<void> voteInPoll({
    required String userId,
    required String postId,
    required String pollId,
    required String optionId,
  }) async {
    _updatePostPollStatus(postId, optionId, true);
    notifyListeners();

    try {
      await _postRepository.voteInPoll(
        userId: userId,
        pollId: pollId,
        optionId: optionId,
      );
    } catch (e) {
      _updatePostPollStatus(postId, optionId, false);
      notifyListeners();
      rethrow;
    }
  }

  void incrementCommentCount(String postId) {
    final newPosts = List<Post>.from(_state.posts);
    for (int i = 0; i < newPosts.length; i++) {
      if (newPosts[i].id == postId) {
        final post = newPosts[i];
        newPosts[i] = post.copyWith(comments: post.comments + 1);
        break;
      }
    }
    _state = _state.copyWith(posts: newPosts);
    notifyListeners();
  }

  void clear() {
    _state = const FeedState();
    notifyListeners();
  }

  // ─── Comment Operations ───────────────────────────────────────────

  Future<List<Comment>> getComments({
    required String postId,
    required String currentUserId,
    int limit = 50,
  }) async {
    return _commentRepository.getPostComments(
      postId: postId,
      currentUserId: currentUserId,
      limit: limit,
    );
  }

  Future<Comment> createComment({
    required String userId,
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    return _commentRepository.createComment(
      userId: userId,
      postId: postId,
      content: content,
      parentCommentId: parentCommentId,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _updatePostLikeStatus(String postId, bool isLiked) {
    final newPosts = List<Post>.from(_state.posts);
    for (int i = 0; i < newPosts.length; i++) {
      if (newPosts[i].id == postId) {
        final post = newPosts[i];
        if (post.isLiked == isLiked) return;
        int newLikes = isLiked ? post.likes + 1 : post.likes - 1;
        newPosts[i] = post.copyWith(
          isLiked: isLiked,
          likes: newLikes < 0 ? 0 : newLikes,
        );
        break;
      }
    }
    _state = _state.copyWith(posts: newPosts);
  }

  void _updatePostBookmarkStatus(String postId, bool isBookmarked) {
    final newPosts = List<Post>.from(_state.posts);
    for (int i = 0; i < newPosts.length; i++) {
      if (newPosts[i].id == postId) {
        newPosts[i] = newPosts[i].copyWith(isBookmarked: isBookmarked);
        break;
      }
    }
    _state = _state.copyWith(posts: newPosts);
  }

  void _updatePostPollStatus(String postId, String optionId, bool hasVoted) {
    final newPosts = List<Post>.from(_state.posts);
    for (int i = 0; i < newPosts.length; i++) {
      if (newPosts[i].id == postId) {
        final post = newPosts[i];
        final poll = post.poll;
        if (poll == null) return;

        final updatedOptions = poll.options.map((opt) {
          if (opt.id == optionId) {
            final newVoteCount = hasVoted
                ? opt.voteCount + 1
                : opt.voteCount - 1;
            return opt.copyWith(voteCount: newVoteCount < 0 ? 0 : newVoteCount);
          }
          return opt;
        }).toList();

        final totalVotes = updatedOptions.fold<int>(
          0,
          (sum, opt) => sum + opt.voteCount,
        );

        final finalizedOptions = updatedOptions.map((opt) {
          return opt.copyWith(
            percentage: totalVotes > 0 ? (opt.voteCount / totalVotes) * 100 : 0,
          );
        }).toList();

        newPosts[i] = post.copyWith(
          poll: poll.copyWith(
            options: finalizedOptions,
            totalVotes: totalVotes,
            hasVoted: hasVoted,
            userVotedOptionId: hasVoted ? optionId : null,
          ),
        );
        break;
      }
    }
    _state = _state.copyWith(posts: newPosts);
  }

  // ─── Curation Tracking ──────────────────────────────────────────────

  Future<void> _trackCategories(List<Post> posts) async {
    if (posts.isEmpty) return;

    final categories = <String>{};
    final hashtags = <String>{};
    for (final post in posts) {
      if (post.communityName != null && post.communityName!.isNotEmpty) {
        categories.add(post.communityName!.toLowerCase());
      }
      for (final tag in post.hashtags) {
        hashtags.add(tag.toLowerCase());
      }
    }

    for (final category in categories) {
      try {
        await _curationTrackingService.trackCategoryInteraction(category);
      } catch (e) {
        debugPrint('[FeedProvider] Category tracking error: $e');
      }
    }

    for (final tag in hashtags) {
      try {
        await _curationTrackingService.trackCategoryInteraction(tag, weight: 1);
      } catch (e) {
        debugPrint('[FeedProvider] Hashtag tracking error: $e');
      }
    }
  }

  Future<void> _trackPostLike(String postId, String communityName) async {
    final category = communityName.toLowerCase();
    if (category.isEmpty) return;

    try {
      await _curationTrackingService.trackPostLike(category, postId);
    } catch (e) {
      debugPrint('[FeedProvider] Post like tracking error: $e');
    }
  }

  /// Updates comment count for a post in the local state.
  void updatePostCommentCount(String postId, int newCount) {
    final updatedPosts = _state.posts.map<Post>((post) {
      if (post.id == postId) {
        return post.copyWith(comments: newCount);
      }
      return post;
    }).toList();
    _state = _state.copyWith(posts: updatedPosts);
    notifyListeners();
  }
}
