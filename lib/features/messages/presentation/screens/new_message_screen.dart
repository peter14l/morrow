import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import 'package:oasis/features/messages/data/messaging_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final ProfileRepositoryImpl _profileRepository = ProfileRepositoryImpl();
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<UserProfileEntity> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    try {
      final results = await _profileRepository.searchUsers(query: query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _startConversation(UserProfileEntity user) async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final conversationId = await _messagingService.getOrCreateConversation(
        user1Id: currentUserId,
        user2Id: user.id,
      );

      if (mounted) {
        final isDesktop = MediaQuery.of(context).size.width >= 1000;
        if (isDesktop) {
          // On desktop, we want to go back to DM screen and select the new conversation
          context.go(
            '/messages',
            extra: {
              'initialConversationId': conversationId,
              'otherUserId': user.id,
              'otherUserName': user.username,
              'otherUserAvatar': user.avatarUrl ?? '',
            },
          );
        } else {
          context.go(
            '/messages/$conversationId',
            extra: {
              'otherUserName': user.username,
              'otherUserAvatar': user.avatarUrl ?? '',
              'otherUserId': user.id,
            },
          );
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
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'New Message',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 600 : double.infinity,
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search users by username...',
                    prefixIcon: const Icon(
                      FluentIcons.search_24_regular,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              FluentIcons.dismiss_24_regular,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              const Divider(height: 1),

              // Search Results
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FluentIcons.person_search_24_regular,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Search for users to message'
                                  : 'No users found',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            child: InkWell(
                              onTap: () => _startConversation(user),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          colorScheme.primaryContainer,
                                      backgroundImage:
                                          user.avatarUrl != null &&
                                              user.avatarUrl!.isNotEmpty
                                          ? CachedNetworkImageProvider(
                                              user.avatarUrl!,
                                            )
                                          : null,
                                      child:
                                          user.avatarUrl == null ||
                                              user.avatarUrl!.isEmpty
                                          ? Text(
                                              user.username[0].toUpperCase(),
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                user.username,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                              ),
                                              if (user.isVerified) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  FluentIcons
                                                      .checkmark_starburst_16_filled,
                                                  size: 14,
                                                  color: colorScheme.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (user.fullName != null &&
                                              user.fullName!.isNotEmpty)
                                            Text(
                                              user.fullName!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      FluentIcons.chevron_right_24_regular,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
