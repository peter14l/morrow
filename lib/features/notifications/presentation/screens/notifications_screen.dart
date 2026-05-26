import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/notifications/domain/models/notification_entity.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_provider.dart';
import 'package:oasis/features/notifications/presentation/providers/notification_state.dart'
    as state;
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/widgets/adaptive/adaptive_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isPanel;
  const NotificationsScreen({super.key, this.isPanel = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  AppNotification? _selectedNotification;
  String _filterType = 'all';
  bool _showUnreadOnly = false;
  final bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await context.read<NotificationProvider>().markAsRead(notification.id);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await context.read<NotificationProvider>().markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<NotificationProvider>().deleteAllNotifications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    _markAsRead(notification);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    if (isDesktop && !widget.isPanel) {
      setState(() => _selectedNotification = notification);
    } else {
      if (notification.postId != null) {
        context.push('/post/${notification.postId}/comments');
      } else if (notification.actorId != null &&
          (notification.type == 'follow' ||
              notification.type == 'follow_request')) {
        context.push('/profile/${notification.actorId}');
      }
    }
  }

  List<AppNotification> get _filteredNotifications {
    final provider = context.read<NotificationProvider>();
    var filtered = provider.notifications;
    if (_showUnreadOnly) filtered = filtered.where((n) => !n.isRead).toList();
    if (_filterType != 'all') {
      filtered = filtered.where((n) => n.type == _filterType).toList();
    }
    filtered = filtered.where((n) => n.type != 'call').toList();
    return filtered;
  }

  Map<String, List<AppNotification>> get _groupedNotifications {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    final Map<String, List<AppNotification>> grouped = {
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };
    for (final notification in _filteredNotifications) {
      final notifDate = DateTime(
        notification.timestamp.year,
        notification.timestamp.month,
        notification.timestamp.day,
      );
      if (notifDate.isAtSameMomentAs(today)) {
        grouped['Today']!.add(notification);
      } else if (notifDate.isAtSameMomentAs(yesterday))
        grouped['Yesterday']!.add(notification);
      else if (notifDate.isAfter(thisWeek))
        grouped['This Week']!.add(notification);
      else
        grouped['Earlier']!.add(notification);
    }
    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'follow_request':
        return Icons.person_add_alt_1_rounded;
      case 'mention':
        return Icons.alternate_email;
      case 'ripple':
        return Icons.waves;
      case 'dm':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationText(AppNotification notification) {
    final actorName = notification.actorName ?? 'Someone';
    switch (notification.type) {
      case 'like':
        return '$actorName liked your post';
      case 'comment':
        return '$actorName commented on your post';
      case 'follow':
        return '$actorName started following you';
      case 'follow_request':
        return '$actorName sent you a follow request';
      case 'mention':
        return '$actorName mentioned you';
      case 'ripple':
        return '$actorName shared a ripple with you';
      case 'dm':
        return '$actorName sent you a message';
      default:
        return notification.message ?? 'New notification';
    }
  }

  Widget _buildNotificationItem(AppNotification notification, bool isDesktop) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;
    final isSelected =
        isDesktop && _selectedNotification?.id == notification.id;
    final bool isFollowRequest = notification.type == 'follow_request';

    return Card(
      margin: EdgeInsets.only(bottom: isM3E ? 8 : 12),
      color: notification.isRead
          ? (isM3E ? colorScheme.surfaceContainerLow : null)
          : (isM3E
                ? colorScheme.secondaryContainer
                : colorScheme.primaryContainer.withValues(alpha: 0.3)),
      elevation: isM3E ? 0 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isM3E ? 20 : 12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : (isM3E
                  ? BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : BorderSide.none),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: isM3E ? 22 : 24,
              backgroundImage: (notification.actorAvatar ?? '').isNotEmpty
                  ? CachedNetworkImageProvider(notification.actorAvatar!)
                  : null,
              child: (notification.actorAvatar ?? '').isEmpty
                  ? Icon(
                      _getNotificationIcon(notification.type),
                      size: isM3E ? 20 : 24,
                    )
                  : null,
            ),
            title: Text(
              _getNotificationText(notification),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: notification.isRead
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              timeago.format(notification.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: !notification.isRead && !isFollowRequest
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isM3E ? colorScheme.tertiary : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () => _handleNotificationTap(notification),
          ),
          if (isFollowRequest)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (notification.actorId != null) {
                          final currentUserId = AuthService().currentUser?.id;
                          if (currentUserId != null) {
                            await context
                                .read<ProfileProvider>()
                                .acceptFollowRequest(
                                  followerId: notification.actorId!,
                                  followingId: currentUserId,
                                );
                            await _markAsRead(notification);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow request accepted'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (notification.actorId != null) {
                          final currentUserId = AuthService().currentUser?.id;
                          if (currentUserId != null) {
                            await context
                                .read<ProfileProvider>()
                                .declineFollowRequest(
                                  followerId: notification.actorId!,
                                  followingId: currentUserId,
                                );
                            await _markAsRead(notification);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow request declined'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (widget.isPanel) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          automaticallyImplyLeading: false,
        ),
        body: _buildNotificationsList(),
      );
    }

    return AdaptiveScaffold(
      title: const Text('Notifications'),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        if (_showSidebar) SizedBox(width: 250, child: _buildFiltersSidebar()),
        Expanded(flex: 2, child: _buildNotificationsList()),
        Expanded(flex: 3, child: _buildDetailPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: () =>
          context.read<NotificationProvider>().loadNotifications(refresh: true),
      child: _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    final provider = context.watch<NotificationProvider>();
    if (provider.state.loadingState == state.NotificationLoadingState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredNotifications.isEmpty) return _buildEmptyState();
    final grouped = _groupedNotifications;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length * 2,
      itemBuilder: (context, index) {
        final groupKey = grouped.keys.elementAt(index ~/ 2);
        if (index.isEven) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              groupKey,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        return Column(
          children: grouped[groupKey]!
              .map(
                (n) => _buildNotificationItem(
                  n,
                  ResponsiveLayout.isDesktop(context) && !widget.isPanel,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildFiltersSidebar() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Filters',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Unread Only'),
          value: _showUnreadOnly,
          onChanged: (v) => setState(() => _showUnreadOnly = v),
        ),
        const Divider(),
        _buildFilterOption('All', 'all', Icons.notifications_outlined),
        _buildFilterOption('Likes', 'like', Icons.favorite_outline),
        _buildFilterOption('Comments', 'comment', Icons.comment_outlined),
        _buildFilterOption('Follows', 'follow', Icons.person_add_outlined),
      ],
    );
  }

  Widget _buildFilterOption(String label, String value, IconData icon) {
    final isSelected = _filterType == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      onTap: () => setState(() => _filterType = value),
      selected: isSelected,
    );
  }

  Widget _buildDetailPanel() {
    if (_selectedNotification == null) {
      return const Center(child: Text('Select a notification'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (_selectedNotification!.actorAvatar ?? '').isNotEmpty
                  ? CachedNetworkImageProvider(
                      _selectedNotification!.actorAvatar!,
                    )
                  : null,
            ),
            title: Text(
              _getNotificationText(_selectedNotification!),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeago.format(_selectedNotification!.timestamp)),
          ),
          if (_selectedNotification!.postId != null)
            ElevatedButton(
              onPressed: () => context.push(
                '/post/${_selectedNotification!.postId}/comments',
              ),
              child: const Text('View Post'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('No notifications yet'));
  }
}
