import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A widget that applies a procedural 'dissolve' (grainy/noise) effect to its child.
/// Useful for indicating a pending or 'unsent' state.
class DissolveEffect extends StatefulWidget {
  const DissolveEffect({
    super.key,
    required this.child,
    this.isDissolving = true,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  final Widget child;
  final bool isDissolving;
  final Duration animationDuration;

  @override
  State<DissolveEffect> createState() => _DissolveEffectState();
}

class _DissolveEffectState extends State<DissolveEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    if (widget.isDissolving) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DissolveEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDissolving && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isDissolving && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDissolving) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.7 + (_controller.value * 0.2)),
                Colors.white.withValues(alpha: 0.5 + (_controller.value * 0.3)),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.modulate,
          child: CustomPaint(
            painter: _DissolvePainter(
              progress: _controller.value,
              seed: 42, // Fixed seed for consistent but 'random' look
            ),
            child: widget.child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _DissolvePainter extends CustomPainter {
  final double progress;
  final int seed;

  _DissolvePainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 + (progress * 0.05))
      ..strokeWidth = 1.0;

    final random = Random(seed);

    // Draw subtle grainy dots over the area
    // This is a simple CPU-based grain. For high performance/density, a fragment shader is better.
    // But for small chat bubbles, this is fine.
    final int dotCount = (size.width * size.height / 20).toInt();
    for (int i = 0; i < dotCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;

      // Only draw if it's 'dissolving' at this point
      // We simulate a noise threshold
      if (random.nextDouble() < 0.2 + (progress * 0.1)) {
        canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DissolvePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
