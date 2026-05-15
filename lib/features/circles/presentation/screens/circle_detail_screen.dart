import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/features/feed/presentation/screens/comments_screen.dart';
import 'package:oasis/widgets/messages/share_to_dm_modal.dart';
import 'package:oasis/features/messages/domain/models/message.dart';
import 'package:oasis/features/feed/presentation/screens/create_post_screen.dart';

class CircleDetailScreen extends StatefulWidget {
  final String circleId;

  const CircleDetailScreen({super.key, required this.circleId});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId != null && mounted) {
        final provider = context.read<CircleProvider>();
        debugPrint(
          '[CircleDetailScreen] Initializing circle ${widget.circleId} for user $currentUserId',
        );
        await provider.setActiveCircle(widget.circleId, currentUserId);
        if (mounted) {
          await provider.loadCircleFeed(
            widget.circleId,
            currentUserId,
            refresh: true,
          );
          debugPrint(
            '[CircleDetailScreen] Feed loaded: ${provider.circleFeed.length} posts',
          );
        }
      }
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId != null) {
        context.read<CircleProvider>().loadCircleFeed(
          widget.circleId,
          currentUserId,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCreatePost() async {
    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId == null) return;

    debugPrint(
      '[CircleDetailScreen] Opening CreatePostScreen for circle ${widget.circleId}',
    );
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(circleId: widget.circleId),
      ),
    );

    debugPrint(
      '[CircleDetailScreen] Returned from CreatePostScreen. Local feed count: ${context.read<CircleProvider>().circleFeed.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Consumer<CircleProvider>(
          builder: (context, provider, child) {
            return Text(provider.activeCircle?.name ?? 'Circle');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.settings_24_regular),
            onPressed: () {
              // TODO: Circle Settings
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(scrollController: _scrollController),
          const _MembersTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleCreatePost,
        icon: const Icon(FluentIcons.add_24_regular),
        label: const Text('New Post'),
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  final ScrollController scrollController;

  const _FeedTab({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<CircleProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingFeed && provider.circleFeed.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.circleFeed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.feed_24_regular,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to post in this circle!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final currentUserId = AuthService().currentUser?.id;
            if (currentUserId != null && provider.activeCircle != null) {
              await provider.loadCircleFeed(
                provider.activeCircle!.id,
                currentUserId,
                refresh: true,
              );
            }
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount:
                provider.circleFeed.length + (provider.hasMoreFeed ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.circleFeed.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final post = provider.circleFeed[index];
              return PostCard(
                post: post,
                showInteractionButtons: true,
                isOwnPost: post.userId == AuthService().currentUser?.id,
                onLike: () {
                  final currentUserId = AuthService().currentUser?.id;
                  if (currentUserId != null) {
                    provider.toggleLike(post.id, currentUserId);
                  }
                },
                onComment: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CommentsScreen(postId: post.id),
                  );
                },
                onShare: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ShareToDirectMessageModal(
                      title: 'Share Post',
                      content: post.content,
                      messageType: MessageType.postShare,
                      postId: post.id,
                      mediaUrl: post.mediaUrls.isNotEmpty
                          ? post.mediaUrls.first
                          : null,
                      shareData: post.toJson(),
                    ),
                  );
                },
                onDelete: () async {
                  final currentUserId = AuthService().currentUser?.id;
                  if (currentUserId != null) {
                    try {
                      await provider.deletePost(post.id, currentUserId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Post deleted')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting post: $e')),
                        );
                      }
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CircleProvider>(
      builder: (context, provider, child) {
        final circle = provider.activeCircle;
        if (circle == null) return const SizedBox.shrink();

        // If members list is empty but we have member IDs, we might still be loading profiles
        // or the data wasn't joined.
        final hasProfiles = circle.members.isNotEmpty;
        final count = hasProfiles
            ? circle.members.length
            : circle.memberIds.length;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: count,
          itemBuilder: (context, index) {
            if (hasProfiles) {
              final member = circle.members[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                      ? const Icon(FluentIcons.person_24_regular)
                      : null,
                ),
                title: Text(member.displayName),
                subtitle: Text(
                  member.id == circle.createdBy ? 'Author' : 'Member',
                ),
              );
            }

            final memberId = circle.memberIds[index];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(FluentIcons.person_24_regular),
              ),
              title: Text('User $memberId'),
              subtitle: Text(
                memberId == circle.createdBy ? 'Author' : 'Member',
              ),
            );
          },
        );
      },
    );
  }
}
