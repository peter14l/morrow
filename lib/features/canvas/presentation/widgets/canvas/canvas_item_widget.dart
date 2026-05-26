import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/journal_entry_widget.dart';
import 'package:oasis/painters/canvas_drawing_painter.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Draggable and long-press-deletable item on the canvas.
class CanvasItemWidget extends StatefulWidget {
  final CanvasItemEntity item;
  final void Function(double x, double y, double rotation) onMoved;
  final VoidCallback onDelete;
  final void Function(String emoji)? onReact;
  final void Function(bool lock)? onLock;

  const CanvasItemWidget({
    super.key,
    required this.item,
    required this.onMoved,
    required this.onDelete,
    this.onReact,
    this.onLock,
  });

  @override
  State<CanvasItemWidget> createState() => _CanvasItemWidgetState();
}

class _CanvasItemWidgetState extends State<CanvasItemWidget> {
  late double _x;
  late double _y;
  late double _rotation;
  bool _selected = false;
  bool _isDraggingLocally = false;

  // We use 3000 as the scale factor for normalized coordinates
  static const double _canvasScale = 3000.0;

  @override
  void initState() {
    super.initState();
    _x = widget.item.xPos * _canvasScale;
    _y = widget.item.yPos * _canvasScale;
    _rotation = widget.item.rotation;
  }

