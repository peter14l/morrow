import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oasis/core/network/supabase_client.dart';
import '../../domain/models/call_entity.dart';
import '../../domain/repositories/call_repository.dart';

/// Implementation of CallRepository using Supabase
class CallRepositoryImpl implements CallRepository {
  SupabaseService get _supabase => SupabaseService();

  @override
  Future<CallEntity> createCall({
    required String conversationId,
    required String callerId,
    required String receiverId,
    required CallType type,
    Map<String, dynamic>? offer,
  }) async {
    final now = DateTime.now();

    final response = await _supabase.client
        .from('calls')
        .insert({
          'conversation_id': conversationId,
          'caller_id': callerId,
          'receiver_id': receiverId,
          'type': type.name,
          'status': CallStatus.ringing.name,
          'created_at': now.toIso8601String(),
          if (offer != null) 'offer': offer,
        })
        .select()
        .single();

    return CallEntity.fromJson(response);
  }

  @override
  Future<CallEntity?> getCall(String callId) async {
    final response = await _supabase.client
        .from('calls')
        .select()
        .eq('id', callId)
        .maybeSingle();

    if (response == null) return null;
    return CallEntity.fromJson(response);
  }

  @override
  Future<List<CallEntity>> getActiveCalls(String userId) async {
    final response = await _supabase.client
        .from('calls')
        .select()
        .or('caller_id.eq.$userId,receiver_id.eq.$userId')
        .eq('status', CallStatus.active.name)
        .order('created_at', ascending: false);

    return response.map((json) => CallEntity.fromJson(json)).toList();
  }

  @override
  Future<CallEntity> acceptCall({
    required String callId,
    required String userId,
  }) async {
    final response = await _supabase.client
        .from('calls')
        .update({
          'status': CallStatus.active.name,
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId)
        .select()
        .single();

    return CallEntity.fromJson(response);
  }

  @override
  Future<void> declineCall(String callId, String userId) async {
    await _supabase.client
        .from('calls')
        .update({'status': CallStatus.declined.name})
        .eq('id', callId);
  }

  @override
  Future<CallEntity> endCall(String callId) async {
    final response = await _supabase.client
        .from('calls')
        .update({
          'status': CallStatus.ended.name,
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', callId)
        .select()
        .single();

    return CallEntity.fromJson(response);
  }

  @override
  Stream<CallEntity> watchCall(String callId) {
    return _supabase.client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .handleError((error) {
          debugPrint('[CallRepository] Realtime stream error: $error');
        })
        .where((data) => data.isNotEmpty)
        .map((data) => CallEntity.fromJson(data.first));
  }
}
