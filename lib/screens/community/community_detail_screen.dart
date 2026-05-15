import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/providers/community_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/widgets/comments_modal.dart';
import 'package:share_plus/share_plus.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  void _loadCommunity() {
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      context.read<CommunityProvider>().loadCommunity(
        widget.communityId,
        userId,
      );
      context.read<CommunityProvider>().loadCommunityPosts(widget.communityId);
    }
  }

  Future<void> _handleJoinLeave() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    final provider = context.read<CommunityProvider>();

    try {
      if (provider.isMember) {
        await provider.leaveCommunity(
          userId: userId,
          communityId: widget.communityId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Left community')));
        }
      } else {
        await provider.joinCommunity(
          userId: userId,
          communityId: widget.communityId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Joined community!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<CommunityProvider>(
      builder: (context, provider, child) {
        final community = provider.selectedCommunity;

        if (provider.isLoading && community == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (community == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text('Community not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          floatingActionButton: provider.isMember
              ? FloatingActionButton.extended(
                  onPressed: () {
                    context.push('/create-post', extra: widget.communityId);
                    // Note: You need to make sure your router creates CreatePostScreen with the extra as communityId
                  },
                  label: const Text('Post'),
                  icon: const Icon(Icons.edit),
                )
              : null,
          body: CustomScrollView(
            slivers: [
              // App Bar with Community Header
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    community.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.groups,
                        size: 64,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),

              // Community Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      Row(
                        children: [
                          _buildStatColumn(
                            context,
                            '${community.membersCount}',
                            'Members',
                          ),
                          const SizedBox(width: 32),
                          _buildStatColumn(
                            context,
                            '${community.postsCount}',
                            'Posts',
                          ),
                          const Spacer(),
                          if (community.isPrivate)
                            const Chip(
                              label: Text('Private'),
                              avatar: Icon(Icons.lock_outline, size: 16),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'About',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        community.description,
                        style: theme.textTheme.bodyMedium,
                      ),

                      // Rules
                      if (community.rules != null &&
                          community.rules!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Rules',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          community.rules!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Join/Leave Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _handleJoinLeave,
                          icon: Icon(
                            provider.isMember ? Icons.check : Icons.add,
                          ),
                          label: Text(
                            provider.isMember ? 'Joined' : 'Join Community',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: provider.isMember
                                ? colorScheme.surfaceContainerHighest
                                : colorScheme.primary,
                            foregroundColor: provider.isMember
                                ? colorScheme.onSurface
                                : colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Posts Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Posts',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Posts List (placeholder)
              // Posts List
              if (provider.communityPosts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No posts yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to post in this community!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final post = provider.communityPosts[index];
                    return PostCard(
                      post: post,
                      showInteractionButtons: false,
                      isOwnPost: post.userId == _authService.currentUser?.id,
                      onLike: () {
                        final userId = _authService.currentUser?.id;
                        if (userId == null) return;
                        if (post.isLiked) {
                          provider.unlikePost(userId: userId, postId: post.id);
                        } else {
                          provider.likePost(userId: userId, postId: post.id);
                        }
                      },
                      onBookmark: () {
                        final userId = _authService.currentUser?.id;
                        if (userId == null) return;
                        if (post.isBookmarked) {
                          provider.unbookmarkPost(
                            userId: userId,
                            postId: post.id,
                          );
                        } else {
                          provider.bookmarkPost(
                            userId: userId,
                            postId: post.id,
                          );
                        }
                      },
                      onComment: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useRootNavigator: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CommentsModal(postId: post.id),
                        );
                      },
                      onShare: () {
                        final deepLink = AppConfig.getWebUrl(
                          '/post/${post.id}',
                        );
                        Share.share('Check out this post on Oasis! $deepLink');
                      },
                      onDelete: () async {
                        try {
                          await provider.deletePost(post.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post deleted')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    );
                  }, childCount: provider.communityPosts.length),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(BuildContext context, String count, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
