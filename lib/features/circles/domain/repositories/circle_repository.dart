import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

abstract class CircleRepository {
  Future<List<CircleEntity>> getCircles(String userId);

  Future<CircleEntity> getCircle(String circleId);

  Future<CircleEntity> createCircle({
    required String createdBy,
    required String name,
    required String emoji,
    required List<String> memberIds,
  });

  Future<void> deleteCircle(String circleId);

  Future<void> joinCircle(String circleId, String userId);

  Future<void> leaveCircle(String circleId, String userId);

  Future<List<CommitmentEntity>> getCommitments({
    required String circleId,
    DateTime? date,
  });

  Future<List<Post>> getCircleFeed({
    required String circleId,
    required String userId,
    int limit = 20,
    int offset = 0,
  });

  Future<Post> createCirclePost({
    required String circleId,
    required String userId,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
  });

  Future<CommitmentEntity> createCommitment({
    required String circleId,
    required String createdBy,
    required String title,
    String? description,
    DateTime? dueDate,
  });

  Future<void> setIntent({
    required String commitmentId,
    required String userId,
    required MemberIntent intent,
  });

  Future<void> markComplete({
    required String commitmentId,
    required String userId,
    String? note,
  });

  Stream<List<CommitmentEntity>> subscribeToCommitments({
    required String circleId,
    DateTime? date,
  });
}
