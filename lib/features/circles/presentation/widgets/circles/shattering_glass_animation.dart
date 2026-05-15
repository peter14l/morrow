import 'package:flutter/material.dart';
import 'dart:math' as math;

class ShatteringGlassAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  const ShatteringGlassAnimation({super.key, required this.onComplete});

  @override
  State<ShatteringGlassAnimation> createState() =>
      _ShatteringGlassAnimationState();
}

class _ShatteringGlassAnimationState extends State<ShatteringGlassAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_GlassShard> _shards = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Create shards
    final random = math.Random();
    for (int i = 0; i < 30; i++) {
      _shards.add(
        _GlassShard(
          angle: random.nextDouble() * 2 * math.pi,
          distance: random.nextDouble() * 200 + 50,
          size: random.nextDouble() * 30 + 10,
          rotation: random.nextDouble() * 4 * math.pi,
        ),
      );
    }

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _shards.map((shard) {
            final progress = _controller.value;
            final opacity = (1.0 - progress).clamp(0.0, 1.0);
            final currentDistance = shard.distance * progress;
            final currentRotation = shard.rotation * progress;

            return Positioned(
              left:
                  MediaQuery.of(context).size.width / 2 +
                  math.cos(shard.angle) * currentDistance -
                  shard.size / 2,
              top:
                  MediaQuery.of(context).size.height / 2 +
                  math.sin(shard.angle) * currentDistance -
                  shard.size / 2,
              child: Transform.rotate(
                angle: currentRotation,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: shard.size,
                    height: shard.size,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white54, width: 0.5),
                    ),
                    child: CustomPaint(painter: _ShardPainter()),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _GlassShard {
  final double angle;
  final double distance;
  final double size;
  final double rotation;

  _GlassShard({
    required this.angle,
    required this.distance,
    required this.size,
    required this.rotation,
  });
}

class _ShardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.1);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width * 0.6, size.height * 0.9);
    path.lineTo(size.width * 0.1, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
