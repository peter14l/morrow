import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/settings/presentation/screens/subscription_screen.dart';

class CreateCanvasScreen extends StatefulWidget {
  const CreateCanvasScreen({super.key});

  @override
  State<CreateCanvasScreen> createState() => _CreateCanvasScreenState();
}

class _CreateCanvasScreenState extends State<CreateCanvasScreen> {
  final _titleController = TextEditingController();
  String _selectedColor = '#3B82F6';
  bool _isLoading = false;
  bool _isCollaborative = false;
  final List<String> _selectedMemberIds = [];

  // Pastel-ish colors for canvas covers
  static const _coverColors = [
    '#3B82F6', // Blue (brand)
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#10B981', // Teal
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#06B6D4', // Cyan
    '#84CC16', // Lime
  ];

  @override
  void initState() {
    super.initState();
    // Load following list to allow invitations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileProvider>().currentProfile;
      if (profile != null) {
        context.read<ProfileProvider>().loadFollowing(profile.id);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final profile = context.read<ProfileProvider>().currentProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for profile to load')),
      );
      return;
    }

    final userId = profile.id;
    final canvasProvider = context.read<CanvasProvider>();

    setState(() => _isLoading = true);
    try {
      final canvas = await canvasProvider.createCanvas(
        createdBy: userId,
        title: title,
        coverColor: _selectedColor,
        memberIds: _isCollaborative ? _selectedMemberIds : [],
        isPro: profile.isPro,
      );

      if (!mounted) return;

      if (canvas != null) {
        context.pushReplacementNamed(
          'canvas_detail',
          pathParameters: {'canvasId': canvas.id},
        );
      } else if (canvasProvider.error == 'FREE_LIMIT_REACHED') {
        canvasProvider.clearError();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(canvasProvider.error ?? 'Failed to create canvas'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('New Canvas'),
        leading: IconButton(
          icon: const Icon(FluentIcons.dismiss_24_regular),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Preview ──────────────────────────────────────────────
            _CanvasPreview(
              title: _titleController.text.isEmpty
                  ? 'My Canvas'
                  : _titleController.text,
              color: _selectedColor,
              memberCount: 1,
            ),

            const SizedBox(height: 28),

            // ── Title ────────────────────────────────────────────────
            Text(
              'Canvas name',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Summer Memories',
              ),
            ),

            const SizedBox(height: 24),

            // ── Color picker ─────────────────────────────────────────
            Text(
              'Cover colour',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _coverColors.map((hex) {
                final isSelected = hex == _selectedColor;
                final color = _hexToColor(hex);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Mode selection ───────────────────────────────────────
            Text(
              'Canvas type',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: 'Solo',
                    icon: FluentIcons.person_24_regular,
                    isSelected: !_isCollaborative,
                    onTap: () => setState(() => _isCollaborative = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: 'Collaborative',
                    icon: FluentIcons.people_24_regular,
                    isSelected: _isCollaborative,
                    onTap: () => setState(() => _isCollaborative = true),
                  ),
                ),
              ],
            ),

            if (_isCollaborative) ...[
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invite friends',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${_selectedMemberIds.length} selected',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (profileProvider.isLoadingFollowing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (profileProvider.following.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('No friends found to invite'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: profileProvider.following.length,
                  itemBuilder: (context, index) {
                    final friend = profileProvider.following[index];
                    final isSelected = _selectedMemberIds.contains(friend.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(friend.fullName ?? friend.username),
                      subtitle: Text('@${friend.username}'),
                      secondary: CircleAvatar(
                        backgroundImage:
                            friend.avatarUrl != null &&
                                friend.avatarUrl!.isNotEmpty
                            ? NetworkImage(friend.avatarUrl!)
                            : null,
                        child:
                            friend.avatarUrl == null ||
                                friend.avatarUrl!.isEmpty
                            ? Text(friend.username[0].toUpperCase())
                            : null,
                      ),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedMemberIds.add(friend.id);
                          } else {
                            _selectedMemberIds.remove(friend.id);
                          }
                        });
                      },
                    );
                  },
                ),
            ],

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _create,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(FluentIcons.whiteboard_24_regular),
                label: Text(_isLoading ? 'Creating...' : 'Create Canvas'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final code = hex.replaceAll('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasPreview extends StatelessWidget {
  final String title;
  final String color;
  final int memberCount;

  const _CanvasPreview({
    required this.title,
    required this.color,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _hexToColor(color);

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.withValues(alpha: 0.7), c.withValues(alpha: 0.3)],
        ),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FluentIcons.whiteboard_24_regular,
              color: Colors.white.withValues(alpha: 0.6),
              size: 28,
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$memberCount ${memberCount == 1 ? 'member' : 'members'} · Just created',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final code = hex.replaceAll('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
