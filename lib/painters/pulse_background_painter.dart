import 'dart:math';
import 'package:flutter/material.dart';

/// Custom painter for the Pulse Map background
/// Draws radial grid and scattered stars for spatial context
class PulseBackgroundPainter extends CustomPainter {
  final Color gridColor;
  final Color starColor;
  final List<Offset>? nodePositions; // Nodes to connect
  final double animationValue; // 0.0 to 1.0 for animations

  PulseBackgroundPainter({
    required this.gridColor,
    required this.starColor,
    this.nodePositions,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw dynamic gradient background (nebula effect)
    _drawNebulaBackground(canvas, size, center);

    // Draw radial grid
    _drawRadialGrid(canvas, size, center);

    // Draw connecting lines between nodes
    if (nodePositions != null) {
      _drawConnections(canvas, nodePositions!, center);
    }

    // Draw drifting particles
    _drawParticles(canvas, size, center);

    // Draw center ripple effect
    _drawCenterRipple(canvas, center);

    // Draw center marker
    _drawCenterMarker(canvas, center);
  }

  void _drawNebulaBackground(Canvas canvas, Size size, Offset center) {
    // Rotating gradient for dynamic background
    final gradient = RadialGradient(
      center: Alignment(
        sin(animationValue * 2 * pi) * 0.1,
        cos(animationValue * 2 * pi) * 0.1,
      ),
      radius: 1.8 + sin(animationValue * pi) * 0.1, // Pulsing radius
      colors: const [
        Color(0xFF0F1420), // Darker center
        Color(0xFF050812), // Deep space black
      ],
      stops: const [0.0, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawRadialGrid(Canvas canvas, Size size, Offset center) {
    // Faint grid lines
    final gridPaint = Paint()
      ..color = gridColor
          .withValues(alpha: 0.08) // More subtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw concentric circles with slight pulsing opacity
    for (int i = 1; i <= 8; i++) {
      final radius = i * 120.0;
      final opacity =
          (0.1 - (i * 0.01)) * (0.8 + 0.2 * sin(animationValue * 4 * pi));
      gridPaint.color = gridColor.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, gridPaint);
    }

    // Draw radial lines
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi;
      final endX = center.dx + cos(angle) * 1500;
      final endY = center.dy + sin(angle) * 1500;
      canvas.drawLine(center, Offset(endX, endY), gridPaint);
    }
  }

  void _drawConnections(Canvas canvas, List<Offset> nodes, Offset center) {
    final connectionPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Connect nodes that are close to each other
    // This is valid for clustered layout
    // Optimized: Only check against next few nodes to simulate immediate neighbors
    final adjustedNodes = nodes;

    for (int i = 0; i < adjustedNodes.length; i++) {
      for (int j = i + 1; j < min(i + 5, adjustedNodes.length); j++) {
        final dist = (adjustedNodes[i] - adjustedNodes[j]).distance;
        if (dist < 300) {
          // Fade line based on distance
          final opacity = (1.0 - (dist / 300)) * 0.2;
          connectionPaint.color = gridColor.withValues(alpha: opacity);
          canvas.drawLine(adjustedNodes[i], adjustedNodes[j], connectionPaint);
        }
      }
    }
  }

  void _drawParticles(Canvas canvas, Size size, Offset center) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final random = Random(42); // Fixed seed

    for (int i = 0; i < 150; i++) {
      // Dynamic position based on animation value
      final speedFactor = random.nextDouble() * 50 + 20;
      final angleOffset =
          animationValue * 2 * pi * (random.nextBool() ? 1 : -1);

      final baseX = random.nextDouble() * size.width * 4 - size.width * 1.5;
      final baseY = random.nextDouble() * size.height * 4 - size.height * 1.5;

      final driftX = cos(angleOffset + random.nextDouble()) * speedFactor;
      final driftY = sin(angleOffset + random.nextDouble()) * speedFactor;

      final x = baseX + driftX;
      final y = baseY + driftY;

      final adjustedPos = Offset(x, y);

      // Only draw if within extended view
      if (adjustedPos.dx > -size.width &&
          adjustedPos.dx < size.width * 2 &&
          adjustedPos.dy > -size.height &&
          adjustedPos.dy < size.height * 2) {
        final sizeFactor = random.nextDouble();
        final alpha = (0.3 + 0.3 * sin(animationValue * 3 * pi + i)).clamp(
          0.0,
          1.0,
        );

        particlePaint.color = starColor.withValues(alpha: alpha * 0.6);
        canvas.drawCircle(adjustedPos, sizeFactor * 2, particlePaint);
      }
    }
  }

  void _drawCenterRipple(Canvas canvas, Offset center) {
    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final adjustedCenter = center;

    // Draw 3 staggered ripples
    for (int i = 0; i < 3; i++) {
      final stagger = i * 0.33;
      final progress = (animationValue + stagger) % 1.0;
      final radius = 50 + (progress * 150);
      final opacity = (1.0 - progress) * 0.3; // Fade out as it expands

      ripplePaint.color = gridColor.withValues(alpha: opacity);
      canvas.drawCircle(adjustedCenter, radius, ripplePaint);
    }
  }

  void _drawCenterMarker(Canvas canvas, Offset center) {
    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final adjustedCenter = center;

    // Draw simple crosshair
    const crosshairSize = 10.0;
    canvas.drawLine(
      adjustedCenter - const Offset(crosshairSize, 0),
      adjustedCenter + const Offset(crosshairSize, 0),
      markerPaint,
    );
    canvas.drawLine(
      adjustedCenter - const Offset(0, crosshairSize),
      adjustedCenter + const Offset(0, crosshairSize),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(PulseBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
