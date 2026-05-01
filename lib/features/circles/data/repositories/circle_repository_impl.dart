import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:oasis/features/circles/domain/repositories/circle_repository.dart';
import 'package:oasis/features/circles/data/datasources/circle_remote_datasource.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

class CircleRepositoryImpl implements CircleRepository {
  final CircleRemoteDatasource _remoteDatasource;

  CircleRepositoryImpl({CircleRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? CircleRemoteDatasource();

  @override
  Future<List<CircleEntity>> getCircles(String userId) async {
    final rawCircles = await _remoteDatasource.fetchUserCircles(userId);
    return rawCircles.map((json) => CircleEntity.fromJson(json)).toList();
  }

  @override
  Future<CircleEntity> getCircle(String circleId) async {
    final circleMap = await _remoteDatasource.getCircle(circleId);
    return CircleEntity.fromJson(circleMap);
  }

  @override
  Future<CircleEntity> createCircle({
    required String createdBy,
    required String name,
    required String emoji,
    required List<String> memberIds,
  }) async {
    final circleMap = await _remoteDatasource.createCircle(
      createdBy: createdBy,
      name: name,
      emoji: emoji,
      memberIds: memberIds,
    );
    return CircleEntity.fromJson(circleMap);
  }

  @override
  Future<void> deleteCircle(String circleId) async {
    await _remoteDatasource.deleteCircle(circleId);
  }

  @override
  Future<void> joinCircle(String circleId, String userId) async {
    await _remoteDatasource.joinCircle(circleId, userId);
  }

  @override
  Future<void> leaveCircle(String circleId, String userId) async {
    await _remoteDatasource.leaveCircle(circleId, userId);
  }

  @override
  Future<List<Post>> getCircleFeed({
    required String circleId,
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rawPosts = await _remoteDatasource.getCircleFeed(
      circleId: circleId,
      userId: userId,
      limit: limit,
      offset: offset,
    );
    return rawPosts.map((json) => Post.fromJson(json)).toList();
  }

  @override
  Future<Post> createCirclePost({
    required String circleId,
    required String userId,
    String? content,
    List<String> mediaUrls = const [],
    List<String> mediaTypes = const [],
    String? mood,
    List<String> hashtags = const [],
    bool isSpoiler = false,
    Map<String, dynamic>? poll,
  }) async {
    final postMap = await _remoteDatasource.createCirclePost(
      circleId: circleId,
      userId: userId,
      content: content,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      mood: mood,
      hashtags: hashtags,
      isSpoiler: isSpoiler,
      poll: poll,
    );
    return Post.fromJson(postMap);
  }

  @override
  Future<List<CommitmentEntity>> getCommitments({
    required String circleId,
    DateTime? date,
  }) async {
    final rawCommitments = await _remoteDatasource.getCommitments(
      circleId: circleId,
      date: date,
    );
    return rawCommitments
        .map((json) => CommitmentEntity.fromJson(json))
        .toList();
  }

  @override
  Future<CommitmentEntity> createCommitment({
    required String circleId,
    required String createdBy,
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    final commitmentMap = await _remoteDatasource.createCommitment(
      circleId: circleId,
      createdBy: createdBy,
      title: title,
      description: description,
      dueDate: dueDate,
    );
    return CommitmentEntity.fromJson(commitmentMap);
  }

  @override
  Future<void> setIntent({
    required String commitmentId,
    required String userId,
    required MemberIntent intent,
  }) async {
    await _remoteDatasource.setIntent(
      commitmentId: commitmentId,
      userId: userId,
      intent: intent,
    );
  }

  @override
  Future<void> markComplete({
    required String commitmentId,
    required String userId,
    String? note,
  }) async {
    await _remoteDatasource.markComplete(
      commitmentId: commitmentId,
      userId: userId,
      note: note,
    );
  }

  @override
  Stream<List<CommitmentEntity>> subscribeToCommitments({
    required String circleId,
    DateTime? date,
  }) {
    return _remoteDatasource
        .subscribeToCommitments(circleId: circleId, date: date)
        .map(
          (rawList) =>
              rawList.map((json) => CommitmentEntity.fromJson(json)).toList(),
        );
  }
}
