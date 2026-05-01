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
    
    final offset = refresh ? 0 : _state.circleFeed.length;
    _state = _state.copyWith(isLoadingFeed: true);
    if (refresh) notifyListeners();

    try {
      final posts = await _repository.getCircleFeed(
        circleId: circleId,
        userId: userId,
        limit: 20,
        offset: offset,
      );

      final newList = refresh ? posts : [..._state.circleFeed, ...posts];
      _state = _state.copyWith(
        circleFeed: newList,
        hasMoreFeed: posts.length == 20,
      );
    } catch (e) {
      debugPrint('[CircleProvider] loadCircleFeed error: $e');
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
  }) async {
    try {
      final post = await _repository.createCirclePost(
        circleId: circleId,
        userId: userId,
        content: content,
        mediaUrls: mediaUrls,
        mediaTypes: mediaTypes,
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
    _state = _state.copyWith(isLoading: true);
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

  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  void clear() {
    _state = const CircleState();
    notifyListeners();
  }
}
