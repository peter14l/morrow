import 'dart:math';
import 'package:flutter/material.dart';

class StarryNightBackground extends StatefulWidget {
  final Offset offset;
  final Widget? child;

  const StarryNightBackground({
    super.key,
    this.offset = Offset.zero,
    this.child,
  });

  @override
  State<StarryNightBackground> createState() => _StarryNightBackgroundState();
}

class _StarryNightBackgroundState extends State<StarryNightBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<StarModel> _stars = [];
  final int _starCount = 200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _generateStars();
  }

  void _generateStars() {
    final random = Random();
    for (int i = 0; i < _starCount; i++) {
      _stars.add(
        StarModel(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: random.nextDouble() * 2.5 + 0.5,
          twinkleSpeed: random.nextDouble() * 2 + 1,
          twinkleOffset: random.nextDouble() * pi * 2,
          parallax: random.nextDouble() * 0.15 + 0.05,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFF0F1115),
        ), // Slightly lighter black for depth

        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: StarPainter(
                stars: _stars,
                twinkleProgress: _controller.value,
                offset: widget.offset,
              ),
              size: Size.infinite,
            );
          },
        ),

        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class StarModel {
  final double x;
  final double y;
  final double size;
  final double twinkleSpeed;
  final double twinkleOffset;
  final double parallax;

  StarModel({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinkleOffset,
    required this.parallax,
  });
}

class StarPainter extends CustomPainter {
  final List<StarModel> stars;
  final double twinkleProgress;
  final Offset offset;

  StarPainter({
    required this.stars,
    required this.twinkleProgress,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      final opacity =
          (sin(
                twinkleProgress * 2 * pi * star.twinkleSpeed +
                    star.twinkleOffset,
              ) +
              1) /
          2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.2 + (opacity * 0.8));

      // Calculate position with 2D parallax and wrapping
      double xPos =
          (star.x * size.width - (offset.dx * star.parallax)) % size.width;
      double yPos =
          (star.y * size.height - (offset.dy * star.parallax)) % size.height;

      if (xPos < 0) xPos += size.width;
      if (yPos < 0) yPos += size.height;

      canvas.drawCircle(Offset(xPos, yPos), star.size / 2, paint);

      if (star.size > 2.0) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(Offset(xPos, yPos), star.size * 1.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.twinkleProgress != twinkleProgress ||
        oldDelegate.offset != offset;
  }
}
