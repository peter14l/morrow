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
      final response = await _supabase
          .from('circle_members')
          .select('circle_id, circles(*, circle_members(user_id))')
          .eq('user_id', userId)
          .order('created_at', referencedTable: 'circles', ascending: false);

      return (response as List).map<Map<String, dynamic>>((row) {
        final circle = row['circles'] as Map<String, dynamic>;
        final memberRows =
            (circle['circle_members'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        circle['member_ids'] =
            memberRows.map((m) => m['user_id'] as String).toList();
        return circle;
      }).toList();
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] fetchUserCircles error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCircle(String circleId) async {
    try {
      final response =
          await _supabase
              .from('circles')
              .select('*, circle_members(user_id)')
              .eq('id', circleId)
              .single();

      final circleMap = Map<String, dynamic>.from(response);
      final memberRows =
          (circleMap['circle_members'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      circleMap['member_ids'] =
          memberRows.map((m) => m['user_id'] as String).toList();

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
        await _supabase.from('notifications').insert({
          'user_id': memberId,
          'type': 'circle_invite',
          'title': 'You\'re in a Circle! $emoji',
          'body': 'You\'ve been added to "$name"',
          'data': {'circle_id': circleId},
          'created_at': now,
        });
      }

      return {
        'id': circleId,
        'name': name,
        'emoji': emoji,
        'created_by': createdBy,
        'created_at': now,
        'streak_count': 0,
        'member_ids': allMembers.toList(),
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

  Future<List<Map<String, dynamic>>> getCircleFeed({
    required String circleId,
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc('get_circle_feed', params: {
        'p_user_id': userId,
        'p_circle_id': circleId,
        'p_limit': limit,
        'p_offset': offset,
      });

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[CircleRemoteDatasource] getCircleFeed error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createCirclePost({
    required String circleId,
    required String userId,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toIso8601String();

      final data = {
        'id': id,
        'user_id': userId,
        'circle_id': circleId,
        'content': content,
        'media_urls': mediaUrls,
        'media_types': mediaTypes,
        'created_at': now,
        'updated_at': now,
      };

      await _supabase.from('posts').insert(data);

      // Fetch the created post with joined profile info
      final response = await _supabase
          .from('posts')
          .select('*, profiles(*)')
          .eq('id', id)
          .single();

      return response;
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
