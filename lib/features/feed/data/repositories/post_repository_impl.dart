import 'package:universal_io/io.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/domain/repositories/post_repository.dart';
import 'package:oasis/features/feed/data/datasources/post_remote_datasource.dart';
import 'package:oasis/services/notification_service.dart';

/// Implementation of PostRepository.
///
/// Delegates to PostRemoteDatasource for all Supabase operations
/// and handles notification triggers after mutations.
class PostRepositoryImpl implements PostRepository {
  final PostRemoteDatasource _remoteDatasource;
  final NotificationService _notificationService = NotificationService();

  PostRepositoryImpl({PostRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? PostRemoteDatasource();

  @override
  Future<Post> createPost({
    required String userId,
    required String? content,
    List<File>? mediaFiles,
    List<String>? mediaTypes,
    String? communityId,
    String? mood,
    bool isSpoiler = false,
    List<String>? collaboratorIds,
  }) async {
    final postMap = await _remoteDatasource.createPost(
      userId: userId,
      content: content,
      mediaFiles: mediaFiles,
      mediaTypes: mediaTypes,
      communityId: communityId,
      mood: mood,
      isSpoiler: isSpoiler,
    );

    final post = Post.fromJson(postMap);

    // Trigger notifications for followers
    _notifyFollowers(userId, post.id);

    return post;
  }

  @override
  Future<void> acceptCollaboration(String postId, String userId) async {
    final supabase = SupabaseService().client;
    await supabase
        .from('post_collaborators')
        .update({'status': 'accepted'})
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  @override
  Future<void> declineCollaboration(String postId, String userId) async {
    final supabase = SupabaseService().client;
    await supabase
        .from('post_collaborators')
        .update({'status': 'denied'})
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  @override
  Future<Post> getPost(String postId, String userId) async {
    final postMap = await _remoteDatasource.getPost(postId, userId);
    return Post.fromJson(postMap);
  }

  @override
  Future<List<Post>> getUserPosts({
    required String userId,
    required String currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rawPosts = await _remoteDatasource.getUserPosts(
      userId: userId,
      currentUserId: currentUserId,
      limit: limit,
      offset: offset,
    );
    return rawPosts.map((json) => Post.fromJson(json)).toList();
  }

  @override
  Future<List<Post>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rawPosts = await _remoteDatasource.getCommunityPosts(
      communityId: communityId,
      limit: limit,
      offset: offset,
    );
    return rawPosts.map((json) => Post.fromJson(json)).toList();
  }

  @override
  Future<void> deletePost(String postId, String userId) async {
    await _remoteDatasource.deletePost(postId, userId);
  }

  @override
  Future<void> likePost({
    required String userId,
    required String postId,
  }) async {
    await _remoteDatasource.likePost(userId: userId, postId: postId);

    // Trigger notification for post owner
    _notifyPostOwner(userId, postId, 'like');
  }

  @override
  Future<void> unlikePost({
    required String userId,
    required String postId,
  }) async {
    await _remoteDatasource.unlikePost(userId: userId, postId: postId);
  }

  @override
  Future<void> bookmarkPost({
    required String userId,
    required String postId,
  }) async {
    await _remoteDatasource.bookmarkPost(userId: userId, postId: postId);
  }

  @override
  Future<void> unbookmarkPost({
    required String userId,
    required String postId,
  }) async {
    await _remoteDatasource.unbookmarkPost(userId: userId, postId: postId);
  }

  @override
  Future<List<Post>> getBookmarkedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rawPosts = await _remoteDatasource.getBookmarkedPosts(
      userId: userId,
      limit: limit,
      offset: offset,
    );
    return rawPosts.map((json) => Post.fromJson(json)).toList();
  }

  @override
  Future<void> incrementViews(String postId) async {
    await _remoteDatasource.incrementViews(postId);
  }

  @override
  Future<void> sharePost(String postId) async {
    await _remoteDatasource.sharePost(postId);
  }

  @override
  Future<void> voteInPoll({
    required String userId,
    required String pollId,
    required String optionId,
  }) async {
    await _remoteDatasource.voteInPoll(
      userId: userId,
      pollId: pollId,
      optionId: optionId,
    );
  }

  // ─── Notification helpers ─────────────────────────────────────────

  void _notifyFollowers(String userId, String postId) async {
    try {
      final supabase = SupabaseService().client;
      final followersResponse = await supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);

      for (final follower in followersResponse) {
        final followerId = follower['follower_id'] as String;
        await _notificationService.createNotification(
          userId: followerId,
          type: 'post',
          actorId: userId,
          postId: postId,
        );
      }
    } catch (e) {
      // Don't fail post creation if notification fails
    }
  }

  void _notifyPostOwner(String actorId, String postId, String type) async {
    try {
      final supabase = SupabaseService().client;
      final postResponse = await supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();

      final postOwnerId = postResponse['user_id'] as String;
      if (postOwnerId != actorId) {
        await _notificationService.createNotification(
          userId: postOwnerId,
          type: type,
          actorId: actorId,
          postId: postId,
        );
      }
    } catch (e) {
      // Don't fail the mutation if notification fails
    }
  }
}