  @override
  void didUpdateWidget(CanvasItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDraggingLocally) {
      _x = widget.item.xPos * _canvasScale;
      _y = widget.item.yPos * _canvasScale;
      _rotation = widget.item.rotation;
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.item.isLocked) return;
    setState(() => _isDraggingLocally = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (widget.item.isLocked) return;
    setState(() {
      _x += details.delta.dx;
      _y += details.delta.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (widget.item.isLocked) return;
    setState(() => _isDraggingLocally = false);
    widget.onMoved(_x / _canvasScale, _y / _canvasScale, _rotation);
  }

  void _onLongPress() {
    setState(() => _selected = true);
    _showItemOptions();
  }

  void _showItemOptions() {
    final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
    final isAuthor = widget.item.authorId == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '😂', '🔥', '✨', '😢']
                  .map(
                    (emoji) => IconButton(
                      onPressed: () {
                        widget.onReact?.call(emoji);
                        Navigator.pop(context);
                      },
                      icon: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  )
                  .toList(),
            ),
            const Divider(height: 32),
            if (isAuthor)
              ListTile(
                leading: Icon(
                  widget.item.isLocked
                      ? FluentIcons.lock_open_24_regular
                      : FluentIcons.lock_closed_24_regular,
                ),
                title: Text(widget.item.isLocked ? 'Unlock Item' : 'Lock Item'),
                onTap: () {
                  widget.onLock?.call(!widget.item.isLocked);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(
                FluentIcons.delete_24_regular,
                color: Colors.red,
              ),
              title: const Text(
                'Remove from Canvas',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<ProfileProvider>().currentProfile?.id;
    final isBeingModifiedByOther =
        widget.item.lastModifiedBy != null &&
        widget.item.lastModifiedBy != currentUserId;

    return Transform.rotate(
      angle: _rotation * 3.14159 / 180,
      child: Transform.scale(
        scale: widget.item.scale,
        child: GestureDetector(
          behavior: HitTestBehavior
              .opaque, // Ensure it catches taps anywhere in its bounds
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onLongPress: _onLongPress,
          onTap: () => setState(() => _selected = !_selected),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Interaction Halo & Border
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(
                  8,
                ), // Increased padding for easier grabbing
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isBeingModifiedByOther
                        ? Colors.blue.withValues(alpha: 0.6)
                        : (_selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent),
                    width: 2.5,
                  ),
                  boxShadow: isBeingModifiedByOther
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ]
                      : (_selected
                            ? [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ]
                            : []),
                ),
                child: _buildContent(),
              ),

              // Selection / Modification Overlays
              if (isBeingModifiedByOther)
                Positioned(
                  top: -20,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Friend is moving this...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Lock Indicator
              if (widget.item.isLocked)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      FluentIcons.lock_closed_16_filled,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),

              // Reactions
              if (widget.item.reactions.isNotEmpty)
                Positioned(
                  bottom: -16,
                  left: 0,
                  right: 0,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: widget.item.reactions.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.value.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final theme = Theme.of(context);
    switch (widget.item.type) {
      case CanvasItemType.text:
        final bgHex = widget.item.color.replaceAll('#', '');
        final bgColor = Color(int.parse('FF$bgHex', radix: 16));
        return Container(
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            widget.item.content,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
          ),
        );

      case CanvasItemType.sticker:
        return Text(widget.item.content, style: const TextStyle(fontSize: 48));

      case CanvasItemType.photo:
        return Container(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: widget.item.content,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                width: 150,
                height: 150,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 150,
                height: 150,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );

      case CanvasItemType.voice:
        return Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(FluentIcons.play_24_filled, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          ),
        );

      case CanvasItemType.milestone:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                FluentIcons.star_16_filled,
                size: 14,
                color: Colors.black,
              ),
              const SizedBox(width: 6),
              Text(
                widget.item.content,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );

      case CanvasItemType.journal:
        return JournalEntryWidget(
          content: widget.item.content,
          createdAt: widget.item.createdAt,
        );

      case CanvasItemType.doodle:
        return _buildDoodleContent();

      case CanvasItemType.shape:
        return _buildShapeContent();
    }
  }

  Widget _buildDoodleContent() {
    try {
      final String content = Uri.decodeComponent(widget.item.content);
      if (content.isEmpty) return const SizedBox.shrink();

      final List<String> segments = content.split(';');
      final List<DrawingPoint?> points = [];

      final color = Color(
        int.parse('FF${widget.item.color.replaceAll('#', '')}', radix: 16),
      );

      for (var segment in segments) {
        if (segment.isEmpty) continue;
        final coords = segment.split(',');
        if (coords.length < 2) continue;

        points.add(
          DrawingPoint(
            point: Offset(double.parse(coords[0]), double.parse(coords[1])),
            paint: Paint()
              ..color = color
              ..strokeWidth = 4.0
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..isAntiAlias = true,
          ),
        );
      }

      // Add a null at the end to ensure the last path segment is drawn if needed by painter
      points.add(null);

      final double w = (widget.item.metadata['w'] as num?)?.toDouble() ?? 200.0;
      final double h = (widget.item.metadata['h'] as num?)?.toDouble() ?? 200.0;

      return SizedBox(
        width: w,
        height: h,
        // Add a background color during debugging if needed
        // color: Colors.white10,
        child: CustomPaint(
          painter: CanvasDrawingPainter(pointsList: points),
          size: Size(w, h),
        ),
      );
    } catch (e) {
      debugPrint('Error building doodle: $e');
      return const Icon(Icons.gesture, color: Colors.white, size: 32);
    }
  }

  Widget _buildShapeContent() {
    final color = Color(
      int.parse('FF${widget.item.color.replaceAll('#', '')}', radix: 16),
    );
    final w = (widget.item.metadata['w'] as num?)?.toDouble() ?? 100.0;
    final h = (widget.item.metadata['h'] as num?)?.toDouble() ?? 100.0;

    switch (widget.item.content) {
      case 'circle':
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            color: color.withValues(alpha: 0.1),
          ),
        );
      case 'rectangle':
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            color: color.withValues(alpha: 0.1),
          ),
        );
      case 'triangle':
        return CustomPaint(
          size: Size(w, h),
          painter: _TrianglePainter(color: color),
        );
      case 'line':
        return CustomPaint(
          size: Size(w, h),
          painter: _LinePainter(color: color),
        );
      default:
        return const Icon(Icons.help_outline, color: Colors.white);
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _LinePainter extends CustomPainter {
  final Color color;
  _LinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
