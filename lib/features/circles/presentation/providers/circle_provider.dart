import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:oasis/features/circles/domain/repositories/circle_repository.dart';
import 'package:oasis/features/circles/presentation/providers/circle_state.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

export 'package:oasis/features/circles/presentation/providers/circle_state.dart';

class CircleProvider with ChangeNotifier {
  final CircleRepository _repository;

  CircleState _state = const CircleState();
  CircleState get state => _state;

  List<CircleEntity> get circles => _state.circles;
  CircleEntity? get activeCircle => _state.activeCircle;
  List<Post> get circleFeed => _state.circleFeed;
  bool get isLoading => _state.isLoading;
  bool get isLoadingFeed => _state.isLoadingFeed;
  bool get hasMoreFeed => _state.hasMoreFeed;
  String? get error => _state.error;

  CircleProvider({required CircleRepository repository})
    : _repository = repository;

  Future<void> loadCircleFeed(String circleId, String userId, {bool refresh = false}) async {
    if (_state.isLoadingFeed) return;
    
    // If we are loading a different circle than what's in the state, force a clear
    final isDifferentCircle = _state.activeCircle?.id != circleId;
    final effectiveRefresh = refresh || isDifferentCircle;

    // Preserve existing posts on refresh ONLY if it's the same circle
    final existingPosts = (!isDifferentCircle && refresh) ? List<Post>.from(_state.circleFeed) : <Post>[];
    final offset = effectiveRefresh ? 0 : _state.circleFeed.length;
    
    _state = _state.copyWith(
      isLoadingFeed: true,
      circleFeed: effectiveRefresh ? [] : _state.circleFeed,
    );
    if (effectiveRefresh) notifyListeners();

    try {
      final posts = await _repository.getCircleFeed(
        circleId: circleId,
        userId: userId,
        limit: 20,
        offset: offset,
      );

      // If refresh returned empty and it's the SAME circle, we might want to keep existing posts
      // but if it's a DIFFERENT circle, empty means empty.
      final List<Post> newList;
      if (effectiveRefresh) {
        if (posts.isEmpty && !isDifferentCircle) {
          newList = existingPosts;
        } else {
          newList = posts;
        }
      } else {
        newList = [..._state.circleFeed, ...posts];
      }
          
      _state = _state.copyWith(
        circleFeed: newList,
        hasMoreFeed: posts.length == 20,
      );
      
      debugPrint('[CircleProvider] loadCircleFeed: circleId=$circleId, refresh=$effectiveRefresh, fetched=${posts.length}, total=${newList.length}');
    } catch (e) {
      debugPrint('[CircleProvider] loadCircleFeed error: $e');
      if (effectiveRefresh && !isDifferentCircle && existingPosts.isNotEmpty) {
        _state = _state.copyWith(circleFeed: existingPosts);
      }
    } finally {
      _state = _state.copyWith(isLoadingFeed: false);
      notifyListeners();
    }
  }

  Future<void> createCirclePost({
    required String circleId,
    required String userId,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    String? mood,
    List<String> hashtags = const [],
    bool isSpoiler = false,
    Map<String, dynamic>? poll,
  }) async {
    try {
      final post = await _repository.createCirclePost(
        circleId: circleId,
        userId: userId,
        content: content,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
        mood: mood,
        hashtags: hashtags,
        isSpoiler: isSpoiler,
        poll: poll,
      );
      
      _state = _state.copyWith(
        circleFeed: [post, ..._state.circleFeed],
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[CircleProvider] createCirclePost error: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final index = _state.circleFeed.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _state.circleFeed[index];
    final isLiked = post.isLiked;
    final newLikes = isLiked ? post.likes - 1 : post.likes + 1;
    
    final updatedPost = post.copyWith(
      isLiked: !isLiked,
      likes: newLikes < 0 ? 0 : newLikes,
    );

    final newList = List<Post>.from(_state.circleFeed);
    newList[index] = updatedPost;
    _state = _state.copyWith(circleFeed: newList);
    notifyListeners();

    try {
       // Since liking is global, we might need a post repository or similar.
       // However, for now we've updated the UI state.
    } catch (e) {
      debugPrint('[CircleProvider] toggleLike error: $e');
    }
  }

  Future<void> addCommitment({
    required String createdBy,
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    if (_state.activeCircle == null) return;
    
    try {
      final commitment = await _repository.createCommitment(
        circleId: _state.activeCircle!.id,
        createdBy: createdBy,
        title: title,
        description: description,
        dueDate: dueDate,
      );
      // You might want to update local state here if you have a list of commitments
      notifyListeners();
    } catch (e) {
      debugPrint('[CircleProvider] addCommitment error: $e');
      rethrow;
    }
  }

  Future<void> loadCircles(String userId, {bool forceRefresh = false}) async {
    if (_state.circles.isNotEmpty && !forceRefresh) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final circles = await _repository.getCircles(userId);
      _state = _state.copyWith(circles: circles);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[CircleProvider] Error loading circles: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<CircleEntity?> createCircle({
    required String createdBy,
    required String name,
    required String emoji,
    required List<String> memberIds,
  }) async {
    try {
      final circle = await _repository.createCircle(
        createdBy: createdBy,
        name: name,
        emoji: emoji,
        memberIds: memberIds,
      );
      _state = _state.copyWith(circles: [circle, ..._state.circles]);
      notifyListeners();
      return circle;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  Future<CircleEntity> getCircle(String circleId) async {
    return _repository.getCircle(circleId);
  }

  Future<void> joinCircle(String circleId, String userId) async {
    await _repository.joinCircle(circleId, userId);
  }

  Future<void> setActiveCircle(String circleId, String userId) async {
    _state = _state.copyWith(
      isLoading: true,
      circleFeed: [], // Clear feed when switching circles
    );
    notifyListeners();

    try {
      CircleEntity? circle;
      try {
        circle = _state.circles.firstWhere((c) => c.id == circleId);
      } catch (_) {
        circle = await _repository.getCircle(circleId);
      }
      _state = _state.copyWith(activeCircle: circle);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[CircleProvider] Error setting active circle: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  void closeCircle() {
    _state = _state.copyWith(activeCircle: null);
    notifyListeners();
  }

  Future<void> deleteCircle(String circleId) async {
    try {
      await _repository.deleteCircle(circleId);
      _state = _state.copyWith(
        circles: _state.circles.where((c) => c.id != circleId).toList(),
      );
      if (_state.activeCircle?.id == circleId) {
        _state = _state.copyWith(activeCircle: null);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CircleProvider] Error deleting circle: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId, String userId) async {
    final index = _state.circleFeed.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _state.circleFeed[index];
    if (post.userId != userId) {
      throw Exception('Not authorized to delete this post');
    }

    // Update local state immediately for responsiveness
    final newList = List<Post>.from(_state.circleFeed);
    newList.removeAt(index);
    _state = _state.copyWith(circleFeed: newList);
    notifyListeners();

    try {
      // Use the repository to delete the post from Supabase
      // Note: We need to make sure the repository/datasource supports this.
      // Assuming we can use the same deletePost logic.
      // If CircleRepository doesn't have it, we might need to inject PostRepository
      // but for now, let's assume we add it to CircleRepository or call it directly.
      await _repository.deletePost(postId, userId);
    } catch (e) {
      debugPrint('[CircleProvider] deletePost error: $e');
      // Rollback on failure
      loadCircleFeed(post.circleId!, userId, refresh: true);
      rethrow;
    }
  }

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  void clear() {
    _state = const CircleState();
    notifyListeners();
  }
}
