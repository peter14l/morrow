import 'package:flutter/foundation.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import 'package:oasis/features/profile/domain/repositories/profile_repository.dart';
import 'package:oasis/features/profile/presentation/providers/profile_state.dart';
import 'package:oasis/features/feed/domain/repositories/post_repository.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart';
import 'package:oasis/features/ripples/domain/repositories/ripple_repository.dart';

export 'package:oasis/features/profile/presentation/providers/profile_state.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileRepository _profileRepository;
  final PostRepository _postRepository;
  final RippleRepository _rippleRepository;
  final MessagingService _messagingService = MessagingService();

  ProfileState _state = const ProfileState();
  ProfileState get state => _state;

  UserProfileEntity? get currentProfile => _state.currentProfile;
  UserProfileEntity? get viewedProfile => _state.viewedProfile;
  List<UserProfileEntity> get followers => _state.followers;
  List<UserProfileEntity> get following => _state.following;
  bool get isLoading => _state.isLoading;
  bool get isLoadingFollowing => _state.isLoading;
  bool get isFollowing => _state.isFollowing;
  String? get error => _state.error;

  ProfileProvider({
    required ProfileRepository profileRepository,
    required PostRepository postRepository,
    required RippleRepository rippleRepository,
  }) : _profileRepository = profileRepository,
       _postRepository = postRepository,
       _rippleRepository = rippleRepository;

  Future<void> loadCurrentProfile(String userId) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final profile = await _profileRepository.getProfile(userId);
      _state = _state.copyWith(currentProfile: profile);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[ProfileProvider] Error loading current profile: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> loadProfile(String userId, String currentUserId) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final profile = await _profileRepository.getProfile(userId);
      _state = _state.copyWith(viewedProfile: profile);

      if (userId != currentUserId) {
        final following = await _profileRepository.isFollowing(
          followerId: currentUserId,
          followingId: userId,
        );
        _state = _state.copyWith(isFollowing: following);
      }
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[ProfileProvider] Error loading profile: $e');
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    String? location,
    String? website,
    String? bannerColor,
    String? avatarFilePath,
    String? bannerFilePath,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final profile = await _profileRepository.updateProfile(
        userId: userId,
        username: username,
        fullName: fullName,
        bio: bio,
        location: location,
        website: website,
        bannerColor: bannerColor,
        avatarFilePath: avatarFilePath,
        bannerFilePath: bannerFilePath,
      );
      _state = _state.copyWith(currentProfile: profile);
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[ProfileProvider] Error updating profile: $e');
      rethrow;
    } finally {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
    }
  }

  Future<void> followUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final isPrivate = _state.viewedProfile?.isPrivate ?? false;
      
      if (isPrivate) {
        _state = _state.copyWith(hasSentRequest: true);
        notifyListeners();
        
        await _profileRepository.sendFollowRequest(
          followerId: followerId,
          followingId: followingId,
        );
        return;
      }

      _state = _state.copyWith(isFollowing: true);
      if (_state.viewedProfile != null) {
        _state = _state.copyWith(
          viewedProfile: _state.viewedProfile!.copyWith(
            followersCount: _state.viewedProfile!.followersCount + 1,
          ),
        );
      }
      if (!_state.following.any((p) => p.id == followingId)) {
        _state = _state.copyWith(
          following: [
            ..._state.following,
            UserProfileEntity(
              id: followingId,
              username: '',
              email: '',
              createdAt: DateTime.now(),
            ),
          ],
        );
      }
      notifyListeners();

      await _profileRepository.followUser(
        followerId: followerId,
        followingId: followingId,
      );
    } catch (e) {
      if (_state.viewedProfile?.isPrivate ?? false) {
        _state = _state.copyWith(hasSentRequest: false);
      } else {
        _state = _state.copyWith(isFollowing: false);
        if (_state.viewedProfile != null) {
          _state = _state.copyWith(
            viewedProfile: _state.viewedProfile!.copyWith(
              followersCount: _state.viewedProfile!.followersCount - 1,
            ),
          );
        }
      }
      notifyListeners();
      debugPrint('[ProfileProvider] Error following user: $e');
      rethrow;
    }
  }

  Future<void> acceptFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _profileRepository.acceptFollowRequest(
        followerId: followerId,
        followingId: followingId,
      );
    } catch (e) {
      debugPrint('[ProfileProvider] Error accepting follow request: $e');
      rethrow;
    }
  }

  Future<void> declineFollowRequest({
    required String followerId,
    required String followingId,
  }) async {
    try {
      await _profileRepository.declineFollowRequest(
        followerId: followerId,
        followingId: followingId,
      );
    } catch (e) {
      debugPrint('[ProfileProvider] Error declining follow request: $e');
      rethrow;
    }
  }

  Future<void> checkFollowRequestStatus({
    required String followerId,
    required String followingId,
  }) async {
    try {
      final hasSent = await _profileRepository.hasSentFollowRequest(
        followerId: followerId,
        followingId: followingId,
      );
      _state = _state.copyWith(hasSentRequest: hasSent);
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileProvider] Error checking follow request status: $e');
    }
  }

  Future<void> unfollowUser({
    required String followerId,
    required String followingId,
  }) async {
    try {
      _state = _state.copyWith(isFollowing: false);
      if (_state.viewedProfile != null) {
        _state = _state.copyWith(
          viewedProfile: _state.viewedProfile!.copyWith(
            followersCount: _state.viewedProfile!.followersCount - 1,
          ),
        );
      }
      _state = _state.copyWith(
        following: _state.following.where((p) => p.id != followingId).toList(),
      );
      notifyListeners();

      await _profileRepository.unfollowUser(
        followerId: followerId,
        followingId: followingId,
      );
    } catch (e) {
      _state = _state.copyWith(isFollowing: true);
      if (_state.viewedProfile != null) {
        _state = _state.copyWith(
          viewedProfile: _state.viewedProfile!.copyWith(
            followersCount: _state.viewedProfile!.followersCount + 1,
          ),
        );
      }
      notifyListeners();
      debugPrint('[ProfileProvider] Error unfollowing user: $e');
      rethrow;
    }
  }

  Future<void> loadFollowers(String userId) async {
    try {
      final followers = await _profileRepository.getFollowers(userId: userId);
      _state = _state.copyWith(followers: followers);
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileProvider] Error loading followers: $e');
      rethrow;
    }
  }

  Future<void> loadFollowing(String userId) async {
    try {
      final following = await _profileRepository.getFollowing(userId: userId);
      _state = _state.copyWith(following: following);
      notifyListeners();
    } catch (e) {
      debugPrint('[ProfileProvider] Error loading following: $e');
      rethrow;
    }
  }

  Future<List<UserProfileEntity>> searchUsers(String query) async {
    try {
      return await _profileRepository.searchUsers(query: query);
    } catch (e) {
      debugPrint('[ProfileProvider] Error searching users: $e');
      rethrow;
    }
  }

  Future<List<Post>> loadSavedPosts(String userId) async {
    try {
      return await _postRepository.getBookmarkedPosts(userId: userId);
    } catch (e) {
      debugPrint('[ProfileProvider] Error fetching saved posts: $e');
      return [];
    }
  }

  Future<List<RippleEntity>> loadSavedRipples(String userId) async {
    try {
      return await _rippleRepository.getSavedRipples(userId);
    } catch (e) {
      debugPrint('[ProfileProvider] Error fetching saved ripples: $e');
      return [];
    }
  }

  Future<void> updatePrivacy({
    required String userId,
    required bool isPrivate,
  }) async {
    try {
      await _profileRepository.updatePrivacy(
        userId: userId,
        isPrivate: isPrivate,
      );

      if (_state.currentProfile != null) {
        _state = _state.copyWith(
          currentProfile: _state.currentProfile!.copyWith(isPrivate: isPrivate),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ProfileProvider] Error updating privacy: $e');
      rethrow;
    }
  }

  void clearViewedProfile() {
    _state = _state.copyWith(viewedProfile: null, isFollowing: false);
    notifyListeners();
  }

  Future<UserProfileEntity> getProfile(String userId) async {
    return await _profileRepository.getProfile(userId);
  }

  Future<String> getOrCreateConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      return await _messagingService.getOrCreateConversation(
        user1Id: user1Id,
        user2Id: user2Id,
      );
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      debugPrint('[ProfileProvider] Error getting/creating conversation: $e');
      rethrow;
    }
  }

  void clear() {
    _state = const ProfileState();
    notifyListeners();
  }
}
