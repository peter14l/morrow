import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/messages/presentation/widgets/bubbles/bubbles.dart';
import 'package:oasis/features/messages/presentation/providers/chat_reactions_provider.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:provider/provider.dart';
import 'package:oasis/widgets/skeleton_container.dart';

import 'package:oasis/features/messages/presentation/widgets/chat/swipe_to_reply.dart';
import 'package:oasis/features/messages/presentation/widgets/chat/dissolve_effect.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:universal_io/io.dart';

/// Chat message list with skeleton loading, empty state, and message rendering.
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.currentUserId,
    required this.onMessageLongPress,
    required this.onMessageDoubleTap,
    required this.onReply,
    this.headerHeight = 72,
    this.bubbleColorSent,
    this.bubbleColorReceived,
    this.textColorSent,
    this.textColorReceived,
    this.scrollController,
    this.onReactionsTap,
    this.highlightedMessageId,
  });

  final List<Message> messages;
  final bool isLoading;
  final String? currentUserId;
  final Function(Message, Offset?) onMessageLongPress;
  final Function(Message) onMessageDoubleTap;
  final Function(Message) onReply;
  final double headerHeight;
  final Color? bubbleColorSent;
  final Color? bubbleColorReceived;
  final Color? textColorSent;
  final Color? textColorReceived;
  final ScrollController? scrollController;
  final VoidCallback? onReactionsTap;
  final String? highlightedMessageId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLoading && messages.isEmpty) {
          return _buildSkeletonLoading(context, constraints.maxWidth);
        }

        if (messages.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          reverse: true,
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + headerHeight + 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMe = message.senderId == currentUserId;
            final isHighlighted = message.id == highlightedMessageId;
            return _buildMessageItem(
                context, message, isMe, isHighlighted, constraints.maxWidth);
          },
        );
      },
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    Message message,
    bool isMe,
    bool isHighlighted,
    double maxWidth,
  ) {
    if (message.messageType == MessageType.system) {
      return SystemMessageBubble(content: message.content);
    }

    if (message.messageType == MessageType.text &&
        message.content.startsWith('[INVITE:')) {
      return InviteBubble(content: message.content, isMe: isMe);
    }

    if (message.messageType == MessageType.collaborationRequest) {
      return CollaborationRequestBubble(message: message, isMe: isMe);
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;

    return SwipeToReply(
      enabled: isMobile,
      onReply: () => onReply(message),
      child: MessageBubble(
        message: message,
        isMe: isMe,
        isHighlighted: isHighlighted,
        bubbleColorSent: bubbleColorSent,
        bubbleColorReceived: bubbleColorReceived,
        textColorSent: textColorSent,
        textColorReceived: textColorReceived,
        maxWidth: maxWidth,
        onLongPress: () => onMessageLongPress(message, null),
        onDoubleTap: () => onMessageDoubleTap(message),
        onReactionsTap: onReactionsTap,
      ),
    );
  }

  Widget _buildSkeletonLoading(BuildContext context, double maxWidth) {
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + headerHeight + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: SkeletonContainer.rounded(
              width: 150.0 + (index % 3) * 50,
              height: 40.0 + (index % 2) * 20,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(4) : null,
                bottomLeft: !isMe ? const Radius.circular(4) : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text('No messages yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Main message bubble container that wraps specialized bubble types.
/// Handles: decoration, reply preview, read receipts, reactions.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.onLongPress,
    required this.onDoubleTap,
    this.isHighlighted = false,
    this.bubbleColorSent,
    this.bubbleColorReceived,
    this.textColorSent,
    this.textColorReceived,
    this.onReactionsTap,
    required this.maxWidth,
  });

  final Message message;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final bool isHighlighted;
  final Color? bubbleColorSent;
  final Color? bubbleColorReceived;
  final Color? textColorSent;
  final Color? textColorReceived;
  final VoidCallback? onReactionsTap;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isSticker = message.messageType == MessageType.sticker;

    final bubbleColor = isHighlighted
        ? colorScheme.primary
        : isMe
        ? (bubbleColorSent ?? colorScheme.primary)
        : (bubbleColorReceived ?? colorScheme.surfaceContainerHighest);

    // Fallback text color based on bubble luminance if specific text colors aren't provided
    final Color autoTextColor = bubbleColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    final textColor = isHighlighted
        ? colorScheme.onPrimary
        : isMe
        ? (textColorSent ??
              (bubbleColorSent != null
                  ? autoTextColor
                  : colorScheme.onPrimaryContainer))
        : (textColorReceived ??
              (bubbleColorReceived != null
                  ? autoTextColor
                  : colorScheme.onSurface));

    // Final safety check: if we are using theme defaults but they are unreadable, force autoTextColor
    final Color finalTextColor;
    if (isHighlighted) {
      finalTextColor = colorScheme.onPrimary;
    } else if (isMe) {
      if (textColorSent != null) {
        finalTextColor = textColorSent!;
      } else {
        // If bubble is light but theme says onPrimaryContainer is white (or vice versa), override it
        final bool isLight = bubbleColor.computeLuminance() > 0.5;
        final bool isTextLight =
            colorScheme.onPrimaryContainer.computeLuminance() > 0.5;
        if (isLight && isTextLight) {
          finalTextColor = Colors.black87;
        } else if (!isLight && !isTextLight) {
          finalTextColor = Colors.white;
        } else {
          finalTextColor = colorScheme.onPrimaryContainer;
        }
      }
    } else {
      if (textColorReceived != null) {
        finalTextColor = textColorReceived!;
      } else {
        final bool isLight = bubbleColor.computeLuminance() > 0.5;
        final bool isTextLight = colorScheme.onSurface.computeLuminance() > 0.5;
        if (isLight && isTextLight) {
          finalTextColor = Colors.black87;
        } else if (!isLight && !isTextLight) {
          finalTextColor = Colors.white;
        } else {
          finalTextColor = colorScheme.onSurface;
        }
      }
    }

    final Widget content = _buildContent(context, finalTextColor);

    final isWhisper = message.isEphemeral || message.whisperMode != 'OFF';

    final bubbleDecoration = isSticker
        ? null
        : BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(24).copyWith(
              bottomRight: isMe ? const Radius.circular(8) : null,
              bottomLeft: !isMe ? const Radius.circular(8) : null,
            ),
            border: isWhisper
                ? Border.all(
                    color: textColor.withValues(alpha: 0.5),
                    width: 1.5,
                    style: BorderStyle
                        .solid, // Note: standard Border doesn't support dashed.
                    // I should probably use a CustomPainter or a wrapper if I want TRUE dashed.
                    // For now, I'll use a specific color/width to differentiate.
                  )
                : Border.all(
                    color: isHighlighted
                        ? colorScheme.primaryContainer
                        : colorScheme.outlineVariant.withValues(alpha: 0.1),
                    width: isHighlighted ? 2.0 : 0.1,
                  ),
            boxShadow: [
              if (isHighlighted)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  blurRadius: 15,
                  spreadRadius: 4,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          );

    final isOptimistic = message.id.startsWith('optimistic_');

    final Widget bubbleWithEffect = DissolveEffect(
      isDissolving: isOptimistic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: isSticker
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: bubbleDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToId != null && !isSticker)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: isMe
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToSenderName ?? 'Unknown',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isMe
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            message.replyToContent ?? 'Original message',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isMe
                                  ? colorScheme.onPrimaryContainer.withValues(
                                      alpha: 0.7,
                                    )
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            content,
            if (!isSticker)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.pqAuraHeader != null)
                      Icon(
                        FluentIcons.shield_lock_24_filled,
                        size: 10,
                        color: isMe
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    if (message.pqAuraHeader != null) const SizedBox(width: 4),
                    if (isMe)
                      Icon(
                        isOptimistic ? Icons.access_time : Icons.done_all,
                        size: 14,
                        color: message.isRead
                            ? (isDesktop ? Colors.blue : Colors.blueAccent)
                            : colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.6,
                              ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: isDesktop
                ? maxWidth * 0.85
                : maxWidth * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              bubbleWithEffect,
              // Reaction badges below the bubble
              if (message.reactions.isNotEmpty)
                _buildReactionBadges(context, isMe),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    switch (message.messageType) {
      case MessageType.text:
        return TextBubble(
          content: message.content,
          isMe: isMe,
          textColor: textColor,
          isSpoiler: message.isSpoiler,
        );
      case MessageType.gif:
        return ImageBubble(message: message, isMe: isMe, textColor: textColor);
      case MessageType.sticker:
        return SizedBox(
          width: 140,
          height: 140,
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl ?? '',
            placeholder: (context, url) => const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            fit: BoxFit.contain,
          ),
        );
      case MessageType.image:
        return ImageBubble(message: message, isMe: isMe, textColor: textColor);
      case MessageType.document:
        if (message.mediaUrl?.contains('videos') ?? false) {
          return VideoBubble(
            message: message,
            isMe: isMe,
            textColor: textColor,
          );
        }
        return DocumentBubble(
          message: message,
          isMe: isMe,
          textColor: textColor,
        );
      case MessageType.voice:
        return VoiceBubble(message: message, isMe: isMe, textColor: textColor);
      case MessageType.postShare:
        return PostShareBubble(message: message, isMe: isMe);
      case MessageType.ripple:
        return RippleShareBubble(message: message, isMe: isMe);
      case MessageType.storyReply:
        return StoryReplyBubble(
          message: message,
          isMe: isMe,
          formatTime: _formatTime,
        );
      case MessageType.location:
        return LocationBubble(
          message: message,
          isMe: isMe,
          conversationId: message.conversationId,
        );
      default:
        return TextBubble(
          content: message.content,
          isMe: isMe,
          textColor: textColor,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildReactionBadges(BuildContext context, bool isMe) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupedReactions =
        ChatReactionsProvider(
          messagingService: context.read<MessagingService>(),
        ).groupReactions(
          message.reactions,
          null, // currentUserId not needed for display grouping
        );

    if (groupedReactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: isMe ? 0 : 4,
        right: isMe ? 4 : 0,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: groupedReactions.map((group) {
          final hasCurrentUser = group.hasCurrentUserReacted;
          return GestureDetector(
            onTap: onReactionsTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasCurrentUser
                    ? colorScheme.primaryContainer.withValues(alpha: 0.8)
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasCurrentUser
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outline.withValues(alpha: 0.2),
                  width: hasCurrentUser ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(group.emoji, style: const TextStyle(fontSize: 14)),
                  if (group.count > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      '${group.count}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasCurrentUser
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
