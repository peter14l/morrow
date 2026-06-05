import 'package:oasis/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

/// Swipeable message widget for quick reply action
class SwipeableMessage extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeReply;
  final bool isOwnMessage;

  const SwipeableMessage({
    super.key,
    required this.child,
    required this.onSwipeReply,
    this.isOwnMessage = false,
  });

  @override
  State<SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<SwipeableMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  static const double _swipeThreshold = 60;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;

    // Only allow swipe in one direction based on message ownership
    if (widget.isOwnMessage) {
      // Own messages swipe left (negative)
      _dragExtent = (_dragExtent + delta).clamp(-100.0, 0.0);
    } else {
      // Other messages swipe right (positive)
      _dragExtent = (_dragExtent + delta).clamp(0.0, 100.0);
    }

    setState(() {});
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _swipeThreshold) {
      HapticUtils.mediumImpact();
      widget.onSwipeReply();
    }

    setState(() => _dragExtent = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (_dragExtent.abs() / _swipeThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: widget.isOwnMessage
            ? Alignment.centerRight
            : Alignment.centerLeft,
        children: [
          // Reply icon behind the message
          Positioned(
            left: widget.isOwnMessage ? null : 8,
            right: widget.isOwnMessage ? 8 : null,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // The actual message
          Transform.translate(
            offset: Offset(_dragExtent * 0.5, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Pull-to-refresh with haptic feedback
class HapticRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const HapticRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticUtils.pullToRefresh();
        await onRefresh();
      },
      child: child,
    );
  }
}

/// Double-tap to like anywhere widget
class DoubleTapLike extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;
  final bool showAnimation;

  const DoubleTapLike({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.showAnimation = true,
  });

  @override
  State<DoubleTapLike> createState() => _DoubleTapLikeState();
}

class _DoubleTapLikeState extends State<DoubleTapLike>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showHeart = false;
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    HapticUtils.mediumImpact();
    widget.onDoubleTap();

    if (widget.showAnimation) {
      setState(() {
        _showHeart = true;
        _tapPosition = details.localPosition;
      });
      _controller.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _showHeart = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      child: Stack(
        children: [
          widget.child,
          if (_showHeart)
            Positioned(
              left: _tapPosition.dx - 40,
              top: _tapPosition.dy - 40,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 80,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Long press quick actions menu
class LongPressQuickActions extends StatelessWidget {
  final Widget child;
  final List<QuickAction> actions;
  final VoidCallback? onLongPress;

  const LongPressQuickActions({
    super.key,
    required this.child,
    required this.actions,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticUtils.mediumImpact();
        onLongPress?.call();
        _showQuickActions(context);
      },
      child: child,
    );
  }

  void _showQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    context.showResponsiveSheet(
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...actions.map(
              (action) => ListTile(
                leading: Icon(action.icon, color: action.color),
                title: Text(action.label),
                onTap: () {
                  HapticUtils.selectionClick();
                  Navigator.pop(context);
                  action.onTap();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}
