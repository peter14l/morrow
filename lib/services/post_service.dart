import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/services/notification_service.dart';
import 'package:oasis/services/s3_storage_service.dart';
import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PostService {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();
  final NotificationService _notificationService = NotificationService();
  final S3StorageService _s3StorageService = S3StorageService();

  /// Upload a single media file and return its public URL
  Future<String> uploadPostMedia(String userId, File file) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${_uuid.v4()}.$fileExt';
      final path = '$userId/$fileName';

      final mimeType =
          fileExt.toLowerCase() == 'mp4' || fileExt.toLowerCase() == 'mov'
          ? 'video/$fileExt'
          : 'image/$fileExt';

      await _supabase.storage
          .from(SupabaseConfig.postImagesBucket)
          .upload(path, file, fileOptions: FileOptions(contentType: mimeType));

      return _supabase.storage
          .from(SupabaseConfig.postImagesBucket)
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading media to Supabase: $e');
      throw Exception('Failed to upload media');
    }
  }

  /// Create a new post
  Future<Post> createPost({
    required String userId,
    required String? content,
    List<File>? mediaFiles,
    List<String>? mediaTypes, // 'image' or 'video'
    String? communityId,
    String? mood,
    List<String>? hashtags,
    bool isSpoiler = false,
    EnhancedPoll? poll,
    List<String>? collaboratorIds,
  }) async {
    try {
      final postId = _uuid.v4();
      List<String> mediaUrls = [];
      String? firstImageUrl;

      // Upload media files to Supabase Storage if they exist
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        try {
          // Upload files in parallel
          mediaUrls = await Future.wait(
            mediaFiles.map((file) async {
              final fileExt = file.path.split('.').last;
              final fileName = '${_uuid.v4()}.$fileExt';
              final path = '$userId/$fileName';

              final mimeType =
                  mediaTypes != null &&
                      mediaFiles.indexOf(file) < mediaTypes.length &&
                      mediaTypes[mediaFiles.indexOf(file)] == 'video'
                  ? 'video/$fileExt'
                  : 'image/$fileExt';

              await _supabase.storage
                  .from(SupabaseConfig.postImagesBucket)
                  .upload(
                    path,
                    file,
                    fileOptions: FileOptions(contentType: mimeType),
                  );

              return _supabase.storage
                  .from(SupabaseConfig.postImagesBucket)
                  .getPublicUrl(path);
            }),
          );

          if (mediaTypes == null ||
              mediaTypes.isEmpty ||
              mediaTypes.first == 'image') {
            firstImageUrl = mediaUrls.isNotEmpty ? mediaUrls.first : null;
          }
        } catch (e) {
          debugPrint('Error uploading media to Supabase: $e');
          throw Exception('Failed to upload media');
        }
      }

      // Create post in database with storage_provider metadata
      final postData = {
        'id': postId,
        'user_id': userId,
        'community_id': communityId,
        'content': content,
        'image_url': firstImageUrl,
        'media_urls': mediaUrls,
        'media_types': mediaTypes ?? [],
        'mood': mood,
        'hashtags': hashtags ?? [],
        'is_spoiler': isSpoiler,
        'storage_provider': 'supabase',
      };

      await _supabase.from(SupabaseConfig.postsTable).insert(postData);

      // Handle Collaborators
      if (collaboratorIds != null && collaboratorIds.isNotEmpty) {
        final List<Map<String, dynamic>> collaboratorsData =
            collaboratorIds
                .map(
                  (cId) => {
                    'post_id': postId,
                    'user_id': cId,
                    'status': 'pending',
                  },
                )
                .toList();

        await _supabase.from('post_collaborators').insert(collaboratorsData);

        // Send DM requests
        for (final collabId in collaboratorIds) {
          try {
            // Get or create conversation
            final String conversationId = await _supabase.rpc(
              'get_or_create_direct_conversation',
              params: {'p_user1_id': userId, 'p_user2_id': collabId},
            );

            // Send collab request message
            await _supabase.rpc(
              'send_message_v3',
              params: {
                'p_conversation_id': conversationId,
                'p_content': 'Invited you to collaborate on a post.',
                'p_message_type': 'collaborationRequest',
                'p_post_id': postId,
                'p_share_data': {
                  'type': 'collaboration_request',
                  'post_id': postId,
                  'status': 'pending',
                },
              },
            );

            // Trigger formal notification
            await _notificationService.createNotification(
              userId: collabId,
              type: 'post',
              actorId: userId,
              postId: postId,
              message: 'invited you to collaborate on a post.',
            );
          } catch (e) {
            debugPrint('Error sending collaboration request DM to $collabId: $e');
          }
        }
      }

      // Handle Poll Creation (if attached)
      if (poll != null) {
        try {
          final pollResponse = await _supabase
              .from(SupabaseConfig.pollsTable)
              .insert({
                'post_id': postId,
                'question': poll.question,
                'poll_type': poll.pollType.name,
                'is_anonymous': poll.isAnonymous,
                'ends_at': poll.endsAt?.toIso8601String(),
              })
              .select()
              .single();

          final createdPollId = pollResponse['id'];

          if (poll.options.isNotEmpty) {
            final optionsData = poll.options
                .map(
                  (opt) => {
                    'poll_id': createdPollId,
                    'option_text': opt.text,
                    'option_order': opt.order,
                  },
                )
                .toList();

            await _supabase
                .from(SupabaseConfig.pollOptionsTable)
                .insert(optionsData);
          }
        } catch (e) {
          debugPrint('Error saving poll: $e');
        }
      }

      // Fetch the created post with details
      final response = await _supabase
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url,
              is_verified
            ),
            communities:community_id (
              name
            ),
            polls:polls (
              *,
              options:poll_options (*)
            )
          ''')
          .eq('id', postId)
          .single();

      final postMap = Map<String, dynamic>.from(response);
      final profile = postMap[SupabaseConfig.profilesTable];
      if (profile != null) {
        postMap['username'] = profile['username'];
        postMap['user_avatar'] = profile['avatar_url'];
        postMap['is_verified'] = profile['is_verified'] ?? false;
      }

      final community = postMap['communities'];
      if (community != null) {
        postMap['community_name'] = community['name'];
      }

      final post = Post.fromJson(postMap);

      // Trigger notifications
      try {
        final followersResponse = await _supabase
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
        debugPrint('Error triggering post notification: $e');
      }

      return post;
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  /// Get a single post by ID
  Future<Post> getPost(String postId, String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url,
              is_verified
            ),
            polls:polls (
              *,
              options:poll_options (*)
            )
          ''')
          .eq('id', postId)
          .single();

      final postMap = Map<String, dynamic>.from(response);
      final profile = postMap[SupabaseConfig.profilesTable];
      if (profile != null) {
        postMap['username'] = profile['username'];
        postMap['user_avatar'] = profile['avatar_url'];
        postMap['is_verified'] = profile['is_verified'] ?? false;
      }

      final likeResponse = await _supabase
          .from(SupabaseConfig.likesTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      final bookmarkResponse = await _supabase
          .from(SupabaseConfig.bookmarksTable)
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      postMap['is_liked'] = likeResponse != null;
      postMap['is_bookmarked'] = bookmarkResponse != null;

      return Post.fromJson(postMap);
    } catch (e) {
      debugPrint('Error getting post: $e');
      rethrow;
    }
  }

  /// Get user's posts
  Future<List<Post>> getUserPosts({
    required String userId,
    required String currentUserId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // 1. Get IDs of posts where user is an accepted collaborator
      final collabResponse = await _supabase
          .from('post_collaborators')
          .select('post_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      final List<String> collabPostIds =
          (collabResponse as List).map((e) => e['post_id'] as String).toList();

      // 2. Build OR filter: owner is user OR post is in collabPostIds
      String orFilter = 'user_id.eq.$userId';
      if (collabPostIds.isNotEmpty) {
        orFilter += ',id.in.(${collabPostIds.map((id) => '"$id"').join(",")})';
      }

      final response = await _supabase
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url,
              is_verified
            ),
            communities:community_id (
              name
            ),
            polls:polls (
              *,
              options:poll_options (*)
            ),
            collaborators:post_collaborators (
              user_id,
              status,
              profiles:user_id (
                username,
                full_name,
                avatar_url,
                is_verified
              )
            )
          ''')
          .or(orFilter)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if ((response as List).isEmpty) return [];

      final List<Post> posts = [];
      for (final item in response as List) {
        try {
          final postMap = Map<String, dynamic>.from(item);

          // Enrich with profile data
          final profile = postMap[SupabaseConfig.profilesTable];
          if (profile != null) {
            postMap['username'] =
                profile['username'] ?? profile['full_name'] ?? 'User';
            postMap['user_avatar'] = profile['avatar_url'] ?? '';
            postMap['is_verified'] = profile['is_verified'] ?? false;
          }

          // Enrich with community data
          final community = postMap['communities'];
          if (community != null) {
            postMap['community_name'] = community['name'];
          }

          posts.add(Post.fromJson(postMap));
        } catch (e) {
          debugPrint('Error parsing user post: $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }

  /// Accept a collaboration invitation
  Future<void> acceptCollaboration(String postId, String userId) async {
    try {
      await _supabase
          .from('post_collaborators')
          .update({'status': 'accepted'})
          .eq('post_id', postId)
          .eq('user_id', userId);

      // Notify the original author
      final post = await getPost(postId, userId);
      await _notificationService.createNotification(
        userId: post.userId,
        type: 'post',
        actorId: userId,
        postId: postId,
        message: 'accepted your collaboration invitation!',
      );
    } catch (e) {
      debugPrint('Error accepting collaboration: $e');
      rethrow;
    }
  }

  /// Decline a collaboration invitation
  Future<void> declineCollaboration(String postId, String userId) async {
    try {
      await _supabase
          .from('post_collaborators')
          .update({'status': 'denied'})
          .eq('post_id', postId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error declining collaboration: $e');
      rethrow;
    }
  }

  /// Get community posts
  Future<List<Post>> getCommunityPosts({
    required String communityId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.postsTable)
          .select('''
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              full_name,
              avatar_url,
              is_verified
            ),
            communities:community_id (
              name
            ),
            polls:polls (
              *,
              options:poll_options (*)
            )
          ''')
          .eq('community_id', communityId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if ((response as List).isEmpty) return [];

      final List<Post> posts = [];
      for (final item in response as List) {
        try {
          final postMap = Map<String, dynamic>.from(item);

          // Enrich with profile data
          final profile = postMap[SupabaseConfig.profilesTable];
          if (profile != null) {
            postMap['username'] =
                profile['username'] ?? profile['full_name'] ?? 'User';
            postMap['user_avatar'] = profile['avatar_url'] ?? '';
            postMap['is_verified'] = profile['is_verified'] ?? false;
          }

          // Enrich with community data
          final community = postMap['communities'];
          if (community != null) {
            postMap['community_name'] = community['name'];
          }

          posts.add(Post.fromJson(postMap));
        } catch (e) {
          debugPrint('Error parsing community post: $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('Error getting community posts: $e');
      return [];
    }
  }

  /// Delete a post
  Future<void> deletePost(String postId, String userId) async {
    try {
      final post = await _supabase
          .from(SupabaseConfig.postsTable)
          .select('user_id, image_url, media_urls, storage_provider')
          .eq('id', postId)
          .single();

      if (post['user_id'] != userId) {
        throw Exception('Not authorized to delete this post');
      }

      final storageProvider = post['storage_provider'] as String?;
      final mediaUrls = List<String>.from(post['media_urls'] ?? []);

      if (storageProvider == 'backblaze') {
        // Logic for deleting from B2 would go here if needed
        // Note: For now we focus on upload and basic record cleanup.
        // Real S3 deletion requires 'DELETE' signed URLs.
      } else {
        final imageUrl = post['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final fileName = imageUrl.split('/').last;
            await _supabase.storage
                .from(SupabaseConfig.postImagesBucket)
                .remove(['$userId/$fileName']);
          } catch (e) {
            debugPrint('Error deleting image: $e');
          }
        }
      }

      await _supabase.from(SupabaseConfig.postsTable).delete().eq('id', postId);
    } catch (e) {
      debugPrint('Error deleting post: $e');
      rethrow;
    }
  }

  /// Like a post
  Future<void> likePost({
    required String userId,
    required String postId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.likesTable).insert({
        'user_id': userId,
        'post_id': postId,
      });

      try {
        final postResponse = await _supabase
            .from(SupabaseConfig.postsTable)
            .select('user_id')
            .eq('id', postId)
            .single();

        final postOwnerId = postResponse['user_id'] as String;

        if (postOwnerId != userId) {
          await _notificationService.createNotification(
            userId: postOwnerId,
            type: 'like',
            actorId: userId,
            postId: postId,
          );
        }
      } catch (e) {
        debugPrint('Error triggering like notification: $e');
      }
    } catch (e) {
      debugPrint('Error liking post: $e');
      rethrow;
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _supabase
          .from(SupabaseConfig.likesTable)
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } catch (e) {
      debugPrint('Error unliking post: $e');
      rethrow;
    }
  }

  /// Bookmark a post
  Future<void> bookmarkPost({
    required String userId,
    required String postId,
  }) async {
    try {
      await _supabase.from(SupabaseConfig.bookmarksTable).insert({
        'user_id': userId,
        'post_id': postId,
      });
    } catch (e) {
      debugPrint('Error bookmarking post: $e');
      rethrow;
    }
  }

  /// Remove bookmark from a post
  Future<void> unbookmarkPost({
    required String userId,
    required String postId,
  }) async {
    try {
      await _supabase
          .from(SupabaseConfig.bookmarksTable)
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } catch (e) {
      debugPrint('Error removing bookmark: $e');
      rethrow;
    }
  }
}
