import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CircleRemoteDatasource {
  final SupabaseClient _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> fetchUserCircles(String userId) async {
    try {
      debugPrint(
        '[CircleRemoteDatasource] fetchUserCircles START for userId: $userId',
      );

      // Step 1: Query circles where the user is a member or the creator
      // We use a join with circle_members!inner to find circles the user is in.
      // We also fetch all members and their profiles in the same query.
      // NOTE: We must explicitly list columns for the profiles join due to security hardening.
      const profileColumns =
          'id, username, full_name, avatar_url, is_verified, xp, level';

      final response = await _supabase
          .from('circles')
          .select(
            '*, circle_members!inner(user_id), all_members:circle_members(user_id, profiles:user_id($profileColumns))',
          )
          .eq('circle_members.user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      debugPrint(
        '[CircleRemoteDatasource] fetchUserCircles: found ${rows.length} circles',
      );

      final List<Map<String, dynamic>> results = [];

      for (final row in rows) {
        try {
          final circleMap = Map<String, dynamic>.from(
            row as Map<String, dynamic>,
          );

          // Extract members from the 'all_members' join
          final allMemberRows =
              (circleMap['all_members'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

          circleMap['member_ids'] = allMemberRows
              .map((m) => m['user_id']?.toString())
              .whereType<String>()
              .toList();

          circleMap['members'] = allMemberRows
              .map((m) => m['profiles'])
              .where((p) => p != null)
              .cast<Map<String, dynamic>>()
              .toList();

          // Cleanup internal join fields
          circleMap.remove('circle_members');
          circleMap.remove('all_members');

          results.add(circleMap);
        } catch (e) {
          debugPrint(
            '[CircleRemoteDatasource] Error processing circle row: $e',
          );
        }
      }

      // Fallback: If no circles found by membership, check if the user created any
      // (This helps if membership record creation failed but circle creation succeeded)
      if (results.isEmpty) {
        debugPrint(
          '[CircleRemoteDatasource] No circles found by membership, checking created_by...',
        );
        final createdResponse = await _supabase
            .from('circles')
            .select(
              '*, all_members:circle_members(user_id, profiles:user_id(*))',
            )
            .eq('created_by', userId)
            .order('created_at', ascending: false);

        if ((createdResponse as List).isNotEmpty) {
          debugPrint(
            '[CircleRemoteDatasource] Found ${(createdResponse as List).length} circles by created_by fallback',
          );
          for (final row in (createdResponse as List)) {
            try {
              final circleMap = Map<String, dynamic>.from(
                row as Map<String, dynamic>,
              );
              final allMemberRows =
                  (circleMap['all_members'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [];
              circleMap['member_ids'] = allMemberRows
                  .map((m) => m['user_id']?.toString())
                  .whereType<String>()
                  .toList();
              circleMap['members'] = allMemberRows
                  .map((m) => m['profiles'])
                  .where((p) => p != null)
                  .cast<Map<String, dynamic>>()
                  .toList();
              circleMap.remove('all_members');
              results.add(circleMap);
            } catch (_) {}
          }
        }
      }

      return results;
    } catch (e, stack) {
      debugPrint('[CircleRemoteDatasource] fetchUserCircles FATAL error: $e');
      debugPrint('Stack trace: $stack');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCircle(String circleId) async {
    try {
      const profileColumns =
          'id, username, full_name, avatar_url, is_verified, xp, level';
      final response = await _supabase
          .from('circles')
          .select(
            '*, circle_members(user_id, profiles:user_id($profileColumns))',
          )
          .eq('id', circleId)
          .single();

      final circleMap = Map<String, dynamic>.from(response);
      final memberRows =
          (circleMap['circle_members'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      circleMap['member_ids'] = memberRows
          .map((m) => m['user_id'] as String)
          .toList();
      circleMap['members'] = memberRows
          .map((m) => m['profiles'])
          .where((p) => p != null)
          .toList();

      return circleMap;
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] getCircle error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCircle({
    required String createdBy,
    required String name,
    required String emoji,
    required List<String> memberIds,
  }) async {
    try {
      final circleId = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      await _supabase.from('circles').insert({
        'id': circleId,
        'name': name,
        'emoji': emoji,
        'created_by': createdBy,
        'streak_count': 0,
        'created_at': now,
      });

      final allMembers = {createdBy, ...memberIds};
      await _supabase
          .from('circle_members')
          .insert(
            allMembers
                .map(
                  (uid) => {
                    'circle_id': circleId,
                    'user_id': uid,
                    'role': uid == createdBy ? 'admin' : 'member',
                    'joined_at': now,
                  },
                )
                .toList(),
          );

      for (final memberId in memberIds) {
        // Skip notifying yourself
        if (memberId == createdBy) continue;

        await _supabase.from('notifications').insert({
          'user_id': memberId,
          'actor_id': createdBy,
          'type': 'circle_invite',
          'content': 'added you to the circle "$name" $emoji',
          'metadata': {'circle_id': circleId},
          'created_at': now,
        });
      }

      // Fetch the creator's profile to include in the returned map
      final creatorProfile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', createdBy)
          .single();

      return {
        'id': circleId,
        'name': name,
        'emoji': emoji,
        'created_by': createdBy,
        'created_at': now,
        'streak_count': 0,
        'member_ids': allMembers.toList(),
        'members': [creatorProfile],
      };
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] createCircle error: $e');
      rethrow;
    }
  }

  Future<void> deleteCircle(String circleId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final circle = await getCircle(circleId);
      if (circle['created_by'] != userId) {
        throw Exception('Only the creator can delete this circle.');
      }

      await _supabase.from('circles').delete().eq('id', circleId);
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] deleteCircle error: $e');
      rethrow;
    }
  }

  Future<void> joinCircle(String circleId, String userId) async {
    try {
      await _supabase.from('circle_members').insert({
        'circle_id': circleId,
        'user_id': userId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] joinCircle error: $e');
      rethrow;
    }
  }

  Future<void> leaveCircle(String circleId, String userId) async {
    try {
      await _supabase
          .from('circle_members')
          .delete()
          .eq('circle_id', circleId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] leaveCircle error: $e');
      rethrow;
    }
  }

  Future<void> deletePost(String postId, String userId) async {
    try {
      final post = await _supabase
          .from('posts')
          .select('user_id, image_url')
          .eq('id', postId)
          .single();

      if (post['user_id'] != userId) {
        throw Exception('Not authorized to delete this post');
      }

      // Delete image from storage if exists
      final imageUrl = post['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final fileName = imageUrl.split('/').last;
          await _supabase.storage.from('post-images').remove([
            '$userId/$fileName',
          ]);
        } catch (e) {
          debugPrint('[CircleRemoteDatasource] Delete image error: $e');
        }
      }

      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] deletePost error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCircleFeed({
    required String circleId,
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // ignore: avoid_print
      print(
        '>>> getCircleFeed START: circleId=$circleId, userId=$userId, limit=$limit, offset=$offset',
      );
      debugPrint(
        '[CircleRemoteDatasource] getCircleFeed: circleId=$circleId, userId=$userId, limit=$limit, offset=$offset',
      );

      // Try RPC first
      var response = await _supabase.rpc(
        'get_circle_feed',
        params: {
          'p_user_id': userId,
          'in_circle_id': circleId, // Fixed: renamed parameter in SQL
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      // If RPC returns empty, fallback to direct query
      if (response == null || (response as List).isEmpty) {
        debugPrint(
          '[CircleRemoteDatasource] RPC returned empty, trying direct query...',
        );

        // Debug: First check if ANY posts exist in the table for this user
        final allUserPosts = await _supabase
            .from('posts')
            .select('id, circle_id, content')
            .eq('user_id', userId);

        debugPrint(
          '[CircleRemoteDatasource] All user posts count: ${(allUserPosts as List).length}',
        );
        if ((allUserPosts as List).isNotEmpty) {
          debugPrint(
            '[CircleRemoteDatasource] User post circle_ids: ${allUserPosts.map((p) => p['circle_id']).toList()}',
          );
        }

        // Direct query as fallback - bypass RPC to avoid potential RPC issues
        // Use range() for pagination instead of limit/offset separately
        final start = offset;
        final end = offset + limit - 1;
        const profileColumns = 'username, full_name, avatar_url, is_verified';
        final directResponse = await _supabase
            .from('posts')
            .select('*, profiles:user_id($profileColumns)')
            .eq('circle_id', circleId)
            .order('created_at', ascending: false)
            .range(start, end);

        debugPrint(
          '[CircleRemoteDatasource] Direct query returned: ${(directResponse as List).length} posts',
        );
        response = directResponse;
      }

      final List<Map<String, dynamic>> posts = (response)
          .cast<Map<String, dynamic>>();
      debugPrint(
        '[CircleRemoteDatasource] getCircleFeed: returned ${posts.length} posts for circle $circleId',
      );

      // Log first post's circle_id to verify posts have circle_id set
      if (posts.isNotEmpty) {
        debugPrint(
          '[CircleRemoteDatasource] First post circle_id: ${posts.first['circle_id']}',
        );
      }

      // ignore: avoid_print
      print(
        '>>> getCircleFeed RESULT: ${posts.length} posts for circle $circleId',
      );

      return posts;
    } catch (e, stack) {
      // ignore: avoid_print
      print('>>> getCircleFeed ERROR: $e');
      debugPrint(
        '[CircleRemoteDatasource] getCircleFeed error: $e, stack: $stack',
      );
      return [];
    }
  }

  Future<Map<String, dynamic>> createCirclePost({
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
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      final data = {
        'id': id,
        'user_id': userId,
        'circle_id': circleId,
        'content': content,
        'image_url': mediaUrls.isNotEmpty ? mediaUrls.first : null,
        'media_urls': mediaUrls,
        'media_types': mediaTypes,
        'mood': mood,
        'hashtags': hashtags,
        'is_spoiler': isSpoiler,
        'storage_provider': 'supabase',
        'created_at': now,
        'updated_at': now,
      };

      await _supabase.from('posts').insert(data);

      // Handle Poll if any
      if (poll != null) {
        final pollId = _uuid.v4();
        await _supabase.from('polls').insert({
          'id': pollId,
          'post_id': id,
          'question': poll['question'],
          'poll_type': poll['poll_type'],
          'is_anonymous': poll['is_anonymous'] ?? false,
          'ends_at': poll['ends_at'],
        });

        if (poll['options'] != null) {
          final options = (poll['options'] as List)
              .map(
                (opt) => {
                  'poll_id': pollId,
                  'option_text': opt['text'],
                  'option_order': opt['order'],
                },
              )
              .toList();
          await _supabase.from('poll_options').insert(options);
        }
      }

      // Fetch the created post with joined profile info
      const profileColumns = 'username, full_name, avatar_url, is_verified';
      final response = await _supabase
          .from('posts')
          .select('''
            *,
            profiles:user_id (
              $profileColumns
            ),
            polls:polls (
              *,
              options:poll_options (*)
            )
          ''')
          .eq('id', id)
          .single();

      final postMap = Map<String, dynamic>.from(response);
      final profile = postMap['profiles'];
      if (profile != null) {
        postMap['username'] =
            profile['username'] ?? profile['full_name'] ?? 'User';
        postMap['user_avatar'] = profile['avatar_url'] ?? '';
        postMap['is_verified'] = profile['is_verified'] ?? false;
      }

      // Ensure circle_id is preserved in the map (select * should include it)
      postMap['circle_id'] = postMap['circle_id'] ?? circleId;
      postMap['storage_provider'] = postMap['storage_provider'] ?? 'supabase';

      return postMap;
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] createCirclePost error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCommitments({
    required String circleId,
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStr =
          '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

      final response = await _supabase
          .from('commitments')
          .select('*, commitment_responses(*)')
          .eq('circle_id', circleId)
          .eq('due_date', dateStr)
          .order('created_at', ascending: true);

      return (response as List).map<Map<String, dynamic>>((row) {
        final rawResponses =
            (row['commitment_responses'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final responsesMap = <String, Map<String, dynamic>>{};
        for (final r in rawResponses) {
          final cr = Map<String, dynamic>.from(r);
          responsesMap[cr['user_id'] as String] = cr;
        }
        final json = Map<String, dynamic>.from(row);
        json['responses'] = responsesMap;
        return json;
      }).toList();
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] getCommitments error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createCommitment({
    required String circleId,
    required String createdBy,
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();
      final due = dueDate ?? now;
      final dateStr =
          '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';

      final data = {
        'id': id,
        'circle_id': circleId,
        'created_by': createdBy,
        'title': title,
        'description': description,
        'due_date': dateStr,
        'status': 'open',
        'created_at': now.toIso8601String(),
      };

      await _supabase.from('commitments').insert(data);

      return {
        'id': id,
        'circle_id': circleId,
        'created_by': createdBy,
        'title': title,
        'description': description,
        'due_date': due.toIso8601String(),
        'status': 'open',
        'responses': <String, dynamic>{},
        'created_at': now.toIso8601String(),
      };
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] createCommitment error: $e');
      rethrow;
    }
  }

  Future<void> setIntent({
    required String commitmentId,
    required String userId,
    required MemberIntent intent,
  }) async {
    try {
      await _supabase.from('commitment_responses').upsert({
        'commitment_id': commitmentId,
        'user_id': userId,
        'intent': intent.name,
        'completed': false,
      }, onConflict: 'commitment_id,user_id');
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] setIntent error: $e');
      rethrow;
    }
  }

  Future<void> markComplete({
    required String commitmentId,
    required String userId,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('commitment_responses').upsert({
        'commitment_id': commitmentId,
        'user_id': userId,
        'intent': MemberIntent.inTrying.name,
        'completed': true,
        'completed_at': now,
        'note': note,
      }, onConflict: 'commitment_id,user_id');
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] markComplete error: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeToCommitments({
    required String circleId,
    DateTime? date,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    final channel = _supabase.channel('commitments:$circleId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'commitments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'circle_id',
            value: circleId,
          ),
          callback: (_) async {
            final items = await getCommitments(circleId: circleId, date: date);
            if (!controller.isClosed) controller.add(items);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'commitment_responses',
          callback: (_) async {
            final items = await getCommitments(circleId: circleId, date: date);
            if (!controller.isClosed) controller.add(items);
          },
        )
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('[CircleRemoteDatasource] subscribe error: $error');
          }
        });

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
