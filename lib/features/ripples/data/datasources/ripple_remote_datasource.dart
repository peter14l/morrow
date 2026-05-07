import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/network/supabase_client.dart';
import 'package:oasis/core/config/supabase_config.dart';
import 'package:oasis/core/config/r2_config.dart';
import 'package:oasis/services/s3_storage_service.dart';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart';

/// Remote data source for ripples - handles all Supabase API calls.
class RippleRemoteDatasource {
  final SupabaseClient _supabase;
  final S3StorageService _s3StorageService = S3StorageService();

  RippleRemoteDatasource({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseService().client;

  /// Uploads a ripple video to Supabase storage (Temporarily bypassing Backblaze).
  Future<String> uploadRippleVideo(File file, String userId) async {
    final fileExt = file.path.split('.').last;
    final fileId =
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}.$fileExt';
    final path = '$userId/$fileId';

    // Temporary: Upload to Supabase instead of Backblaze
    await _supabase.storage.from(SupabaseConfig.ripplesVideosBucket).upload(
      path,
      file,
    );

    return _supabase.storage
        .from(SupabaseConfig.ripplesVideosBucket)
        .getPublicUrl(path);

    /* Original Backblaze Logic:
    return _s3StorageService.uploadFile(
      bucket: R2Config.b2RipplesBucketName,
      fileId: fileId,
      type: 'ripples',
      file: file,
      contentType: 'video/$fileExt',
    );
    */
  }

  /// Fetches ripples from Supabase with profile data and like/save status.
  Future<List<RippleEntity>> getRipples() async {
    final userId = _supabase.auth.currentUser?.id;

    final response = await _supabase
        .from(SupabaseConfig.ripplesTable)
        .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            avatar_url,
            is_private
          ),
          ${SupabaseConfig.rippleLikesTable}!left (
            user_id
          ),
          ${SupabaseConfig.rippleSavesTable}!left (
            user_id
          )
        ''')
        .or('is_private.eq.false,user_id.eq.$userId')
        .order('created_at', ascending: false);

    final ripplesData = List<Map<String, dynamic>>.from(response);

    // Process ripples to add is_liked and is_saved fields
    for (var ripple in ripplesData) {
      final likes = ripple[SupabaseConfig.rippleLikesTable] as List<dynamic>?;
      ripple['is_liked'] =
          likes != null && likes.any((l) => l['user_id'] == userId);
      ripple.remove(SupabaseConfig.rippleLikesTable);

      final saves = ripple[SupabaseConfig.rippleSavesTable] as List<dynamic>?;
      ripple['is_saved'] =
          saves != null && saves.any((s) => s['user_id'] == userId);
      ripple.remove(SupabaseConfig.rippleSavesTable);
    }

    return ripplesData.map((json) => RippleEntity.fromJson(json)).toList();
  }

  /// Creates a new ripple in Supabase.
  Future<RippleEntity> createRipple({
    required String userId,
    required String videoUrl,
    String? thumbnailUrl,
    String? caption,
    bool isPrivate = false,
  }) async {
    final data =
        await _supabase
            .from(SupabaseConfig.ripplesTable)
            .insert({
              'user_id': userId,
              'video_url': videoUrl,
              'thumbnail_url': thumbnailUrl,
              'caption': caption,
              'is_private': isPrivate,
              'storage_provider': 'supabase', // Mark as supabase for now
            })
            .select()
            .single();

    return RippleEntity.fromJson(data);
  }

  /// Deletes a ripple by ID.
  Future<void> deleteRipple(String rippleId) async {
    await _supabase.from(SupabaseConfig.ripplesTable).delete().eq('id', rippleId);
  }

  /// Likes a ripple.
  Future<void> likeRipple(String rippleId, String userId) async {
    try {
      await _supabase.from(SupabaseConfig.rippleLikesTable).insert({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      // Ignore if already liked (conflict)
      if (!e.toString().contains('duplicate key')) {
        rethrow;
      }
    }
  }

  /// Removes like from a ripple.
  Future<void> unlikeRipple(String rippleId, String userId) async {
    await _supabase.from(SupabaseConfig.rippleLikesTable).delete().match({
      'ripple_id': rippleId,
      'user_id': userId,
    });
  }

  /// Saves a ripple.
  Future<void> saveRipple(String rippleId, String userId) async {
    try {
      await _supabase.from(SupabaseConfig.rippleSavesTable).insert({
        'ripple_id': rippleId,
        'user_id': userId,
      });
    } catch (e) {
      // Ignore if already saved (conflict)
      if (!e.toString().contains('duplicate key')) {
        rethrow;
      }
    }
  }

  /// Removes a ripple from saved.
  Future<void> unsaveRipple(String rippleId, String userId) async {
    await _supabase.from(SupabaseConfig.rippleSavesTable).delete().match({
      'ripple_id': rippleId,
      'user_id': userId,
    });
  }

  /// Comments on a ripple.
  Future<RippleCommentEntity> commentOnRipple({
    required String rippleId,
    required String userId,
    required String content,
  }) async {
    final data =
        await _supabase
            .from(SupabaseConfig.rippleCommentsTable)
            .insert({
              'ripple_id': rippleId,
              'user_id': userId,
              'content': content,
            })
            .select()
            .single();

    return RippleCommentEntity.fromJson(data);
  }

  /// Gets comments for a ripple.
  Future<List<RippleCommentEntity>> getComments(String rippleId) async {
    final response = await _supabase
        .from(SupabaseConfig.rippleCommentsTable)
        .select('*, ${SupabaseConfig.profilesTable}:user_id(username, avatar_url)')
        .eq('ripple_id', rippleId)
        .order('created_at', ascending: true);

    return response.map((json) => RippleCommentEntity.fromJson(json)).toList();
  }

  /// Gets a single ripple by ID.
  Future<RippleEntity?> getRippleById(String rippleId) async {
    final userId = _supabase.auth.currentUser?.id;

    final response =
        await _supabase
            .from(SupabaseConfig.ripplesTable)
            .select('''
          *,
          ${SupabaseConfig.profilesTable}:user_id (
            username,
            avatar_url,
            is_private
          ),
          ${SupabaseConfig.rippleLikesTable}!left (
            user_id
          ),
          ${SupabaseConfig.rippleSavesTable}!left (
            user_id
          )
        ''')
            .eq('id', rippleId)
            .maybeSingle();

    if (response == null) return null;

    final ripple = Map<String, dynamic>.from(response);
    final likes = ripple[SupabaseConfig.rippleLikesTable] as List<dynamic>?;
    ripple['is_liked'] =
        likes != null && likes.any((l) => l['user_id'] == userId);
    ripple.remove(SupabaseConfig.rippleLikesTable);

    final saves = ripple[SupabaseConfig.rippleSavesTable] as List<dynamic>?;
    ripple['is_saved'] =
        saves != null && saves.any((s) => s['user_id'] == userId);
    ripple.remove(SupabaseConfig.rippleSavesTable);

    return RippleEntity.fromJson(ripple);
  }

  /// Gets saved ripples for a specific user.
  Future<List<RippleEntity>> getSavedRipples(String userId) async {
    final response = await _supabase
        .from(SupabaseConfig.rippleSavesTable)
        .select('''
          ripple_id,
          ${SupabaseConfig.ripplesTable} (
            *,
            ${SupabaseConfig.profilesTable}:user_id (
              username,
              avatar_url,
              is_private
            ),
            ${SupabaseConfig.rippleLikesTable}!left (
              user_id
            ),
            ${SupabaseConfig.rippleSavesTable}!left (
              user_id
            )
          )
        ''')
        .eq('user_id', userId);

    final List<dynamic> data = response as List<dynamic>;
    final ripplesData = <Map<String, dynamic>>[];

    for (var item in data) {
      if (item[SupabaseConfig.ripplesTable] != null) {
        final ripple = Map<String, dynamic>.from(item[SupabaseConfig.ripplesTable]);
        
        // Process likes/saves for the ripple
        final likes = ripple[SupabaseConfig.rippleLikesTable] as List<dynamic>?;
        ripple['is_liked'] = likes != null && likes.any((l) => l['user_id'] == userId);
        ripple.remove(SupabaseConfig.rippleLikesTable);

        final saves = ripple[SupabaseConfig.rippleSavesTable] as List<dynamic>?;
        ripple['is_saved'] = saves != null && saves.any((s) => s['user_id'] == userId);
        ripple.remove(SupabaseConfig.rippleSavesTable);

        ripplesData.add(ripple);
      }
    }

    return ripplesData.map((json) => RippleEntity.fromJson(json)).toList();
  }
}
