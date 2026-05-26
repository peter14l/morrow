import 'package:flutter/material.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  double _dragOffset = 0.0;
  bool _isTriggered = false;

  static const double _triggerThreshold = 60.0;
  static const double _maxDrag = 90.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = _controller.drive(
      Tween<Offset>(begin: Offset.zero, end: Offset.zero),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    setState(() {
      _dragOffset += details.primaryDelta!;
      // Only allow swiping to the right (common for reply)
      if (_dragOffset < 0) _dragOffset = 0;
      if (_dragOffset > _maxDrag) _dragOffset = _maxDrag;

      if (_dragOffset >= _triggerThreshold && !_isTriggered) {
        _isTriggered = true;
        HapticUtils.lightImpact();
      } else if (_dragOffset < _triggerThreshold && _isTriggered) {
        _isTriggered = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    if (_isTriggered) {
      widget.onReply();
    }

    setState(() {
      _dragOffset = 0;
      _isTriggered = false;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Reply Icon Background
          Positioned(
            left: 16,
            child: Opacity(
              opacity: (_dragOffset / _triggerThreshold).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: (_dragOffset / _triggerThreshold).clamp(0.5, 1.2),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isTriggered
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: _isTriggered
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          // Swipable Content
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
