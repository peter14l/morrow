import 'package:flutter/material.dart';
import 'dart:ui';

class DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final BorderRadius? borderRadius;
  final Radius? radius;

  DottedBorderPainter({
    this.color = Colors.white,
    this.strokeWidth = 1.0,
    this.gap = 3.0,
    this.dash = 3.0,
    this.borderRadius,
    this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    if (borderRadius != null) {
      path.addRRect(
        borderRadius!.toRRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    } else if (radius != null) {
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          radius!,
        ),
      );
    } else {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    final Path dashPath = Path();
    double distance = 0.0;

    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.radius != radius;
  }
}

class DottedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final BorderRadius? borderRadius;
  final Radius? radius;
  final EdgeInsets padding;

  const DottedBorder({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.strokeWidth = 1.0,
    this.gap = 3.0,
    this.dash = 3.0,
    this.borderRadius,
    this.radius,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DottedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        gap: gap,
        dash: dash,
        borderRadius: borderRadius,
        radius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
