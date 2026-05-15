import 'dart:ui';
import 'package:flutter/material.dart';

/// A widget that hides its content behind a 'spoiler' effect.
/// The content is revealed when the user taps on it.
class SpoilerWidget extends StatefulWidget {
  const SpoilerWidget({
    super.key,
    required this.child,
    this.isSpoiler = true,
    this.label = 'SPOILER',
  });

  final Widget child;
  final bool isSpoiler;
  final String label;

  @override
  State<SpoilerWidget> createState() => _SpoilerWidgetState();
}

class _SpoilerWidgetState extends State<SpoilerWidget> {
  bool _isRevealed = false;

  @override
  void didUpdateWidget(SpoilerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpoiler != oldWidget.isSpoiler) {
      if (!widget.isSpoiler) {
        _isRevealed = true;
      } else {
        _isRevealed = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpoiler || _isRevealed) {
      return widget.child;
    }

    return GestureDetector(
      onTap: () => setState(() => _isRevealed = true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The blurred content
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: widget.child,
            ),
          ),

          // Overlay to make it darker and show the label
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Spoiler Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
