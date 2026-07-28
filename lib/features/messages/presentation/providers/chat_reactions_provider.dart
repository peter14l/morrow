import 'package:flutter/foundation.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/domain/models/message_reaction.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';

/// Grouped reaction for display in the UI.
class GroupedReaction {
  final String emoji;
  final int count;
  final List<String> usernames;
  final bool hasCurrentUserReacted;

  const GroupedReaction({
    required this.emoji,
    required this.count,
    required this.usernames,
    required this.hasCurrentUserReacted,
  });
}

/// Provider handling all message reaction logic.
class ChatReactionsProvider with ChangeNotifier {
  final MessagingService _messagingService;

  ChatReactionsProvider({required MessagingService messagingService})
    : _messagingService = messagingService;

  /// Group individual reactions by emoji for display.
  static List<GroupedReaction> groupReactions(
    List<MessageReactionModel> reactions,
    String? currentUserId,
  ) {
    final groups = <String, GroupedReaction>{};

    for (final reaction in reactions) {
      if (groups.containsKey(reaction.reaction)) {
        final group = groups[reaction.reaction]!;
        groups[reaction.reaction] = GroupedReaction(
          emoji: group.emoji,
          count: group.count + 1,
          usernames: [...group.usernames, reaction.username],
          hasCurrentUserReacted:
              group.hasCurrentUserReacted || reaction.userId == currentUserId,
        );
      } else {
        groups[reaction.reaction] = GroupedReaction(
          emoji: reaction.reaction,
          count: 1,
          usernames: [reaction.username],
          hasCurrentUserReacted: reaction.userId == currentUserId,
        );
      }
    }
    return groups.values.toList();
  }

  /// Add, remove, or toggle a reaction on a message.
  Future<void> onReactionSelected({
    required Message message,
    required String reaction,
    required String userId,
    required String username,
    required List<MessageReactionModel> currentReactions,
    required Function(List<MessageReactionModel>) onReactionsUpdated,
    Function(String)? onError,
  }) async {
    // Optimistic update
    final updatedReactions = List<MessageReactionModel>.from(currentReactions);

    final existingIndex = updatedReactions.indexWhere(
      (r) => r.userId == userId && r.reaction == reaction,
    );

    // Also check if user has ANY reaction to replace it
    final anyReactionIndex = updatedReactions.indexWhere(
      (r) => r.userId == userId,
    );

    if (existingIndex >= 0) {
      // Remove same reaction (toggle off)
      updatedReactions.removeAt(existingIndex);
    } else {
      // If user has a different reaction, remove it first (standard behavior)
      if (anyReactionIndex >= 0) {
        updatedReactions.removeAt(anyReactionIndex);
      }

      // Add new reaction
      updatedReactions.add(
        MessageReactionModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          messageId: message.id,
          userId: userId,
          username: username,
          reaction: reaction,
          createdAt: DateTime.now(),
        ),
      );
    }

    // Notify UI of optimistic update
    onReactionsUpdated(updatedReactions);

    try {
      if (existingIndex >= 0) {
        // Toggle off: remove reaction
        await _messagingService.removeReaction(
          messageId: message.id,
          userId: userId,
          emoji: reaction,
        );
      } else {
        // Add new reaction
        await _messagingService.addReaction(
          messageId: message.id,
          userId: userId,
          emoji: reaction,
          username: username,
        );
      }
    } catch (e) {
      debugPrint('Error updating reaction: $e');
      onError?.call('Failed to update reaction');
      // Caller should revert optimistic update if needed
    }
  }
}
