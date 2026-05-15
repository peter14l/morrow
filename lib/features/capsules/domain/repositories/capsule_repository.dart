import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';

/// Repository interface for Time Capsule operations
abstract class CapsuleRepository {
  /// Get all capsules for a user
  Future<List<TimeCapsule>> getCapsules({
    required String userId,
    int limit = 20,
    int offset = 0,
  });

  /// Get a single capsule by ID
  Future<TimeCapsule?> getCapsuleById(String capsuleId);

  /// Create a new time capsule
  Future<TimeCapsule> createCapsule({
    required String userId,
    required String content,
    required DateTime unlockDate,
    String? mediaUrl,
    String mediaType = 'none',
  });

  /// Open/unlock a capsule (when unlock date is reached)
  Future<TimeCapsule> openCapsule(String capsuleId);

  /// Contribute to an existing capsule (add content)
  Future<TimeCapsule> contributeToCapsule({
    required String capsuleId,
    required String content,
    String? mediaUrl,
    String mediaType = 'none',
  });

  /// Delete a capsule
  Future<void> deleteCapsule(String capsuleId);
}
