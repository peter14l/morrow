import 'package:oasis/core/extensions/context_extensions.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/features/canvas/presentation/providers/canvas_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/starry_night_background.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/timeline_scrubber.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/pulse_ripple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oasis/services/canvas_service.dart';
import 'package:oasis/widgets/share_sheet.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/scattered_polaroid_spread.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/canvas_item_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oasis/features/canvas/domain/utils/shape_recognizer.dart';
import 'package:oasis/painters/canvas_drawing_painter.dart';
import 'package:oasis/features/canvas/presentation/widgets/canvas/infinite_canvas.dart';

class _PulseData {
  final String id;
  final Offset position;
  _PulseData({required this.id, required this.position});
}

class TimelineCanvasScreen extends StatefulWidget {
  final String canvasId;
  const TimelineCanvasScreen({super.key, required this.canvasId});

  @override
  State<TimelineCanvasScreen> createState() => _TimelineCanvasScreenState();
}

class _TimelineCanvasScreenState extends State<TimelineCanvasScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  final List<_PulseData> _pulses = [];
  RealtimeChannel? _pulseChannel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isMapMode = true;
  bool _isDrawingMode = false;
  List<DrawingPoint?> _currentPoints = [];
  Timer? _morphTimer;
  Offset? _lastPointerPosition;
  Color _selectedDrawingColor = Colors.white;
  double _drawingStrokeWidth = 4.0;

  // Spatial Canvas Constants
  static const double _canvasScale = 3000.0;

  Offset _canvasOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });

    // Listen for errors from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CanvasProvider>().addListener(_handleProviderError);
    });
  }

  @override
  void dispose() {
    // Provider might be disposed already in some cases, so we use a safe check
    try {
      context.read<CanvasProvider>().removeListener(_handleProviderError);
    } catch (_) {}

    _scrollController.dispose();
    _audioRecorder.dispose();
    _morphTimer?.cancel();
    super.dispose();
  }

  void _handleProviderError() {
    if (!mounted) return;
    final error = context.read<CanvasProvider>().error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Canvas Error: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
      context.read<CanvasProvider>().clearError();
    }
  }

  String _getAuthorId() {
    final profileId = context.read<ProfileProvider>().currentProfile?.id;
    if (profileId != null && profileId.isNotEmpty) return profileId;

    // Fallback to Supabase auth directly if profile provider isn't ready
    final authId = Supabase.instance.client.auth.currentUser?.id;
    return authId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CanvasProvider>();
    final canvas = provider.activeCanvas;
    final currentUserId = _getAuthorId();
    final isOwner = canvas?.createdBy == currentUserId;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: !_isDrawingMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isDrawingMode) {
          setState(() => _isDrawingMode = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: Stack(
          children: [
            // Background - Starry Night with Parallax support
            StarryNightBackground(
              offset: _isMapMode ? _canvasOffset : Offset(0, _scrollOffset),
            ),

            if (_isMapMode) ...[
              InfiniteCanvas(
                items: provider.activeItems,
                isDrawingMode: _isDrawingMode,
                onLongPress: (pos) => _sendPulse(pos),
                onTransformationChanged: (offset) {
                  setState(() => _canvasOffset = offset);
                },
                onItemMoved: (itemId, x, y) {
                  context.read<CanvasProvider>().moveItem(
                    itemId: itemId,
                    xPos: x,
                    yPos: y,
                    lastModifiedBy: currentUserId,
                  );
                },
                drawingLayer: _isDrawingMode ? _buildDrawingLayer() : null,
              ),

              // Floating Controls Overlay (Map Mode only)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: _buildHeaderOverlay(canvas, isDesktop, provider),
              ),
            ] else
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  if (!isDesktop)
                    _buildMobileAppBar(canvas, isOwner)
                  else
                    SliverToBoxAdapter(
                      child: _buildDesktopHeader(canvas, provider),
                    ),
                  if (provider.isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  else if (provider.activeItems.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    ..._buildTimelineSlivers(provider.activeItems),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),

            // Collaborative Cursors
            if (_isMapMode || isDesktop) ..._buildPresenceCursors(provider),

            // Pulses
            ..._pulses.map(
              (p) => PulseRipple(
                key: ValueKey(p.id),
                position: p.position,
                color: Colors.white,
              ),
            ),

            // Drawing Toolbar
            if (_isDrawingMode)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Center(
                  child: _DoodleToolbar(
                    selectedColor: _selectedDrawingColor,
                    strokeWidth: _drawingStrokeWidth,
                    onColorChanged: (color) =>
                        setState(() => _selectedDrawingColor = color),
                    onStrokeWidthChanged: (w) =>
                        setState(() => _drawingStrokeWidth = w),
                    onUndo: _undoLastSegment,
                    onClose: () => setState(() => _isDrawingMode = false),
                  ),
                ),
              ),

            // Right-side Timeline Scrubber (only in Spatial mode)
            if (provider.activeItems.isNotEmpty && _isMapMode)
              Positioned(
                right: 16,
                top: 100,
                bottom: 100,
                child: Center(
                  child: Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TimelineScrubber(
                      items: provider.activeItems,
                      scrollController: _scrollController,
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: isDesktop
            ? null
            : _TimelineAddItemTray(
                onAddText: () => _showAddNote(context),
                onAddPhoto: () => _pickAndUploadPhoto(),
                onAddVoice: () => _showVoiceRecorder(context),
                onAddSticker: () => _showStickerPicker(context),
                onAddMilestone: () => _showAddMilestone(context),
                onAddJournal: () => _showAddJournal(context),
                onToggleDrawing: () =>
                    setState(() => _isDrawingMode = !_isDrawingMode),
                isDrawingMode: _isDrawingMode,
              ),
      ),
    );
  }

  Widget _buildHeaderOverlay(
    OasisCanvas? canvas,
    bool isDesktop,
    CanvasProvider provider,
  ) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(
              FluentIcons.chevron_left_24_regular,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canvas?.title ?? 'Our Canvas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      _buildActiveUsersRow(provider),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isMapMode
                        ? FluentIcons.list_24_regular
                        : FluentIcons.glance_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isMapMode = !_isMapMode),
                ),
                IconButton(
                  icon: const Icon(
                    FluentIcons.people_add_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _showInviteSheet(canvas),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _sendPulse(Offset canvasPosition) {
    // CanvasPosition is already in absolute coordinates from InfiniteCanvas
    _triggerLocalPulse(canvasPosition);
    if (_pulseChannel != null) {
      _pulseChannel!.sendBroadcastMessage(
        event: 'pulse',
        payload: {'x': canvasPosition.dx, 'y': canvasPosition.dy},
      );
    }
  }

  void _triggerLocalPulse(Offset position) {
    // We need to map position to screen space if we want to show it on top of everything,
    // OR we just render it inside the InfiniteCanvas stack.
    // For now, let's keep it in screen space but this will be tricky with panning.
    // IMPROVEMENT: Pulse should be an item in InfiniteCanvas stack.
    final pulse = _PulseData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: position,
    );
    setState(() => _pulses.add(pulse));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _pulses.remove(pulse));
    });
  }

  Widget _buildMobileAppBar(OasisCanvas? canvas, bool isOwner) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          FluentIcons.chevron_left_24_regular,
          color: Colors.white,
        ),
        onPressed: () => context.pop(),
      ),
      title: Text(
        canvas?.title ?? 'Our Canvas',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isMapMode
                ? FluentIcons.list_24_regular
                : FluentIcons.glance_24_regular,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _isMapMode = !_isMapMode),
        ),
        IconButton(
          icon: const Icon(
            FluentIcons.people_add_24_regular,
            color: Colors.white,
          ),
          onPressed: () => _showInviteSheet(canvas),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(OasisCanvas? canvas, CanvasProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              FluentIcons.chevron_left_24_regular,
              color: Colors.white,
            ),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                canvas?.title ?? 'Our Canvas',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              _buildActiveUsersRow(provider),
            ],
          ),
          const Spacer(),
          _DesktopCanvasToolbar(
            onAddText: () => _showAddNote(context),
            onAddPhoto: () => _pickAndUploadPhoto(),
            onAddVoice: () => _showVoiceRecorder(context),
            onAddSticker: () => _showStickerPicker(context),
            onAddMilestone: () => _showAddMilestone(context),
            onToggleView: () => setState(() => _isMapMode = !_isMapMode),
            onToggleDrawing: () =>
                setState(() => _isDrawingMode = !_isDrawingMode),
            isMapMode: _isMapMode,
            isDrawingMode: _isDrawingMode,
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => _showInviteSheet(canvas),
            icon: const Icon(FluentIcons.people_add_20_regular, size: 18),
            label: const Text('Invite'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUsersRow(CanvasProvider provider) {
    final currentUserId = _getAuthorId();
    final othersCount =
        provider.presenceState.length -
        (provider.presenceState.containsKey(currentUserId) ? 1 : 0);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${othersCount + 1} online',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPresenceCursors(CanvasProvider provider) {
    final List<Widget> cursors = [];
    final currentUserId = _getAuthorId();

    provider.presenceState.forEach((userId, stateList) {
      if (userId == currentUserId) return;

      final state = (stateList as List).first;
      final x = (state['x'] as num?)?.toDouble() ?? 0.5;
      final y = (state['y'] as num?)?.toDouble() ?? 0.5;

      cursors.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.linear,
          left: x * MediaQuery.of(context).size.width,
          top: y * MediaQuery.of(context).size.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                FluentIcons.cursor_24_filled,
                size: 20,
                color: Colors.blueAccent,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Friend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });

    return cursors;
  }

  void _showInviteSheet(OasisCanvas? canvas) {
    if (canvas == null) return;
    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSheet(
        title: 'Share Canvas',
        payload: '[INVITE:canvas:${canvas.id}:${canvas.title}]',
      ),
    );
  }

  void _showAddJournal(BuildContext context) {
    final controller = TextEditingController();
    final authorId = _getAuthorId();

    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Color(0xFFFDFCF0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'NEW JOURNAL ENTRY',
                    style: GoogleFonts.montserrat(
                      color: Colors.brown[300],
                      letterSpacing: 2,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.brown),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Pour your thoughts here...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      context.read<CanvasProvider>().addItem(
                        authorId: authorId,
                        type: CanvasItemType.journal,
                        content: controller.text.trim(),
                        xPos: 0,
                        yPos: 0,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                  ),
                  child: const Text('Seal Entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimelineSlivers(List<CanvasItemEntity> items) {
    final sortedItems = List<CanvasItemEntity>.from(items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final List<dynamic> timelineGroups = [];
    for (int i = 0; i < sortedItems.length; i++) {
      final item = sortedItems[i];
      if (item.type == CanvasItemType.photo) {
        final List<CanvasItemEntity> stack = [item];
        while (i + 1 < sortedItems.length &&
            sortedItems[i + 1].type == CanvasItemType.photo &&
            item.createdAt
                    .difference(sortedItems[i + 1].createdAt)
                    .inHours
                    .abs() <
                1) {
          stack.add(sortedItems[++i]);
        }
        timelineGroups.add(stack);
      } else {
        timelineGroups.add(item);
      }
    }

    final List<Widget> slivers = [];
    String? currentMonth;

    for (var group in timelineGroups) {
      final firstItem = group is List
          ? group.first as CanvasItemEntity
          : group as CanvasItemEntity;
      final monthStr = DateFormat('MMMM yyyy').format(firstItem.createdAt);

      if (monthStr != currentMonth) {
        currentMonth = monthStr;
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    monthStr.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 4,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: _buildTimelineItem(group),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildTimelineItem(dynamic group) {
    final currentUserId = _getAuthorId();

    if (group is List<CanvasItemEntity>) {
      final isLocked = group.any(
        (item) =>
            item.unlockAt != null && item.unlockAt!.isAfter(DateTime.now()),
      );
      if (isLocked) return _buildTimeCapsuleWidget(group.first);
      return ScatteredPolaroidSpread(items: group);
    }

    final item = group as CanvasItemEntity;
    final isLocked =
        item.unlockAt != null && item.unlockAt!.isAfter(DateTime.now());
    if (isLocked) return _buildTimeCapsuleWidget(item);

    return Align(
      alignment: Alignment.center,
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
        onDelete: () => context.read<CanvasProvider>().deleteItem(item.id),
        onReact: (emoji) => context.read<CanvasProvider>().toggleReaction(
          item.id,
          currentUserId,
          emoji,
        ),
        onLock: (lock) =>
            context.read<CanvasProvider>().setItemLock(item.id, lock),
      ),
    );
  }

  Widget _buildTimeCapsuleWidget(CanvasItemEntity item) {
    final timeLeft = item.unlockAt!.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(
            FluentIcons.lock_closed_24_regular,
            color: Colors.amber,
            size: 32,
          ),
          const SizedBox(height: 16),
          const Text(
            'TIME CAPSULE',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlocks in ${timeLeft.inDays}d ${timeLeft.inHours % 24}h',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingLayer() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _currentPoints.add(
            DrawingPoint(
              point: details.localPosition,
              paint: Paint()
                ..color = _selectedDrawingColor
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = _drawingStrokeWidth
                ..isAntiAlias = true,
            ),
          );
        });
        _startMorphTimer();
      },
      onPanUpdate: (details) {
        setState(() {
          _currentPoints.add(
            DrawingPoint(
              point: details.localPosition,
              paint: Paint()
                ..color = _selectedDrawingColor
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = _drawingStrokeWidth
                ..isAntiAlias = true,
            ),
          );
        });
        _lastPointerPosition = details.localPosition;
      },
      onPanEnd: (details) {
        _morphTimer?.cancel();
        _currentPoints.add(null);
        _finishDoodle();
      },
      child: CustomPaint(
        painter: CanvasDrawingPainter(pointsList: _currentPoints),
        size: Size.infinite,
      ),
    );
  }

  void _startMorphTimer() {
    _morphTimer?.cancel();
    _morphTimer = Timer(const Duration(milliseconds: 800), () {
      if (_currentPoints.isNotEmpty) {
        _tryMorphShape();
      }
    });
  }

  void _undoLastSegment() {
    if (_currentPoints.isEmpty) return;
    setState(() {
      int lastNullIndex = _currentPoints.lastIndexOf(null);
      if (lastNullIndex == -1) {
        _currentPoints = [];
      } else if (lastNullIndex == _currentPoints.length - 1) {
        _currentPoints.removeLast();
        lastNullIndex = _currentPoints.lastIndexOf(null);
        if (lastNullIndex == -1) {
          _currentPoints = [];
        } else {
          _currentPoints.removeRange(lastNullIndex + 1, _currentPoints.length);
        }
      } else {
        _currentPoints.removeRange(lastNullIndex + 1, _currentPoints.length);
      }
    });
  }

  void _tryMorphShape() {
    final points = _currentPoints
        .where((p) => p != null)
        .map((p) => p!.point)
        .toList();
    if (points.isEmpty) return;

    final shape = ShapeRecognizer.recognize(points);
    if (shape.type != RecognizedShapeType.unknown) {
      final authorId = _getAuthorId();
      if (authorId.isEmpty) return;

      context.read<CanvasProvider>().addItem(
        authorId: authorId,
        type: CanvasItemType.shape,
        content: shape.type.name,
        xPos: shape.bounds.left / _canvasScale,
        yPos: shape.bounds.top / _canvasScale,
        metadata: {'w': shape.bounds.width, 'h': shape.bounds.height},
      );

      setState(() {
        _currentPoints = [];
        _isDrawingMode = false;
      });
      _morphTimer?.cancel();
    }
  }

  void _finishDoodle() {
    if (_currentPoints.isEmpty) return;
    final points = _currentPoints
        .where((p) => p != null)
        .map((p) => p!.point)
        .toList();
    if (points.length < 5) {
      setState(() => _currentPoints = []);
      return;
    }

    final authorId = _getAuthorId();
    if (authorId.isEmpty) return;

    double minX = points[0].dx;
    double minY = points[0].dy;
    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
    }

    final relativePoints = points
        .map((p) => Offset(p.dx - minX, p.dy - minY))
        .toList();
    // Filter out any invalid points before joining
    final content = relativePoints
        .where((p) => p.dx.isFinite && p.dy.isFinite)
        .map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}')
        .join(';');

    if (content.isEmpty) {
      setState(() => _currentPoints = []);
      return;
    }

    context.read<CanvasProvider>().addItem(
      authorId: authorId,
      type: CanvasItemType.doodle,
      content: Uri.encodeComponent(content),
      color: '#${_selectedDrawingColor.value.toRadixString(16).substring(2)}',
      xPos: minX / _canvasScale,
      yPos: minY / _canvasScale,
      metadata: {
        'w': points.map((p) => p.dx).reduce(max) - minX,
        'h': points.map((p) => p.dy).reduce(max) - minY,
      },
    );

    setState(() => _currentPoints = []);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.star_24_regular,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your timeline is waiting for memories',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showAddNote(BuildContext context) {
    final controller = TextEditingController();
    final authorId = _getAuthorId();
    final colors = ['#3B82F6', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6'];
    String selectedColor = colors[0];
    DateTime? unlockAt;

    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1F26),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create Core Memory',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What happened?',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: colors
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setModalState(() => selectedColor = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  'FF${c.replaceAll('#', '')}',
                                  radix: 16,
                                ),
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    FluentIcons.lock_closed_24_regular,
                    color: Colors.amber,
                  ),
                  title: Text(
                    unlockAt == null
                        ? 'Set Unlock Date (Optional)'
                        : 'Unlocks: ${DateFormat('yMMMd').format(unlockAt!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  trailing: unlockAt != null
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => setModalState(() => unlockAt = null),
                        )
                      : const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 10),
                      ),
                    );
                    if (date != null) {
                      setModalState(() => unlockAt = date);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context.read<CanvasProvider>().addItem(
                          authorId: authorId,
                          type: CanvasItemType.text,
                          content: controller.text.trim(),
                          color: selectedColor,
                          xPos: 0,
                          yPos: 0,
                          unlockAt: unlockAt,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Add to Timeline'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMilestone(BuildContext context) {
    final controller = TextEditingController();
    final authorId = _getAuthorId();
    final colors = ['#F59E0B', '#8B5CF6', '#EC4899', '#10B981', '#3B82F6'];
    String selectedColor = colors[0];

    context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1F26),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'New Milestone',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLines: 1,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'Chapter Name (e.g. Summer Trip)',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: colors
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setModalState(() => selectedColor = c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  'FF${c.replaceAll('#', '')}',
                                  radix: 16,
                                ),
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context.read<CanvasProvider>().addItem(
                          authorId: authorId,
                          type: CanvasItemType.milestone,
                          content: controller.text.trim(),
                          color: selectedColor,
                          xPos: 0,
                          yPos: 0,
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Pin Milestone'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      if (!mounted) return;
      final authorId = _getAuthorId();
      final canvasService = CanvasService();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploading ${images.length} photos...')),
      );

      for (var img in images) {
        final url = await canvasService.uploadCanvasImage(
          widget.canvasId,
          img.path,
        );
        if (mounted) {
          context.read<CanvasProvider>().addItem(
            authorId: authorId,
            type: CanvasItemType.photo,
            content: url,
            xPos: 0,
            yPos: 0,
          );
        }
      }
    }
  }

  void _showStickerPicker(BuildContext context) {
    final stickers = ['❤️', '🔥', '✨', '😂', '🎉', '🌟', '👍', '💡'];

    context.showResponsiveSheet(
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Sticker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: stickers
                  .map(
                    (sticker) => GestureDetector(
                      onTap: () {
                        context.read<CanvasProvider>().addItem(
                          authorId: _getAuthorId(),
                          type: CanvasItemType.sticker,
                          content: sticker,
                          xPos: 0,
                          yPos: 0,
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        sticker,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showVoiceRecorder(BuildContext context) {
    bool isRecording = false;
    String? recordPath;

    context.showResponsiveSheet(
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (innerModalCtx, setModalState) => Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F26),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRecording ? 'Recording...' : 'Record Voice Memo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  if (isRecording) {
                    final path = await _audioRecorder.stop();
                    setModalState(() {
                      isRecording = false;
                      recordPath = path;
                    });

                    if (recordPath != null && modalCtx.mounted) {
                      final authorId = _getAuthorId();
                      final canvasProvider = modalCtx.read<CanvasProvider>();
                      final messenger = ScaffoldMessenger.of(modalCtx);
                      final canvasService = CanvasService();

                      Navigator.pop(modalCtx);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Uploading voice memo...'),
                        ),
                      );

                      try {
                        final url = await canvasService.uploadCanvasAudio(
                          widget.canvasId,
                          recordPath!,
                        );
                        if (mounted) {
                          canvasProvider.addItem(
                            authorId: authorId,
                            type: CanvasItemType.voice,
                            content: url,
                            xPos: 0,
                            yPos: 0,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to upload: $e')),
                          );
                        }
                      }
                    }
                  } else {
                    if (await _audioRecorder.hasPermission()) {
                      final tempDir = await getTemporaryDirectory();
                      final path =
                          '${tempDir.path}/canvas_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
                      await _audioRecorder.start(
                        const RecordConfig(),
                        path: path,
                      );
                      setModalState(() => isRecording = true);
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isRecording
                        ? Colors.red
                        : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    isRecording
                        ? FluentIcons.stop_24_filled
                        : FluentIcons.mic_24_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!isRecording)
                TextButton(
                  onPressed: () => Navigator.pop(modalCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderOverlay extends StatelessWidget {
  final OasisCanvas? canvas;
  final bool isDesktop;
  final CanvasProvider provider;
  final VoidCallback onToggleView;
  final VoidCallback onInvite;
  final String currentUserId;

  const _HeaderOverlay({
    required this.canvas,
    required this.isDesktop,
    required this.provider,
    required this.onToggleView,
    required this.onInvite,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(
              FluentIcons.chevron_left_24_regular,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canvas?.title ?? 'Our Canvas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      _ActiveUsersRow(
                        provider: provider,
                        currentUserId: currentUserId,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    FluentIcons.glance_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onToggleView,
                ),
                IconButton(
                  icon: const Icon(
                    FluentIcons.people_add_24_regular,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onInvite,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveUsersRow extends StatelessWidget {
  final CanvasProvider provider;
  final String currentUserId;

  const _ActiveUsersRow({required this.provider, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final othersCount =
        provider.presenceState.length -
        (provider.presenceState.containsKey(currentUserId) ? 1 : 0);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${othersCount + 1} online',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DesktopCanvasToolbar extends StatelessWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVoice;
  final VoidCallback onAddSticker;
  final VoidCallback onAddMilestone;
  final VoidCallback onToggleView;
  final VoidCallback onToggleDrawing;
  final bool isMapMode;
  final bool isDrawingMode;

  const _DesktopCanvasToolbar({
    required this.onAddText,
    required this.onAddPhoto,
    required this.onAddVoice,
    required this.onAddSticker,
    required this.onAddMilestone,
    required this.onToggleView,
    required this.onToggleDrawing,
    required this.isMapMode,
    required this.isDrawingMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarAction(
            icon: FluentIcons.text_description_24_regular,
            label: 'Note',
            onTap: onAddText,
          ),
          _ToolbarAction(
            icon: FluentIcons.image_24_regular,
            label: 'Photo',
            onTap: onAddPhoto,
          ),
          _ToolbarAction(
            icon: FluentIcons.mic_24_regular,
            label: 'Voice',
            onTap: onAddVoice,
          ),
          _ToolbarAction(
            icon: FluentIcons.sticker_24_regular,
            label: 'Sticker',
            onTap: onAddSticker,
          ),
          _ToolbarAction(
            icon: FluentIcons.star_24_regular,
            label: 'Milestone',
            onTap: onAddMilestone,
          ),
          _ToolbarAction(
            icon: FluentIcons.gesture_24_regular,
            label: 'Doodle',
            onTap: onToggleDrawing,
            isVibrant: isDrawingMode,
          ),
          const VerticalDivider(
            width: 24,
            indent: 8,
            endIndent: 8,
            color: Colors.white10,
          ),
          _ToolbarAction(
            icon: isMapMode
                ? FluentIcons.list_24_regular
                : FluentIcons.glance_24_regular,
            label: isMapMode ? 'Timeline' : 'Spatial',
            onTap: onToggleView,
            isVibrant: true,
          ),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isVibrant;

  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isVibrant = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: isVibrant ? Colors.blueAccent : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _TimelineAddItemTray extends StatefulWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVoice;
  final VoidCallback onAddSticker;
  final VoidCallback onAddMilestone;
  final VoidCallback onAddJournal;
  final VoidCallback onToggleDrawing;
  final bool isDrawingMode;

  const _TimelineAddItemTray({
    required this.onAddText,
    required this.onAddPhoto,
    required this.onAddVoice,
    required this.onAddSticker,
    required this.onAddMilestone,
    required this.onAddJournal,
    required this.onToggleDrawing,
    required this.isDrawingMode,
  });

  @override
  State<_TimelineAddItemTray> createState() => _TimelineAddItemTrayState();
}

class _TimelineAddItemTrayState extends State<_TimelineAddItemTray> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_expanded) ...[
          FloatingActionButton.small(
            heroTag: 'milestone',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddMilestone();
            },
            backgroundColor: Colors.white,
            child: const Icon(FluentIcons.star_24_regular, color: Colors.black),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'journal',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddJournal();
            },
            backgroundColor: const Color(0xFFFDFCF0),
            child: const Icon(FluentIcons.book_24_regular, color: Colors.brown),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'sticker',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddSticker();
            },
            backgroundColor: Colors.white,
            child: const Icon(
              FluentIcons.sticker_24_regular,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'doodle',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onToggleDrawing();
            },
            backgroundColor: widget.isDrawingMode
                ? Colors.blueAccent
                : Colors.white,
            child: Icon(
              FluentIcons.gesture_24_regular,
              color: widget.isDrawingMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'voice',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddVoice();
            },
            backgroundColor: Colors.white,
            child: const Icon(FluentIcons.mic_24_regular, color: Colors.black),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'note',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddText();
            },
            backgroundColor: Colors.white,
            child: const Icon(FluentIcons.note_24_regular, color: Colors.black),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'photo',
            onPressed: () {
              setState(() => _expanded = false);
              widget.onAddPhoto();
            },
            backgroundColor: Colors.white,
            child: const Icon(
              FluentIcons.image_24_regular,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(_expanded ? Icons.close : Icons.add, color: Colors.white),
        ),
      ],
    );
  }
}

class _DoodleToolbar extends StatelessWidget {
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  const _DoodleToolbar({
    required this.selectedColor,
    required this.strokeWidth,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.white,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.yellowAccent,
      Colors.greenAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...colors.map(
                (color) => _DoodleColorButton(
                  color: color,
                  isSelected: selectedColor == color,
                  onTap: () => onColorChanged(color),
                ),
              ),
              const VerticalDivider(width: 20, color: Colors.white24),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white),
                onPressed: onUndo,
                tooltip: 'Undo',
              ),
              IconButton(
                icon: const Icon(Icons.check, color: Colors.greenAccent),
                onPressed: onClose,
                tooltip: 'Finish',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.line_weight, color: Colors.white70, size: 16),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: strokeWidth,
                    min: 1.0,
                    max: 15.0,
                    onChanged: onStrokeWidthChanged,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoodleColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DoodleColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}
