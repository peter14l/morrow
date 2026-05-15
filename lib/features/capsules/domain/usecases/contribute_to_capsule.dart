import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/features/capsules/domain/repositories/capsule_repository.dart';

/// Use case to contribute to an existing time capsule
class ContributeToCapsule {
  final CapsuleRepository _repository;

  ContributeToCapsule(this._repository);

  Future<TimeCapsule> call({
    required String capsuleId,
    required String content,
    String? mediaUrl,
    String mediaType = 'none',
  }) {
    return _repository.contributeToCapsule(
      capsuleId: capsuleId,
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );
  }
}
