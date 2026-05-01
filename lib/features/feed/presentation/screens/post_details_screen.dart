import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/feed/domain/models/post.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/services/post_service.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailsScreen extends StatefulWidget {
  final String postId;
  final Post? initialPost;

  const PostDetailsScreen({super.key, required this.postId, this.initialPost});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  final PostService _postService = PostService();
  Post? _post;
  bool _isLoading = true;
  String? _error;

  AuthService get _authService => context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
      _isLoading = false;
    } else {
      _loadPost();
    }
  }

  Future<void> _loadPost() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) {
      if (mounted) context.pop();
      return;
    }

    try {
      final post = await _postService.getPost(widget.postId, userId);
      if (mounted) {
        setState(() {
          _post = post;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_post == null) return;

    final themeProvider = context.read<ThemeProvider>();
    final useFluent = themeProvider.useFluentUI;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    bool confirm = false;

    if (useFluent && isDesktop) {
      final result = await fluent.showDialog<String>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            fluent.Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, 'cancel'),
            ),
            fluent.FilledButton(
              onPressed: () => Navigator.pop(context, 'delete'),
              style: fluent.ButtonStyle(
                backgroundColor: fluent.WidgetStateProperty.all(fluent.Colors.red),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      confirm = result == 'delete';
    } else {
      final result = await material.showDialog<bool>(
        context: context,
        builder: (context) => material.AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            material.TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            material.TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const material.Text(
                'Delete',
                style: material.TextStyle(color: material.Colors.red),
              ),
            ),
          ],
        ),
      );
      confirm = result ?? false;
    }

    if (!confirm) return;

    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    try {
      await _postService.deletePost(_post!.id, userId);
      if (mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          const material.SnackBar(content: Text('Post deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          material.SnackBar(content: Text('Error deleting post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: const Text('Post Details'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: material.CircularProgressIndicator());
    }

    if (_error != null) {
      final theme = material.ThemeData.light(); // Fallback or use context theme
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(material.Icons.error_outline, size: 48, color: material.Colors.grey),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            material.ElevatedButton(
              onPressed: _loadPost,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_post == null) {
      return const Center(child: Text('Post not found'));
    }

    final currentUserId = _authService.currentUser?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: material.Column(
        children: [
          PostCard(
            post: _post!,
            isOwnPost: _post!.userId == currentUserId,
            onLike: () async {
              final userId = _authService.currentUser?.id;
              if (userId == null || _post == null) return;

              final wasLiked = _post!.isLiked;
              final newLikes = wasLiked
                  ? (_post!.likes > 0 ? _post!.likes - 1 : 0)
                  : _post!.likes + 1;

              setState(() {
                _post = _post!.copyWith(
                  isLiked: !wasLiked,
                  likes: newLikes,
                );
              });

              try {
                if (wasLiked) {
                  await _postService.unlikePost(_post!.id, userId);
                } else {
                  await _postService.likePost(userId: userId, postId: _post!.id);
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _post = _post!.copyWith(
                      isLiked: wasLiked,
                      likes: wasLiked ? _post!.likes + 1 : (_post!.likes > 0 ? _post!.likes - 1 : 0),
                    );
                  });
                }
              }
            },
            onBookmark: () async {
              final userId = _authService.currentUser?.id;
              if (userId == null || _post == null) return;

              final wasBookmarked = _post!.isBookmarked;
              setState(() {
                _post = _post!.copyWith(isBookmarked: !wasBookmarked);
              });

              try {
                if (wasBookmarked) {
                  await _postService.unbookmarkPost(userId: userId, postId: _post!.id);
                } else {
                  await _postService.bookmarkPost(userId: userId, postId: _post!.id);
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _post = _post!.copyWith(isBookmarked: wasBookmarked);
                  });
                }
              }
            },
            onComment: () {
              context.push('/post/${_post!.id}/comments');
            },
            onShare: () {
              final deepLink = AppConfig.getWebUrl('/post/${_post!.id}');
              Share.share('Check out this post on Oasis! $deepLink');
            },
            onDelete: _handleDelete,
          ),
        ],
      ),
    );
  }
}
