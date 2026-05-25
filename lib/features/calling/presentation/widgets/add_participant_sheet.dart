import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/call_service.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';

class AddParticipantSheet extends StatefulWidget {
  final List<String> existingParticipantIds;

  const AddParticipantSheet({
    super.key,
    required this.existingParticipantIds,
  });

  @override
  State<AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends State<AddParticipantSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final following = profileProvider.state.following;

    final availableUsers = following.where((user) {
      return !widget.existingParticipantIds.contains(user.id);
    }).toList();

    final filteredUsers = availableUsers.where((user) {
      final name = user.username.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add Participant',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search followers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(child: Text('No followers found'))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (user.avatarUrl ?? '').isNotEmpty
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: (user.avatarUrl ?? '').isEmpty
                              ? Text(user.username[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user.username),
                        subtitle: user.fullName != null ? Text(user.fullName!) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.person_add_alt_1),
                          onPressed: () => _inviteUser(context, user),
                        ),
                        onTap: () => _inviteUser(context, user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUser(BuildContext context, UserProfileEntity user) async {
    try {
      await CallService.instance.inviteToCall(user.id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invited ${user.username}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inviting: $e')),
      );
    }
  }
}
