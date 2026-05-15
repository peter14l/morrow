import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/core/network/supabase_client.dart';

class GroupMemberSelectionScreen extends StatefulWidget {
  final bool isAddingMembers;
  final List<String> existingParticipantIds;

  const GroupMemberSelectionScreen({
    super.key,
    this.isAddingMembers = false,
    this.existingParticipantIds = const [],
  });

  @override
  State<GroupMemberSelectionScreen> createState() =>
      _GroupMemberSelectionScreenState();
}

class _GroupMemberSelectionScreenState
    extends State<GroupMemberSelectionScreen> {
  final Set<String> _selectedUserIds = {};
  String _searchQuery = '';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = AuthService().currentUser?.id;
      if (currentUserId != null) {
        context.read<ProfileProvider>().loadFollowing(currentUserId);
      }
    });
  }

  Future<void> _handleNext() async {
    if (_selectedUserIds.isEmpty) return;

    if (widget.isAddingMembers) {
      Navigator.pop(context, _selectedUserIds.toList());
      return;
    }

    final groupName = await _showGroupNameDialog();
    if (groupName == null || groupName.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final messagingService = context.read<MessagingService>();
      final conversationId = await messagingService.createGroupConversation(
        name: groupName,
        participantIds: _selectedUserIds.toList(),
      );

      if (mounted) {
        context.pushReplacement(
          '/messages/$conversationId',
          extra: {'otherUserName': groupName, 'type': 'group'},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating group: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<String?> _showGroupNameDialog() async {
    final controller = TextEditingController(text: 'New Group');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter group name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileProvider = context.watch<ProfileProvider>();
    final following = profileProvider.state.following;

    // Filter out existing participants
    final availableUsers = following.where((user) {
      return !widget.existingParticipantIds.contains(user.id);
    }).toList();

    final filteredUsers = availableUsers.where((user) {
      final name = user.username.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAddingMembers ? 'Add Members' : 'New Group'),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _selectedUserIds.isNotEmpty ? _handleNext : null,
              child: Text(
                widget.isAddingMembers ? 'Add' : 'Next',
                style: TextStyle(
                  color: _selectedUserIds.isNotEmpty
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search followers...',
                prefixIcon: const Icon(FluentIcons.search_24_regular),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          if (_selectedUserIds.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedUserIds.map((id) {
                  final user = following.firstWhere((u) => u.id == id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: (user.avatarUrl ?? '').isNotEmpty
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                              child: (user.avatarUrl ?? '').isEmpty
                                  ? Text(user.username[0].toUpperCase())
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              top: -4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedUserIds.remove(id)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 50,
                          child: Text(
                            user.username,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text('No followers found'))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _selectedUserIds.contains(user.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(user.id);
                            } else {
                              _selectedUserIds.remove(user.id);
                            }
                          });
                        },
                        title: Text(user.username),
                        subtitle: Text(user.bio ?? ''),
                        secondary: CircleAvatar(
                          backgroundImage: (user.avatarUrl ?? '').isNotEmpty
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: (user.avatarUrl ?? '').isEmpty
                              ? Text(user.username[0].toUpperCase())
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
