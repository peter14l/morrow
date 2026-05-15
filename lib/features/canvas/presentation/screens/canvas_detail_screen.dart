import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/canvas_item_widget.dart';
import 'package:oasis/services/canvas_service.dart';
import 'package:oasis/widgets/share_sheet.dart';
import 'package:oasis/services/canvas_audio_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CanvasDetailScreen extends StatefulWidget {
  final String canvasId;
  const CanvasDetailScreen({super.key, required this.canvasId});

  @override
  State<CanvasDetailScreen> createState() => _CanvasDetailScreenState();
}

class _CanvasDetailScreenState extends State<CanvasDetailScreen> {
  late CanvasProvider _canvasProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canvasProvider = context.read<CanvasProvider>();
  }

  @override
  void initState() {
    super.initState();
    CanvasAudioService().start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
      if (currentUserId != null) {
        // Automatically join if not a member (handles invites)
        await context.read<CanvasProvider>().joinCanvas(
          widget.canvasId,
          currentUserId,
        );
      }
      _canvasProvider.openCanvas(widget.canvasId);
    });
  }

  @override
  void dispose() {
    CanvasAudioService().stop();
    _canvasProvider.closeCanvas();
    super.dispose();
  }

  void _deleteCanvas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Canvas?'),
        content: const Text(
          'This will permanently delete this canvas and all its memories. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<CanvasProvider>().deleteCanvas(
        widget.canvasId,
      );
      if (success && mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Canvas deleted')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete canvas')),
        );
      }
    }
  }

  void _leaveCanvas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Canvas?'),
        content: const Text(
          'You will no longer be able to see or contribute to this canvas unless invited back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<CanvasProvider>().leaveCanvas(
        widget.canvasId,
      );
      if (success && mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You left the canvas')));
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to leave canvas')));
      }
    }
  }

  String _getAuthorId() {
    final profileId = context.read<ProfileProvider>().currentProfile?.id;
    if (profileId != null && profileId.isNotEmpty) return profileId;
    return Supabase.instance.client.auth.currentUser?.id ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CanvasProvider>();
    final canvas = provider.activeCanvas;
    final currentUserId = _getAuthorId();
    final isOwner = canvas?.createdBy == currentUserId;
    final canvasColor = canvas?.coverColor != null
        ? Color(int.parse(canvas!.coverColor.replaceAll('#', '0xFF')))
        : const Color(0xFF0C0F14);

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: AppBar(
        title: Text(canvas?.title ?? 'Canvas'),
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        leading: IconButton(
          icon: const Icon(FluentIcons.chevron_left_24_regular),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.people_add_24_regular),
            onPressed: () {
              if (canvas != null) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ShareSheet(
                    title: 'Share Canvas',
                    payload: '[INVITE:canvas:${canvas.id}:${canvas.title}]',
                  ),
                );
              }
            },
            tooltip: 'Invite',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteCanvas();
              } else if (value == 'leave') {
                _leaveCanvas();
              }
            },
            itemBuilder: (context) => [
              if (isOwner)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.delete_24_regular,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Delete Canvas',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.arrow_exit_20_regular,
                        color: Colors.red,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Leave Canvas', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      // ── Add Item FAB tray ──────────────────────────────────────────
      floatingActionButton: _AddItemTray(
        onAddText: () => _addTextNote(context),
        onAddPhoto: () => _addPhoto(context),
        onAddVoice: () {}, // future: voice recorder
        onAddSticker: () => _addSticker(context),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ── Interactive canvas surface ─────────────────────
                GestureDetector(
                  onTapDown: (details) {
                    // Tap on empty space to deselect
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),
                // ── Canvas items ───────────────────────────────────
                ...provider.activeItems.map((item) {
                  return Positioned(
                    left: item.xPos,
                    top: item.yPos,
                    child: CanvasItemWidget(
                      item: item,
                      onMoved: (dx, dy, rotation) {
                        context.read<CanvasProvider>().moveItem(
                          itemId: item.id,
                          xPos: dx,
                          yPos: dy,
                          rotation: rotation,
                          lastModifiedBy: currentUserId,
                        );
                      },
                      onDelete: () {
                        context.read<CanvasProvider>().deleteItem(item.id);
                      },
                    ),
                  );
                }),
                // ── Empty state hint ───────────────────────────────
                if (provider.activeItems.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.emoji_add_24_regular,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your canvas is empty',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add stickers, notes, or photos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _addTextNote(BuildContext context) {
    final controller = TextEditingController();
    final authorId = _getAuthorId();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add a note',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Write something...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      context.read<CanvasProvider>().addItem(
                        authorId: authorId,
                        type: CanvasItemType.text,
                        content: controller.text.trim(),
                        xPos: 50,
                        yPos: 120,
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Add to Canvas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null && context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final provider = context.read<CanvasProvider>();
        final authorId = _getAuthorId();

        messenger.showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );

        final canvasService = CanvasService();

        final imageUrl = await canvasService.uploadCanvasImage(
          widget.canvasId,
          pickedFile.path,
        );

        if (mounted) {
          provider.addItem(
            authorId: authorId,
            type: CanvasItemType.photo,
            content: imageUrl,
            xPos: 100,
            yPos: 150,
          );

          messenger.showSnackBar(const SnackBar(content: Text('Photo added!')));
        }
      }
    } catch (e) {
      debugPrint('Error adding photo: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add photo')));
      }
    }
  }

  void _addSticker(BuildContext context) {
    final stickers = [
      '⭐',
      '🌊',
      '🔥',
      '✨',
      '💙',
      '🎵',
      '🌙',
      '☀️',
      '🌿',
      '🎯',
      '💫',
      '🦋',
      '🎸',
      '📚',
    ];
    final authorId = _getAuthorId();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pick a sticker',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stickers.map((s) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.read<CanvasProvider>().addItem(
                      authorId: authorId,
                      type: CanvasItemType.sticker,
                      content: s,
                      xPos: 80,
                      yPos: 100,
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Add Item Tray ────────────────────────────────────────────────────────────

class _AddItemTray extends StatefulWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVoice;
  final VoidCallback onAddSticker;

  const _AddItemTray({
    required this.onAddText,
    required this.onAddPhoto,
    required this.onAddVoice,
    required this.onAddSticker,
  });

  @override
  State<_AddItemTray> createState() => _AddItemTrayState();
}

class _AddItemTrayState extends State<_AddItemTray>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          _TrayButton(
            icon: FluentIcons.text_description_24_regular,
            label: 'Note',
            onTap: () {
              _toggle();
              widget.onAddText();
            },
          ),
          const SizedBox(height: 8),
          _TrayButton(
            icon: FluentIcons.image_24_regular,
            label: 'Photo',
            onTap: () {
              _toggle();
              widget.onAddPhoto();
            },
          ),
          const SizedBox(height: 8),
          _TrayButton(
            icon: FluentIcons.emoji_24_regular,
            label: 'Sticker',
            onTap: () {
              _toggle();
              widget.onAddSticker();
            },
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: theme.colorScheme.primary,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _expanded
                  ? FluentIcons.dismiss_24_regular
                  : FluentIcons.add_24_regular,
              key: ValueKey(_expanded),
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TrayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black.withValues(alpha: 0.6),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Icon(icon, size: 20),
          ),
        ],
      ),
    );
  }
}
