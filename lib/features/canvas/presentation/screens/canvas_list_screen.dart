import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/canvas_list_tile.dart';

class CanvasListScreen extends StatefulWidget {
  const CanvasListScreen({super.key});

  @override
  State<CanvasListScreen> createState() => _CanvasListScreenState();
}

class _CanvasListScreenState extends State<CanvasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<ProfileProvider>().currentProfile?.id;
    if (userId != null) {
      await context.read<CanvasProvider>().loadCanvases(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<CanvasProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 1000;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isM3E = themeProvider.isM3EEnabled;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 40 : 20,
                  isDesktop ? 40 : 20,
                  isDesktop ? 40 : 20,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Canvas',
                            style:
                                (isDesktop
                                        ? theme.textTheme.headlineLarge
                                        : theme.textTheme.headlineMedium)
                                    ?.copyWith(
                                      fontWeight: isM3E
                                          ? FontWeight.w900
                                          : FontWeight.w900,
                                      letterSpacing: isM3E ? -1.5 : -1,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Shared visual memory boards',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.pushNamed('create_canvas'),
                      icon: const Icon(
                        FluentIcons.add_circle_24_regular,
                        size: 18,
                      ),
                      label: Text(
                        isDesktop ? 'Create New Canvas' : 'New Canvas',
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isM3E ? 12 : 14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: isM3E ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            if (provider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.canvases.isEmpty)
              SliverFillRemaining(
                child: _EmptyCanvasState(
                  isM3E: isM3E,
                  onCreateTap: () => context.pushNamed('create_canvas'),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 4 : 2,
                    mainAxisSpacing: isDesktop ? 20 : 12,
                    crossAxisSpacing: isDesktop ? 20 : 12,
                    childAspectRatio: isDesktop ? 0.85 : 0.85,
                  ),
                  itemCount: provider.canvases.length,
                  itemBuilder: (context, i) {
                    final canvas = provider.canvases[i];
                    return _CanvasTileWrapper(
                      canvas: canvas,
                      isDesktop: isDesktop,
                      onTap: () => context.pushNamed(
                        'canvas_detail',
                        pathParameters: {'canvasId': canvas.id},
                      ),
                    );
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _EmptyCanvasState extends StatelessWidget {
  final VoidCallback onCreateTap;
  final bool isM3E;
  const _EmptyCanvasState({required this.onCreateTap, this.isM3E = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: isM3E ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isM3E ? BorderRadius.circular(24) : null,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Icon(
              FluentIcons.whiteboard_24_regular,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No canvases yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isM3E ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a canvas with close friends\nand start building shared memories.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(FluentIcons.add_circle_24_regular, size: 18),
            label: const Text('Create a Canvas'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isM3E ? 12 : 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasTileWrapper extends StatelessWidget {
  final OasisCanvas canvas;
  final VoidCallback onTap;
  final bool isDesktop;

  const _CanvasTileWrapper({
    required this.canvas,
    required this.onTap,
    this.isDesktop = false,
  });

  void _showContextMenu(BuildContext context, Offset position) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canvasProvider = context.read<CanvasProvider>();
    final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
    final isOwner = canvas.createdBy == currentUserId;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      elevation: 8,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(
                FluentIcons.open_24_regular,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              const Text('Open Canvas'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (isOwner)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  FluentIcons.delete_24_regular,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Canvas',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: 'leave',
            child: Row(
              children: [
                Icon(
                  FluentIcons.arrow_exit_20_regular,
                  size: 20,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Leave Canvas',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );

    if (result == 'open') {
      onTap();
    } else if (result == 'delete' && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Canvas?'),
          content: const Text(
            'This will permanently delete this canvas. This action cannot be undone.',
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

      if (confirmed == true && context.mounted) {
        await canvasProvider.deleteCanvas(canvas.id);
      }
    } else if (result == 'leave' && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave Canvas?'),
          content: const Text('Are you sure you want to leave this canvas?'),
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

      if (confirmed == true && context.mounted) {
        await canvasProvider.leaveCanvas(canvas.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Desktop: right-click for context menu
    if (isDesktop) {
      return GestureDetector(
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: CanvasListTile(canvas: canvas, onTap: onTap, isDesktop: true),
      );
    }
    // Mobile: long-press for context menu
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: CanvasListTile(canvas: canvas, onTap: onTap),
    );
  }
}
