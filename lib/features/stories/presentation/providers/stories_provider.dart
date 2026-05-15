import 'package:flutter/foundation.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/stories/domain/repositories/stories_repository.dart';
import 'package:oasis/features/stories/data/repositories/stories_repository_impl.dart';
import 'package:oasis/features/stories/presentation/providers/stories_state.dart';

/// Provider for stories feature - manages UI state.
class StoriesProvider extends ChangeNotifier {
  final StoriesRepository _repository;

  StoriesState _state = const StoriesState();

  StoriesProvider({StoriesRepository? repository})
    : _repository = repository ?? StoriesRepositoryImpl();

  // Getters
  List<StoryGroupEntity> get storyGroups => _state.storyGroups;
  List<StoryEntity> get userStories => _state.userStories;
  bool get isLoading => _state.isLoading;
  String? get error => _state.error;
  String? get currentStoryId => _state.currentStoryId;

  /// Load stories from followed users.
  Future<void> loadFollowingStories() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final storyGroups = await _repository.getFollowingStories();
      _state = _state.copyWith(storyGroups: storyGroups, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  /// Load stories for a specific user.
  Future<void> loadUserStories(String userId) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final userStories = await _repository.getUserStories(userId);
      _state = _state.copyWith(userStories: userStories, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  /// Load current user's own stories.
  Future<void> loadMyStories() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final userStories = await _repository.getMyStories();
      _state = _state.copyWith(userStories: userStories, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }
    notifyListeners();
  }

  /// Create a new story.
  Future<StoryEntity?> createStory({
    required String mediaUrl,
    required String mediaType,
    String? thumbnailUrl,
    String? caption,
    int duration = 5,
  }) async {
    try {
      final story = await _repository.createStory(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        duration: duration,
      );
      // Refresh stories after creation
      await loadMyStories();
      return story;
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
      return null;
    }
  }

  /// Mark story as viewed.
  Future<void> viewStory(String storyId) async {
    await _repository.viewStory(storyId);
    // Update local state to mark as viewed
    _updateStoryAsViewed(storyId);
  }

  void _updateStoryAsViewed(String storyId) {
    // Update in story groups
    final updatedGroups = _state.storyGroups.map((group) {
      final updatedStories = group.stories.map((story) {
        if (story.id == storyId) {
          return story.copyWith(hasViewed: true);
        }
        return story;
      }).toList();
      return StoryGroupEntity(
        userId: group.userId,
        username: group.username,
        avatarUrl: group.avatarUrl,
        stories: updatedStories,
        hasUnviewed: updatedStories.any((s) => !s.hasViewed),
        latestStoryAt: group.latestStoryAt,
      );
    }).toList();

    _state = _state.copyWith(storyGroups: updatedGroups);
    notifyListeners();
  }

  /// Get story viewers.
  Future<List<StoryViewerEntity>> getStoryViewers(String storyId) async {
    return _repository.getStoryViewers(storyId);
  }

  /// React to a story.
  Future<void> reactToStory(String storyId, String emoji) async {
    await _repository.reactToStory(storyId, emoji);
  }

  /// Remove reaction from a story.
  Future<void> removeReaction(String storyId) async {
    await _repository.removeReaction(storyId);
  }

  /// Delete a story.
  Future<bool> deleteStory(String storyId) async {
    final result = await _repository.deleteStory(storyId);
    if (result) {
      // Remove from local state
      final updatedStories = _state.userStories
          .where((s) => s.id != storyId)
          .toList();
      _state = _state.copyWith(userStories: updatedStories);
      notifyListeners();
    }
    return result;
  }

  /// Clean up expired stories.
  Future<void> cleanupExpiredStories() async {
    await _repository.cleanupExpiredStories();
  }
}
