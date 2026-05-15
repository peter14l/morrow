import 'package:flutter/material.dart';
import 'dart:math' as math;

class FluidMeshBackground extends StatefulWidget {
  final int streakCount;
  const FluidMeshBackground({super.key, required this.streakCount});

  @override
  State<FluidMeshBackground> createState() => _FluidMeshBackgroundState();
}

class _FluidMeshBackgroundState extends State<FluidMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Muted colors for broken streak (0), vibrant for high streak
    final isBroken = widget.streakCount == 0;
    final baseColor = isBroken ? Colors.blueGrey.shade900 : colorScheme.primary;

    final secondaryColor = isBroken ? Colors.black : colorScheme.tertiary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshPainter(
            animationValue: _controller.value,
            baseColor: baseColor,
            secondaryColor: secondaryColor,
            intensity: isBroken ? 0.3 : 0.8,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;
  final Color secondaryColor;
  final double intensity;

  _MeshPainter({
    required this.animationValue,
    required this.baseColor,
    required this.secondaryColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw base background
    canvas.drawRect(rect, Paint()..color = baseColor.withValues(alpha: 0.2));

    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + (i * 0.33)) % 1.0;
      final x = size.width * (0.5 + 0.3 * math.cos(progress * 2 * math.pi + i));
      final y =
          size.height * (0.5 + 0.3 * math.sin(progress * 2 * math.pi + i));

      final radius = size.width * (0.6 + 0.2 * math.sin(progress * math.pi));

      final gradient = RadialGradient(
        colors: [
          secondaryColor.withValues(alpha: 0.3 * intensity),
          Colors.transparent,
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset(x, y), radius: radius),
        );

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => true;
}
