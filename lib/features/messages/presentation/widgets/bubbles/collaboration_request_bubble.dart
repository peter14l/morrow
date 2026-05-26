import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/services/post_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

class CollaborationRequestBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const CollaborationRequestBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<CollaborationRequestBubble> createState() =>
      _CollaborationRequestBubbleState();
}

class _CollaborationRequestBubbleState
    extends State<CollaborationRequestBubble> {
  bool _isLoading = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.message.shareData?['status'] ?? 'pending';
  }

  Future<void> _handleAction(bool accept) async {
    setState(() => _isLoading = true);
    HapticUtils.selectionClick();

    try {
      final postService = PostService();
      final userId = AuthService().currentUser?.id;
      if (userId == null) return;

      if (accept) {
        await postService.acceptCollaboration(widget.message.postId!, userId);
        setState(() => _status = 'accepted');
      } else {
        await postService.declineCollaboration(widget.message.postId!, userId);
        setState(() => _status = 'denied');
      }

      // Update message state in Supabase if needed (optional, status in shareData)
      // For now, we assume the UI reflects the local change and the user can re-fetch.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shareData = widget.message.shareData;

    final username = widget.message.senderName.isNotEmpty
        ? widget.message.senderName
        : 'User';
    final userAvatar = widget.message.senderAvatar;
    final postContent = widget.message.content;
    final mediaUrl = widget.message.mediaUrl;

    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: widget.isMe
            ? colorScheme.primary.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage:
                      (userAvatar.isNotEmpty) ? NetworkImage(userAvatar) : null,
                  child: (userAvatar.isEmpty)
                      ? Text(username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 10))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$username invited you to collaborate',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Post Preview
          InkWell(
            onTap: () {
              if (widget.message.postId != null) {
                context.push('/post/${widget.message.postId}');
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mediaUrl != null && mediaUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    postContent.isNotEmpty ? postContent : 'Collaborative Post',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildFooter(colorScheme),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: card,
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    if (_status == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text(
              'Collaboration Accepted',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_status == 'denied') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 16),
            SizedBox(width: 8),
            Text(
              'Collaboration Declined',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Waiting for response...',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => _handleAction(false),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: colorScheme.error),
              foregroundColor: colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _isLoading ? null : () => _handleAction(true),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Accept'),
          ),
        ),
      ],
    );
  }
}
