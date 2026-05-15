import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

typedef WhisperDragBuilder =
    Widget Function(
      BuildContext context,
      double dragProgress,
      double dragOffset,
    );

/// Whisper mode drag gesture (Instagram-style).
/// Dragging up past a threshold toggles the mode.
class ChatWhisperGesture extends StatefulWidget {
  const ChatWhisperGesture({
    super.key,
    required this.builder,
    required this.isWhisperMode,
    required this.onWhisperToggle,
  });

  final WhisperDragBuilder builder;
  final int isWhisperMode;
  final VoidCallback onWhisperToggle;

  @override
  State<ChatWhisperGesture> createState() => _ChatWhisperGestureState();
}

class _ChatWhisperGestureState extends State<ChatWhisperGesture> {
  double _dragProgress = 0.0;
  double _dragOffset = 0.0;
  bool _triggered = false;
  static const double _dragThreshold = 120.0;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // Only allow dragging UP
    if (details.primaryDelta! > 0 && _dragOffset <= 0) return;

    setState(() {
      _dragOffset -= details.primaryDelta!;
      if (_dragOffset < 0) _dragOffset = 0;

      _dragProgress = (_dragOffset / _dragThreshold).clamp(0.0, 1.0);

      if (_dragProgress >= 1.0 && !_triggered) {
        _triggered = true;
        HapticUtils.heavyImpact();
      } else if (_dragProgress < 1.0 && _triggered) {
        _triggered = false;
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_triggered) {
      widget.onWhisperToggle();
    }

    setState(() {
      _dragOffset = 0.0;
      _dragProgress = 0.0;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: widget.builder(context, _dragProgress, _dragOffset),
    );
  }
}
