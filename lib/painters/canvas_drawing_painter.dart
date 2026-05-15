import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class DrawingPoint {
  final Offset point;
  final Paint paint;

  DrawingPoint({required this.point, required this.paint});
}

class CanvasDrawingPainter extends CustomPainter {
  final List<DrawingPoint?> pointsList;

  CanvasDrawingPainter({required this.pointsList});

  @override
  void paint(Canvas canvas, Size size) {
    if (pointsList.isEmpty) return;

    final path = Path();
    Paint? currentPaint;

    for (int i = 0; i < pointsList.length; i++) {
      final point = pointsList[i];

      if (point == null) {
        if (currentPaint != null) {
          canvas.drawPath(path, currentPaint);
          path.reset();
        }
        continue;
      }

      // Ensure we have a paint style for the current segment
      if (currentPaint == null) {
        currentPaint = Paint()
          ..color = point.paint.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = point.paint.strokeWidth
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
      }

      if (path.getBounds().isEmpty) {
        path.moveTo(point.point.dx, point.point.dy);
      } else {
        // Use quadratic bezier for smoother transitions if possible,
        // but drawLine within a Path with Round join/cap is already much smoother
        path.lineTo(point.point.dx, point.point.dy);
      }
    }

    // Draw the final path if it wasn't closed by a null
    if (!path.getBounds().isEmpty && currentPaint != null) {
      canvas.drawPath(path, currentPaint);
    }
  }

  @override
  bool shouldRepaint(CanvasDrawingPainter oldDelegate) => true;
}
