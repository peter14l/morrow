import 'package:flutter/foundation.dart';
import 'package:oasis/models/study_session.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:uuid/uuid.dart';

class StudySessionService extends ChangeNotifier {
  final _supabase = SupabaseService().client;
  final _uuid = const Uuid();

  Future<StudySession> createSession({
    required String title,
    required int durationMinutes,
    bool isLockedIn = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final sessionData = {
      'id': _uuid.v4(),
      'title': title,
      'creator_id': user.id,
      'duration_minutes': durationMinutes,
      'is_locked_in': isLockedIn,
      'status': 'active',
      'start_time': DateTime.now().toIso8601String(),
    };

    final response = await _supabase
        .from('study_sessions')
        .insert(sessionData)
        .select()
        .single();

    return StudySession.fromJson(response);
  }

  Future<void> joinSession(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('study_session_participants').upsert({
      'session_id': sessionId,
      'user_id': user.id,
      'joined_at': DateTime.now().toIso8601String(),
      'exit_status': 'joined',
    });
  }

  Future<void> completeSession(String sessionId, int xpEarned) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Update participant status
    await _supabase
        .from('study_session_participants')
        .update({'exit_status': 'completed', 'xp_earned': xpEarned})
        .eq('session_id', sessionId)
        .eq('user_id', user.id);

    // Update session status if creator
    await _supabase
        .from('study_sessions')
        .update({'status': 'completed'})
        .eq('id', sessionId)
        .eq('creator_id', user.id);

    // Award XP to profile
    await _supabase.rpc('increment_xp', params: {'xp_amount': xpEarned});
  }
}
