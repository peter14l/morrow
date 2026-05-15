import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final int initialTab; // 0 for followers, 1 for following

  const FollowersScreen({super.key, required this.userId, this.initialTab = 0});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final profileProvider = context.read<ProfileProvider>();
      await Future.wait([
        profileProvider.loadFollowers(widget.userId),
        profileProvider.loadFollowing(widget.userId),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(profileProvider.followers),
              _buildUserList(profileProvider.following),
            ],
          );
        },
      ),
    );

    return ResponsiveLayout.isDesktop(context)
        ? MaxWidthContainer(
            maxWidth: ResponsiveLayout.maxContentWidth,
            child: content,
          )
        : content;
  }

  Widget _buildUserList(List<UserProfileEntity> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildUserItem(UserProfileEntity user) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
              ? CachedNetworkImageProvider(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null || user.avatarUrl!.isEmpty
              ? Text(user.username[0].toUpperCase())
              : null,
        ),
        title: Row(
          children: [
            Text(
              user.username,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 4),
              Icon(Icons.verified, size: 16, color: theme.colorScheme.primary),
            ],
          ],
        ),
        subtitle: user.fullName != null && user.fullName!.isNotEmpty
            ? Text(user.fullName!)
            : null,
        trailing: user.id != widget.userId
            ? OutlinedButton(
                onPressed: () => context.push('/profile/${user.id}'),
                child: const Text('View'),
              )
            : null,
        onTap: () => context.push('/profile/${user.id}'),
      ),
    );
  }
}
