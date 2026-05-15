import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/feed/domain/models/comment.dart';
import 'package:oasis/services/comment_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/feed/presentation/providers/feed_provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:oasis/widgets/moderation_dialogs.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Comment> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _error;
  Comment? _replyingTo;
  RealtimeChannel? _commentsChannel;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _subscribeToComments();
  }

  @override
  void dispose() {
    if (_commentsChannel != null) {
      _commentService.unsubscribeFromComments(_commentsChannel!);
    }
    _commentController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _uploadVoiceComment(path);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/comment_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _uploadVoiceComment(String path) async {
    // UI placeholder for now
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice comments are coming soon to posts!')),
    );
  }

  void _subscribeToComments() {
    _commentsChannel = _commentService.subscribeToPostComments(
      postId: widget.postId,
      onCommentAdded: (commentData) {
        if (mounted) {
          try {
            final newComment = Comment.fromJson(commentData);
            setState(() {
              if (!_comments.any((c) => c.id == newComment.id)) {
                _comments.insert(0, newComment);
              }
            });
          } catch (e) {
            debugPrint('Error adding comment: $e');
          }
        }
      },
      onCommentDeleted: (commentId) {
        if (mounted) {
          setState(() {
            _comments.removeWhere((c) => c.id == commentId);
          });
        }
      },
    );
  }

  Future<void> _loadComments() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final comments = await _commentService.getPostComments(
        postId: widget.postId,
        currentUserId: userId,
      );

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final comment = await _commentService.createComment(
        userId: userId,
        postId: widget.postId,
        content: _commentController.text.trim(),
        parentCommentId: _replyingTo?.id,
      );

      setState(() {
        if (_replyingTo == null) {
          _comments.insert(0, comment);
        }
        _commentController.clear();
        _replyingTo = null;
        _isSubmitting = false;
      });

      if (mounted && _replyingTo == null) {
        context.read<FeedProvider>().incrementCommentCount(widget.postId);
      }

      // Scroll to top to show new comment
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _likeComment(Comment comment) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      if (comment.isLiked) {
        await _commentService.unlikeComment(
          userId: userId,
          commentId: comment.id,
        );
      } else {
        await _commentService.likeComment(
          userId: userId,
          commentId: comment.id,
        );
      }

      // Update local state
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = comment.copyWith(
            isLiked: !comment.isLiked,
            likes: comment.isLiked ? comment.likes - 1 : comment.likes + 1,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      await _commentService.deleteComment(
        commentId: comment.id,
        userId: userId,
      );

      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showCommentOptions(Comment comment) {
    final userId = _authService.currentUser?.id;
    final isOwnComment = comment.userId == userId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnComment) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(comment);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(Comment comment) {
    ReportDialog.show(context, commentId: comment.id, userId: comment.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userId = _authService.currentUser?.id;

    final content = Scaffold(
      appBar: AppBar(title: const Text('Comments'), elevation: 0),
      body: Column(
        children: [
          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadComments,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return _buildCommentItem(comment, userId);
                    },
                  ),
          ),

          // Reply indicator
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo!.username}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop_circle : Icons.mic_none_rounded,
                      color: _isRecording
                          ? Colors.red
                          : colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _toggleRecording,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? 'Recording...'
                            : 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isRecording,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: (_isSubmitting || _isRecording)
                        ? null
                        : _submitComment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return ResponsiveLayout.isDesktop(context)
        ? MaxWidthContainer(
            maxWidth: ResponsiveLayout.maxCommentsWidth,
            child: content,
          )
        : content;
  }

  Widget _buildCommentItem(Comment comment, String? currentUserId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.userAvatar.isNotEmpty
                ? CachedNetworkImageProvider(comment.userAvatar)
                : null,
            child: comment.userAvatar.isEmpty
                ? Text(comment.username[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () => _showCommentOptions(comment),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _likeComment(comment),
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: comment.isLiked ? Colors.red : null,
                          ),
                          if (comment.likes > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${comment.likes}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () {
                        setState(() => _replyingTo = comment);
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      child: Text(
                        'Reply',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
