import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/features/ripples/data/datasources/ripple_remote_datasource.dart';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart';
import 'package:oasis/features/ripples/domain/repositories/ripple_repository.dart';

/// Implementation of RippleRepository - wraps the remote datasource.
class RippleRepositoryImpl implements RippleRepository {
  final RippleRemoteDatasource _remoteDatasource;
  final SupabaseClient _supabase;

  RippleRepositoryImpl({
    RippleRemoteDatasource? remoteDatasource,
    SupabaseClient? supabase,
  }) : _remoteDatasource = remoteDatasource ?? RippleRemoteDatasource(),
       _supabase = supabase ?? SupabaseService().client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<RippleEntity>> getRipples() async {
    return _remoteDatasource.getRipples();
  }

  @override
  Future<RippleEntity> uploadAndCreateRipple({
    required File videoFile,
    String? caption,
    bool isPrivate = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Upload video
    final videoUrl = await _remoteDatasource.uploadRippleVideo(
      videoFile,
      userId,
    );

    // 2. Create DB record
    return createRipple(
      videoUrl: videoUrl,
      caption: caption,
      isPrivate: isPrivate,
    );
  }

  @override
  Future<RippleEntity> createRipple({
    required String videoUrl,
    String? caption,
    bool isPrivate = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _remoteDatasource.createRipple(
      userId: userId,
      videoUrl: videoUrl,
      caption: caption,
      isPrivate: isPrivate,
    );
  }

  @override
  Future<void> deleteRipple(String rippleId) async {
    await _remoteDatasource.deleteRipple(rippleId);
  }

  @override
  Future<void> likeRipple(String rippleId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _remoteDatasource.likeRipple(rippleId, userId);
  }

  @override
  Future<void> unlikeRipple(String rippleId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _remoteDatasource.unlikeRipple(rippleId, userId);
  }

  @override
  Future<void> saveRipple(String rippleId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _remoteDatasource.saveRipple(rippleId, userId);
  }

  @override
  Future<void> unsaveRipple(String rippleId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    await _remoteDatasource.unsaveRipple(rippleId, userId);
  }

  @override
  Future<RippleCommentEntity> commentOnRipple({
    required String rippleId,
    required String content,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    return _remoteDatasource.commentOnRipple(
      rippleId: rippleId,
      userId: userId,
      content: content,
    );
  }

  @override
  Future<List<RippleCommentEntity>> getComments(String rippleId) async {
    return _remoteDatasource.getComments(rippleId);
  }

  @override
  Future<RippleEntity?> getRippleById(String rippleId) async {
    return _remoteDatasource.getRippleById(rippleId);
  }

  @override
  Future<List<RippleEntity>> getSavedRipples(String userId) async {
    return _remoteDatasource.getSavedRipples(userId);
  }
}
