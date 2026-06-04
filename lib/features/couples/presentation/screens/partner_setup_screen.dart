import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/couples/presentation/providers/partner_provider.dart';
import 'package:oasis/features/couples/data/partner_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PartnerSetupScreen extends StatefulWidget {
  const PartnerSetupScreen({super.key});

  @override
  State<PartnerSetupScreen> createState() => _PartnerSetupScreenState();
}

class _PartnerSetupScreenState extends State<PartnerSetupScreen> {
  final _searchController = TextEditingController();
  List<PartnerProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final repo = context.read<PartnerProvider>().currentPartner == null 
        ? PartnerRepository() // Need access to searchUsers
        : null;
        
    if (repo != null) {
      final results = await repo.searchUsers(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final partnerProvider = context.watch<PartnerProvider>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Link a Partner'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: partnerProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (partnerProvider.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          partnerProvider.error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.error),
                        onPressed: partnerProvider.clearError,
                      ),
                    ],
                  ),
                ),

              // Pending Invites
              if (partnerProvider.pendingInvites.isNotEmpty) ...[
                Text(
                  'Pending Invites',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...partnerProvider.pendingInvites.map((invite) {
                  final sender = invite.senderProfile;
                  if (sender == null) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: sender.avatarUrl != null 
                            ? CachedNetworkImageProvider(sender.avatarUrl!) 
                            : null,
                        child: sender.avatarUrl == null 
                            ? Text(sender.username[0].toUpperCase())
                            : null,
                      ),
                      title: Text(sender.displayName ?? sender.username),
                      subtitle: Text('@${sender.username} wants to link with you'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => partnerProvider.declineInvite(invite.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              final success = await partnerProvider.acceptInvite(invite.id, sender.id);
                              if (success) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Partner linked successfully!')),
                                );
                                context.pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // Search
              if (partnerProvider.currentPartner == null && partnerProvider.sentInviteReceiverId == null) ...[
                Text(
                  'Find your partner',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 16),
                if (_isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (_searchResults.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.avatarUrl != null 
                              ? CachedNetworkImageProvider(user.avatarUrl!) 
                              : null,
                          child: user.avatarUrl == null 
                              ? Text(user.username[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user.displayName ?? user.username),
                        subtitle: Text('@${user.username}'),
                        trailing: FilledButton(
                          onPressed: partnerProvider.isSending 
                            ? null 
                            : () async {
                                final success = await partnerProvider.sendInvite(user.id);
                                if (success) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invite sent!')),
                                  );
                                  context.pop();
                                }
                              },
                          child: const Text('Invite'),
                        ),
                      );
                    },
                  )
                else if (_searchController.text.isNotEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No users found'),
                    ),
                  ),
              ] else if (partnerProvider.sentInviteReceiverId != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.mark_email_read, size: 48, color: Colors.orange),
                      SizedBox(height: 16),
                      Text(
                        'Invite Sent',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Waiting for them to accept your invitation in their Home Location settings.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
      ),
    );
  }
}
