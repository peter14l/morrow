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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId != null) {
        context.read<CircleProvider>().setActiveCircle(widget.circleId, currentUserId);
        context.read<CircleProvider>().loadCircleFeed(widget.circleId, currentUserId, refresh: true);
      }
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId != null) {
        context.read<CircleProvider>().loadCircleFeed(widget.circleId, currentUserId);
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

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          circleId: widget.circleId,
        ),
      ),
    );

    if (result == true) {
      if (mounted) {
        context.read<CircleProvider>().loadCircleFeed(widget.circleId, currentUserId, refresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

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
            if (currentUserId != null) {
              await provider.loadCircleFeed(provider.activeCircle!.id, currentUserId, refresh: true);
            }
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: provider.circleFeed.length + (provider.hasMoreFeed ? 1 : 0),
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
                    builder: (context) => CommentsScreen(post: post),
                  );
                },
                onShare: () {
                  ShareToDMModal.show(context, post: post);
                },
                onDelete: () {
                   // Implement delete if needed
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: circle.memberIds.length,
          itemBuilder: (context, index) {
            final memberId = circle.memberIds[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(FluentIcons.person_24_regular)),
              title: Text('User $memberId'),
              subtitle: Text(memberId == circle.createdBy ? 'Author' : 'Member'),
            );
          },
        );
      },
    );
  }
}
