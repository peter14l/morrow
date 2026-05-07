import 'dart:io';
import 'package:oasis/features/ripples/domain/models/ripple_entity.dart';

/// Repository interface for ripples - defines the contract for data operations.
/// This is the domain layer abstraction that decouples the presentation layer
/// from the underlying data sources (Supabase, local cache, etc.)
abstract class RippleRepository {
  /// Fetches all ripples visible to the current user.
  /// Returns ripples that are either public or owned by the user.
  Future<List<RippleEntity>> getRipples();

  /// Uploads a video file and creates a new ripple.
  Future<RippleEntity> uploadAndCreateRipple({
    required File videoFile,
    String? caption,
    bool isPrivate = false,
  });

  /// Creates a new ripple with the given video URL and caption.
  Future<RippleEntity> createRipple({
    required String videoUrl,
    String? caption,
    bool isPrivate = false,
  });

  /// Deletes a ripple by ID. Only the owner can delete.
  Future<void> deleteRipple(String rippleId);

  /// Likes a ripple.
  Future<void> likeRipple(String rippleId);

  /// Removes like from a ripple.
  Future<void> unlikeRipple(String rippleId);

  /// Saves a ripple to user's collection.
  Future<void> saveRipple(String rippleId);

  /// Removes a ripple from user's saved collection.
  Future<void> unsaveRipple(String rippleId);

  /// Adds a comment to a ripple.
  Future<RippleCommentEntity> commentOnRipple({
    required String rippleId,
    required String content,
  });

  /// Fetches comments for a ripple.
  Future<List<RippleCommentEntity>> getComments(String rippleId);

  /// Gets a single ripple by ID.
  Future<RippleEntity?> getRippleById(String rippleId);

  /// Fetches saved ripples for a specific user.
  Future<List<RippleEntity>> getSavedRipples(String userId);
}
