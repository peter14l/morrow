import 'package:universal_io/io.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

/// Repository contract for post operations.
///
/// Defines all post-related data operations. Implementations
/// live in the data layer (e.g., PostRepositoryImpl).
abstract class PostRepository {
  /// Create a new post with optional media files.
  Future<Post> createPost({
    required String userId,
    required String? content,
    List<File>? mediaFiles,
    List<String>? mediaTypes,
    String? communityId,
    String? mood,
    bool isSpoiler = false,
    List<String>? collaboratorIds,
  });

  /// Accept a collaboration invitation.
  Future<void> acceptCollaboration(String postId, String userId);

  /// Decline a collaboration invitation.
  Future<void> declineCollaboration(String postId, String userId);

  /// Get a single post by ID with like/bookmark status.
  Future<Post> getPost(String postId, String userId);

  /// Get posts by a specific user.
  Future<List<Post>> getUserPosts({
    required String userId,
    required String currentUserId,
    int limit = 20,
    int offset = 0,
  });

  /// Get posts from a specific community.
  Future<List<Post>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    int offset = 0,
  });

  /// Delete a post (verifies ownership).
  Future<void> deletePost(String postId, String userId);

  /// Like a post.
  Future<void> likePost({required String userId, required String postId});

  /// Unlike a post.
  Future<void> unlikePost({required String userId, required String postId});

  /// Bookmark a post.
  Future<void> bookmarkPost({required String userId, required String postId});

  /// Remove bookmark from a post.
  Future<void> unbookmarkPost({required String userId, required String postId});

  /// Get user's bookmarked posts.
  Future<List<Post>> getBookmarkedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  });

  /// Increment view count for a post.
  Future<void> incrementViews(String postId);

  /// Share a post (increment share count).
  Future<void> sharePost(String postId);

  /// Vote in a poll.
  Future<void> voteInPoll({
    required String userId,
    required String pollId,
    required String optionId,
  });
}
