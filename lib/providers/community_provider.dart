import 'package:flutter/foundation.dart';
import 'package:oasis/models/community.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/services/community_service.dart';
import 'package:oasis/services/post_service.dart';
import 'package:oasis/services/feed_service.dart';
import 'package:oasis/core/providers/safe_change_notifier.dart';

class CommunityProvider with ChangeNotifier, SafeChangeNotifier {
  final CommunityService _communityService = CommunityService();
  final FeedService _feedService = FeedService();
  final PostService _postService = PostService();

  List<Community> _allCommunities = [];
  List<Community> _userCommunities = [];
  Community? _selectedCommunity;
  bool _isLoading = false;
  bool _isMember = false;
  String? _error;

  // Getters
  List<Community> get allCommunities => _allCommunities;
  List<Community> get userCommunities => _userCommunities;
  Community? get selectedCommunity => _selectedCommunity;
  bool get isLoading => _isLoading;
  bool get isMember => _isMember;
  String? get error => _error;

  /// Load all communities
  Future<void> loadAllCommunities() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allCommunities = await _communityService.getCommunities();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading communities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user's communities
  Future<void> loadUserCommunities(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userCommunities = await _communityService.getUserCommunities(
        userId: userId,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading user communities: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load a specific community
  Future<void> loadCommunity(String communityId, String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedCommunity = await _communityService.getCommunity(communityId);
      _isMember = await _communityService.isMember(
        userId: userId,
        communityId: communityId,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading community: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a community
  Future<Community> createCommunity({
    required String creatorId,
    required String name,
    required String description,
    String? rules,
    bool isPrivate = false,
  }) async {
    try {
      final community = await _communityService.createCommunity(
        creatorId: creatorId,
        name: name,
        description: description,
        rules: rules,
        isPrivate: isPrivate,
      );

      // Add to user communities and all communities
      _userCommunities.insert(0, community);
      _allCommunities.insert(0, community);
      notifyListeners();

      return community;
    } catch (e) {
      debugPrint('Error creating community: $e');
      rethrow;
    }
  }

  /// Join a community
  Future<void> joinCommunity({
    required String userId,
    required String communityId,
  }) async {
    try {
      // Optimistic update
      _isMember = true;
      if (_selectedCommunity != null) {
        _selectedCommunity = _selectedCommunity!.copyWith(
          membersCount: _selectedCommunity!.membersCount + 1,
        );
      }
      notifyListeners();

      await _communityService.joinCommunity(
        userId: userId,
        communityId: communityId,
      );

      // Reload user communities
      await loadUserCommunities(userId);
    } catch (e) {
      // Revert on error
      _isMember = false;
      if (_selectedCommunity != null) {
        _selectedCommunity = _selectedCommunity!.copyWith(
          membersCount: _selectedCommunity!.membersCount - 1,
        );
      }
      notifyListeners();
      debugPrint('Error joining community: $e');
      rethrow;
    }
  }

  /// Leave a community
  Future<void> leaveCommunity({
    required String userId,
    required String communityId,
  }) async {
    try {
      // Optimistic update
      _isMember = false;
      if (_selectedCommunity != null) {
        _selectedCommunity = _selectedCommunity!.copyWith(
          membersCount: _selectedCommunity!.membersCount - 1,
        );
      }
      notifyListeners();

      await _communityService.leaveCommunity(
        userId: userId,
        communityId: communityId,
      );

      // Remove from user communities
      _userCommunities.removeWhere((c) => c.id == communityId);
      notifyListeners();
    } catch (e) {
      // Revert on error
      _isMember = true;
      if (_selectedCommunity != null) {
        _selectedCommunity = _selectedCommunity!.copyWith(
          membersCount: _selectedCommunity!.membersCount + 1,
        );
      }
      notifyListeners();
      debugPrint('Error leaving community: $e');
      rethrow;
    }
  }

  /// Search communities
  Future<List<Community>> searchCommunities(String query) async {
    try {
      return await _communityService.searchCommunities(query: query);
    } catch (e) {
      debugPrint('Error searching communities: $e');
      rethrow;
    }
  }

  /// Update community
  Future<void> updateCommunity({
    required String communityId,
    required String userId,
    String? name,
    String? description,
    String? rules,
    bool? isPrivate,
  }) async {
    try {
      _selectedCommunity = await _communityService.updateCommunity(
        communityId: communityId,
        userId: userId,
        name: name,
        description: description,
        rules: rules,
        isPrivate: isPrivate,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating community: $e');
      rethrow;
    }
  }

  /// Delete community
  Future<void> deleteCommunity({
    required String communityId,
    required String userId,
  }) async {
    try {
      await _communityService.deleteCommunity(
        communityId: communityId,
        userId: userId,
      );

      // Remove from lists
      _allCommunities.removeWhere((c) => c.id == communityId);
      _userCommunities.removeWhere((c) => c.id == communityId);
      if (_selectedCommunity?.id == communityId) {
        _selectedCommunity = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting community: $e');
      rethrow;
    }
  }

  /// Clear selected community
  void clearSelectedCommunity() {
    _selectedCommunity = null;
    _isMember = false;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _allCommunities = [];
    _userCommunities = [];
    _selectedCommunity = null;
    _isLoading = false;
    _isMember = false;
    _error = null;
    notifyListeners();
  }

  List<Post> _communityPosts = [];
  List<Post> get communityPosts => _communityPosts;

  /// Load community posts
  Future<void> loadCommunityPosts(String communityId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // We need an instance of PostService here.
      // Ideally it should be injected or instantiated.
      // Since CommunityProvider currently only has CommunityService, let's instantiate PostService locally or add it.
      final postService =
          PostService(); // Using specific import aliasing if needed, but standard import should work
      _communityPosts = await postService.getCommunityPosts(
        communityId: communityId,
      );
    } catch (e) {
      debugPrint('Error loading community posts: $e');
      // Don't set global error for posts failure to allow community info to show
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Like a post
  Future<void> likePost({
    required String userId,
    required String postId,
  }) async {
    try {
      _updatePostLikeStatus(postId, true);
      notifyListeners();
      await _feedService.likePost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostLikeStatus(postId, false);
      notifyListeners();
      debugPrint('Error liking post: $e');
    }
  }

  /// Unlike a post
  Future<void> unlikePost({
    required String userId,
    required String postId,
  }) async {
    try {
      _updatePostLikeStatus(postId, false);
      notifyListeners();
      await _feedService.unlikePost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostLikeStatus(postId, true);
      notifyListeners();
      debugPrint('Error unliking post: $e');
    }
  }

  /// Bookmark a post
  Future<void> bookmarkPost({
    required String userId,
    required String postId,
  }) async {
    try {
      _updatePostBookmarkStatus(postId, true);
      notifyListeners();
      await _feedService.bookmarkPost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostBookmarkStatus(postId, false);
      notifyListeners();
      debugPrint('Error bookmarking post: $e');
    }
  }

  /// Remove bookmark
  Future<void> unbookmarkPost({
    required String userId,
    required String postId,
  }) async {
    try {
      _updatePostBookmarkStatus(postId, false);
      notifyListeners();
      await _feedService.unbookmarkPost(userId: userId, postId: postId);
    } catch (e) {
      _updatePostBookmarkStatus(postId, true);
      notifyListeners();
      debugPrint('Error removing bookmark: $e');
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    try {
      // In a real app, you'd verify ownership or have backend RLS handle it
      // For now, assume current user is owner if they can trigger this
      await _postService.deletePost(postId, ''); // userId dummy
      _communityPosts.removeWhere((p) => p.id == postId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  void _updatePostLikeStatus(String postId, bool isLiked) {
    for (int i = 0; i < _communityPosts.length; i++) {
      if (_communityPosts[i].id == postId) {
        final post = _communityPosts[i];
        if (post.isLiked == isLiked) return;

        int newLikes = isLiked ? post.likes + 1 : post.likes - 1;
        if (newLikes < 0) newLikes = 0;

        _communityPosts[i] = post.copyWith(isLiked: isLiked, likes: newLikes);
        break;
      }
    }
  }

  void _updatePostBookmarkStatus(String postId, bool isBookmarked) {
    for (int i = 0; i < _communityPosts.length; i++) {
      if (_communityPosts[i].id == postId) {
        _communityPosts[i] = _communityPosts[i].copyWith(
          isBookmarked: isBookmarked,
        );
        break;
      }
    }
  }
}
