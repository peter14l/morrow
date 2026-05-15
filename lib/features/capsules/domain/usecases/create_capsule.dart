import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/features/capsules/domain/repositories/capsule_repository.dart';

/// Use case to create a new time capsule
class CreateCapsule {
  final CapsuleRepository _repository;

  CreateCapsule(this._repository);

  Future<TimeCapsule> call({
    required String userId,
    required String content,
    required DateTime unlockDate,
    String? mediaUrl,
    String mediaType = 'none',
  }) {
    return _repository.createCapsule(
      userId: userId,
      content: content,
      unlockDate: unlockDate,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }
}
