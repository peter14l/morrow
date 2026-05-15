import 'package:oasis/features/feed/domain/models/enhanced_poll.dart';

/// Create or manage a poll attached to a post.
class ManagePoll {
  ManagePoll();

  /// Create a poll (stored as part of post content).
  Future<EnhancedPoll> call({
    required String postId,
    required String question,
    required List<String> options,
    PollType pollType = PollType.single,
    bool isAnonymous = false,
    DateTime? endsAt,
  }) async {
    final pollId = DateTime.now().millisecondsSinceEpoch.toString();
    final pollOptions = options.asMap().entries.map((entry) {
      return PollOption(
        id: '${pollId}_${entry.key}',
        pollId: pollId,
        text: entry.value,
        order: entry.key,
      );
    }).toList();

    return EnhancedPoll(
      id: pollId,
      postId: postId,
      question: question,
      pollType: pollType,
      isAnonymous: isAnonymous,
      endsAt: endsAt,
      createdAt: DateTime.now(),
      options: pollOptions,
    );
  }
}
