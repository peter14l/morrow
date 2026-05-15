import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/feed/domain/models/comment.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CommentService {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();
  final NotificationService _notificationService = NotificationService();

  /// Get comments for a post
  Future<List<Comment>> getPostComments({
    required String postId,
    required String currentUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Comment> comments = [];
      for (final item in response) {
        final commentMap = Map<String, dynamic>.from(item);
        final profile = commentMap[SupabaseConfig.profilesTable];
        if (profile != null) {
          commentMap['username'] = profile['username'];
          commentMap['user_avatar'] = profile['avatar_url'];
        }

        // Check if current user has liked this comment
        final likeResponse = await _supabase
            .from(SupabaseConfig.commentLikesTable)
            .select()
            .eq('comment_id', commentMap['id'])
            .eq('user_id', currentUserId)
            .maybeSingle();

        commentMap['is_liked'] = likeResponse != null;

        comments.add(Comment.fromJson(commentMap));
      }

      return comments;
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      rethrow;
    }
  }

  /// Get replies for a comment
  Future<List<Comment>> getCommentReplies({
    required String commentId,
    required String currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('parent_comment_id', commentId)
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      if (response.isEmpty) return [];

      final List<Comment> replies = [];
      for (final item in response) {
        final commentMap = Map<String, dynamic>.from(item);
        final profile = commentMap[SupabaseConfig.profilesTable];
        if (profile != null) {
          commentMap['username'] = profile['username'];
          commentMap['user_avatar'] = profile['avatar_url'];
        }

        // Check if current user has liked this comment
        final likeResponse = await _supabase
            .from(SupabaseConfig.commentLikesTable)
            .select()
            .eq('comment_id', commentMap['id'])
            .eq('user_id', currentUserId)
            .maybeSingle();

        commentMap['is_liked'] = likeResponse != null;

        replies.add(Comment.fromJson(commentMap));
      }

      return replies;
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      rethrow;
    }
  }

  /// Create a comment
  Future<Comment> createComment({
    required String userId,
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final commentId = _uuid.v4();

      final commentData = {
        'id': commentId,
        'user_id': userId,
        'post_id': postId,
        'parent_comment_id': parentCommentId,
        'content': content,
      };

      await _supabase.from(SupabaseConfig.commentsTable).insert(commentData);

      // Fetch the created comment with user details
      final response = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('id', commentId)
          .single();

      // Transform response
      final commentMap = Map<String, dynamic>.from(response);
      final profile = commentMap[SupabaseConfig.profilesTable];
      if (profile != null) {
        commentMap['username'] = profile['username'];
        commentMap['user_avatar'] = profile['avatar_url'];
      }
      final comment = Comment.fromJson(commentMap);

      // Trigger notifications
      try {
        if (parentCommentId == null) {
          // New top-level comment: Notify post owner
          final postResponse = await _supabase
              .from(SupabaseConfig.postsTable)
              .select('user_id')
              .eq('id', postId)
              .single();

          final postOwnerId = postResponse['user_id'] as String;

          if (postOwnerId != userId) {
            await _notificationService.createNotification(
              userId: postOwnerId,
              type: 'comment',
              actorId: userId,
              postId: postId,
              commentId: commentId,
            );
          }
        } else {
          // Reply: Notify original commenter
          final parentCommentResponse = await _supabase
              .from(SupabaseConfig.commentsTable)
              .select('user_id')
              .eq('id', parentCommentId)
              .single();

          final parentCommentOwnerId =
              parentCommentResponse['user_id'] as String;

          if (parentCommentOwnerId != userId) {
            await _notificationService.createNotification(
              userId: parentCommentOwnerId,
              type: 'reply',
              actorId: userId,
              postId: postId,
              commentId: commentId,
            );
          }
        }
      } catch (e) {
        debugPrint('Error triggering comment notification: $e');
      }

      return comment;
    } catch (e) {
      debugPrint('Error creating comment: $e');
      rethrow;
    }
  }

  /// Like a comment
  Future<void> likeComment({
    required String userId,
    required String commentId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.commentLikesTable).insert({
        'user_id': userId,
        'comment_id': commentId,
      });
    } catch (e) {
      debugPrint('Error liking comment: $e');
      rethrow;
    }
  }

  /// Unlike a comment
  Future<void> unlikeComment({
    required String userId,
    required String commentId,
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.commentLikesTable)
          .delete()
          .eq('user_id', userId)
          .eq('comment_id', commentId);
    } catch (e) {
      debugPrint('Error unliking comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      // Verify ownership
      final comment = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('user_id')
          .eq('id', commentId)
          .single();

      if (comment['user_id'] != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      // Delete comment (cascades to replies and likes)
      await _supabase
          .from(SupabaseConfig.commentsTable)
          .delete()
          .eq('id', commentId);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Update a comment
  Future<Comment> updateComment({
    required String commentId,
    required String userId,
    required String content,
  }) async {
    try {
      // Verify ownership
      final comment = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('user_id')
          .eq('id', commentId)
          .single();

      if (comment['user_id'] != userId) {
        throw Exception('Not authorized to update this comment');
      }

      // Update comment
      await _supabase
          .from(SupabaseConfig.commentsTable)
          .update({'content': content})
          .eq('id', commentId);

      // Fetch updated comment
      final response = await _supabase
          .from(SupabaseConfig.commentsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url
            )
          ''')
          .eq('id', commentId)
          .single();

      // Transform response
      final commentMap = Map<String, dynamic>.from(response);
      final profile = commentMap[SupabaseConfig.profilesTable];
      if (profile != null) {
        commentMap['username'] = profile['username'];
        commentMap['user_avatar'] = profile['avatar_url'];
      }

      // Check if current user has liked
      final likeResponse = await _supabase
          .from(SupabaseConfig.commentLikesTable)
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      commentMap['is_liked'] = likeResponse != null;

      return Comment.fromJson(commentMap);
    } catch (e) {
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  /// Subscribe to post comments
  RealtimeChannel subscribeToPostComments({
    required String postId,
    required Function(Map<String, dynamic>) onCommentAdded,
    required Function(String) onCommentDeleted,
  }) {
    final channel = _supabase.channel('comments:$postId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.commentsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) async {
            try {
              final commentData = payload.newRecord;

              // Fetch user details for the new comment
              final profile = await _supabase
                  .from(SupabaseConfig.profilesTable)
                  .select('username, avatar_url')
                  .eq('id', commentData['user_id'])
                  .single();

              commentData['username'] = profile['username'];
              commentData['user_avatar'] = profile['avatar_url'];
              commentData['is_liked'] = false;

              onCommentAdded(commentData);
            } catch (e) {
              debugPrint('Error processing new comment: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConfig.commentsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            final commentId = payload.oldRecord['id'] as String;
            onCommentDeleted(commentId);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('CommentService: subscribeToPostComments error: $error');
          }
        });

    return channel;
  }

  /// Unsubscribe from comments
  Future<void> unsubscribeFromComments(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
