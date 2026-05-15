import 'package:oasis/features/feed/domain/models/post.dart';

/// Immutable UI state for the feed feature.
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? cursor;
  final bool hasMore;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.cursor,
    this.hasMore = true,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? cursor,
    bool? hasMore,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// Deprecated: Keeping for compatibility if needed elsewhere temporarily
enum FeedType { forYou, following }
