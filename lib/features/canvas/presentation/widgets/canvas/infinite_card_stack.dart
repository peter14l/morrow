import 'package:flutter/material.dart';
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InfiniteCardStack extends StatelessWidget {
  final List<CanvasItemEntity> items;
  final double width;
  final double height;

  const InfiniteCardStack({
    super.key,
    required this.items,
    this.width = 300,
    this.height = 380,
  });

  void _openPreview(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Preview',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            // Background tap to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // The interactive swipeable stack
            Center(
              child: Material(
                color: Colors.transparent,
                child: _SwipeableCardStack(
                  items: items,
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.7,
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    const int maxDisplay = 5;
    final displayItems = items.take(maxDisplay).toList();
    final int extraCount = items.length - maxDisplay;

    // We want the first item (oldest/newest? based on input list) to be visually on top.
    // The input list is items. The first item is items[0].
    // So items[0] should be rendered last in the Stack.
    // And to make a fan, we calculate an angle for each item.

    return GestureDetector(
      onTap: () => _openPreview(context),
      child: Container(
        width: width,
        height: height,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(displayItems.length, (index) {
            // Reverse index for rendering (rendered from back to front)
            // If displayItems.length = 3 (0, 1, 2)
            // renderIndex 0 should be item index 2 (backmost)
            // renderIndex 1 should be item index 1
            // renderIndex 2 should be item index 0 (topmost)
            final itemIndex = displayItems.length - 1 - index;
            final item = displayItems[itemIndex];

            // Calculate fan angle based on itemIndex.
            // Let's spread them symmetrically.
            // Middle index is (length - 1) / 2
            final middleIndex = (displayItems.length - 1) / 2.0;
            final positionOffset =
                itemIndex - middleIndex; // e.g. -2, -1, 0, 1, 2

            const double angleStep = 0.15; // roughly 8.5 degrees
            final double angle = positionOffset * angleStep;

            // We can also lower the outer cards a bit or let rotation handle it
            // rotation with Alignment.bottomCenter naturally lowers the top edges.

            final bool isBackmost =
                index == 0; // The first one rendered is the furthest back
            final int? addCount = isBackmost && extraCount > 0
                ? extraCount
                : null;

            return Transform.rotate(
              angle: angle,
              alignment: const Alignment(
                0,
                0.8,
              ), // Rotates around a point near the bottom
              child: _buildCardVisually(
                item: item,
                width: width - 40,
                height: height - 60,
                additionalCount: addCount,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCardVisually({
    required CanvasItemEntity item,
    required double width,
    required double height,
    int? additionalCount,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: item.content,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                if (additionalCount != null && additionalCount > 0)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+$additionalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              'Captured on ${item.createdAt.day}/${item.createdAt.month}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The swipeable stack for the fullscreen preview
// ─────────────────────────────────────────────────────────────────────────────

class _SwipeableCardStack extends StatefulWidget {
  final List<CanvasItemEntity> items;
  final double width;
  final double height;

  const _SwipeableCardStack({
    required this.items,
    required this.width,
    required this.height,
  });

  @override
  State<_SwipeableCardStack> createState() => _SwipeableCardStackState();
}

class _SwipeableCardStackState extends State<_SwipeableCardStack> {
  late List<CanvasItemEntity> _displayItems;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _displayItems = List.from(widget.items);
  }

  @override
  void didUpdateWidget(_SwipeableCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _displayItems = List.from(widget.items);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Determine if it was dragged far enough right (or left/up/down)
    if (_dragOffset.dx > 100 ||
        _dragOffset.dx < -100 ||
        _dragOffset.dy.abs() > 100) {
      _moveToBack();
    } else {
      // Return to center
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _moveToBack() {
    setState(() {
      final top = _displayItems.removeAt(0);
      _displayItems.add(top);
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_displayItems.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: _displayItems.reversed.toList().asMap().entries.map((entry) {
          final item = entry.value;
          final indexFromFront = _displayItems.indexOf(item);
          final isTop = indexFromFront == 0;

          // Only render top 3 cards to avoid performance issues if list is huge
          if (indexFromFront > 2) return const SizedBox.shrink();

          return _buildInteractiveCard(item, indexFromFront, isTop);
        }).toList(),
      ),
    );
  }

  Widget _buildInteractiveCard(
    CanvasItemEntity item,
    int indexFromFront,
    bool isTop,
  ) {
    final double scale = isTop
        ? 1.0
        : (1.0 - (indexFromFront * 0.05)).clamp(0.8, 1.0);
    final double topPadding = indexFromFront * 16.0;
    final double rotation = indexFromFront * 0.02;

    final Widget card = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: item.content,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Captured on ${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );

    if (isTop) {
      return AnimatedPositioned(
        duration: _isDragging
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        left: _dragOffset.dx,
        top: _dragOffset.dy + topPadding,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Transform.rotate(
            angle: (_dragOffset.dx / 1000) + rotation,
            child: card,
          ),
        ),
      );
    } else {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 400),
        top: topPadding,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 400),
          scale: scale,
          child: Transform.rotate(angle: rotation, child: card),
        ),
      );
    }
  }
}
