import 'package:oasis/features/circles/domain/models/circles_models.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

class CircleState {
  final List<CircleEntity> circles;
  final CircleEntity? activeCircle;
  final List<Post> circleFeed;
  final List<CommitmentEntity> todaysCommitments;
  final bool isLoading;
  final bool isLoadingFeed;
  final bool hasMoreFeed;
  final String? error;

  const CircleState({
    this.circles = const [],
    this.activeCircle,
    this.circleFeed = const [],
    this.todaysCommitments = const [],
    this.isLoading = false,
    this.isLoadingFeed = false,
    this.hasMoreFeed = true,
    this.error,
  });

  CircleState copyWith({
    List<CircleEntity>? circles,
    CircleEntity? activeCircle,
    List<Post>? circleFeed,
    List<CommitmentEntity>? todaysCommitments,
    bool? isLoading,
    bool? isLoadingFeed,
    bool? hasMoreFeed,
    String? error,
  }) {
    return CircleState(
      circles: circles ?? this.circles,
      activeCircle: activeCircle ?? this.activeCircle,
      circleFeed: circleFeed ?? this.circleFeed,
      todaysCommitments: todaysCommitments ?? this.todaysCommitments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFeed: isLoadingFeed ?? this.isLoadingFeed,
      hasMoreFeed: hasMoreFeed ?? this.hasMoreFeed,
      error: error,
    );
  }
}
