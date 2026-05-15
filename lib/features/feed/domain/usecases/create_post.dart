import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/domain/repositories/post_repository.dart';

/// Create a new post with optional media and mood.
class CreatePost {
  final PostRepository _repository;

  CreatePost(this._repository);

  Future<Post> call({
    required String userId,
    required String? content,
    List<String>? mediaFiles,
    List<String>? mediaTypes,
    String? communityId,
    String? mood,
    List<String>? collaboratorIds,
  }) {
    return _repository.createPost(
      userId: userId,
      content: content,
      mediaFiles: mediaFiles,
      mediaTypes: mediaTypes,
      communityId: communityId,
      mood: mood,
      collaboratorIds: collaboratorIds,
    );
  }
}
