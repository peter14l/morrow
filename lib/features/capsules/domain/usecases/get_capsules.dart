import 'package:oasis/features/capsules/domain/models/time_capsule_entity.dart';
import 'package:oasis/features/capsules/domain/repositories/capsule_repository.dart';

/// Use case to get all capsules for a user
class GetCapsules {
  final CapsuleRepository _repository;

  GetCapsules(this._repository);

  Future<List<TimeCapsule>> call({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.getCapsules(
      userId: userId,
      limit: limit,
      offset: offset,
    );
  }
}
