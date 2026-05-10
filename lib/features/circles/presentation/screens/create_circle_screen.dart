import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/circles/presentation/providers/circle_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/profile/domain/models/user_profile_entity.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '🌊';
  bool _isLoading = false;
  final List<UserProfileEntity> _selectedMembers = [];

  static const _emojis = [
    '🌊', '🔥', '⚡', '🌿', '🎯', '💫', '🦋', '✨', 
    '🌙', '☀️', '🏔️', '🌺', '🎸', '📚', '🧠', '💪',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final profile = context.read<ProfileProvider>().currentProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for profile to load')),
      );
      return;
    }

    final userId = profile.id;

    setState(() => _isLoading = true);
    try {
      final memberIds = _selectedMembers.map((m) => m.id).toList();
      // Add author as member if not already there
      if (!memberIds.contains(userId)) {
        memberIds.add(userId);
      }

      final circle = await context.read<CircleProvider>().createCircle(
        createdBy: userId,
        name: name,
        emoji: _selectedEmoji,
        memberIds: memberIds,
      );
      
      if (!mounted) return;

      if (circle != null) {
        context.pushReplacementNamed(
          'circle_detail',
          pathParameters: {'circleId': circle.id},
        );
      } else {
        final error = context.read<CircleProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to create circle. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMember(UserProfileEntity profile) {
    setState(() {
      if (_selectedMembers.any((m) => m.id == profile.id)) {
        _selectedMembers.removeWhere((m) => m.id == profile.id);
      } else {
        _selectedMembers.add(profile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('New Circle'),
        leading: IconButton(
          icon: const Icon(FluentIcons.dismiss_24_regular),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick an emoji',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.2)
                          : colorScheme.surface,
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            Text(
              'Name your circle',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. The Morning Crew',
                prefixText: '$_selectedEmoji  ',
                prefixStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Choose Members',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            
            // Selected members horizontal list
            if (_selectedMembers.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMembers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final member = _selectedMembers[index];
                    return Stack(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: member.avatarUrl != null 
                                  ? CachedNetworkImageProvider(member.avatarUrl!) 
                                  : null,
                              child: member.avatarUrl == null ? Text(member.username[0].toUpperCase()) : null,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 50,
                              child: Text(
                                member.username,
                                style: theme.textTheme.labelSmall,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => _toggleMember(member),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            
            // Following list for selection
            Consumer<ProfileProvider>(
              builder: (context, profileProvider, child) {
                final following = profileProvider.following;
                if (following.isEmpty) {
                  return Text(
                    'Follow some people to invite them to your circle!',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  );
                }

                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: ListView.builder(
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      final profile = following[index];
                      final isSelected = _selectedMembers.any((m) => m.id == profile.id);

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleMember(profile),
                        title: Text(profile.username),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundImage: profile.avatarUrl != null 
                              ? CachedNetworkImageProvider(profile.avatarUrl!) 
                              : null,
                          child: profile.avatarUrl == null ? Text(profile.username[0].toUpperCase()) : null,
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _create,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(FluentIcons.checkmark_circle_24_regular),
                label: Text(_isLoading ? 'Creating...' : 'Create Circle'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
