import 'dart:math';
import 'package:flutter/material.dart';

enum RecognizedShapeType { circle, rectangle, triangle, line, unknown }

class RecognizedShape {
  final RecognizedShapeType type;
  final Rect bounds;
  final List<Offset> points;

  RecognizedShape({
    required this.type,
    required this.bounds,
    required this.points,
  });
}

class ShapeRecognizer {
  static RecognizedShape recognize(List<Offset> points) {
    if (points.length < 10)
      return RecognizedShape(
        type: RecognizedShapeType.unknown,
        bounds: Rect.zero,
        points: [],
      );

    double minX = points[0].dx;
    double maxX = points[0].dx;
    double minY = points[0].dy;
    double maxY = points[0].dy;

    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    final center = bounds.center;
    final width = bounds.width;
    final height = bounds.height;

    // Check for line
    final startPoint = points.first;
    final endPoint = points.last;
    final distStartEnd = (startPoint - endPoint).distance;
    double totalDist = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDist += (points[i] - points[i + 1]).distance;
    }

    if (distStartEnd > totalDist * 0.8) {
      return RecognizedShape(
        type: RecognizedShapeType.line,
        bounds: bounds,
        points: [startPoint, endPoint],
      );
    }

    // Check for circle
    double avgDistFromCenter = 0;
    for (var p in points) {
      avgDistFromCenter += (p - center).distance;
    }
    avgDistFromCenter /= points.length;

    double variance = 0;
    for (var p in points) {
      variance += pow((p - center).distance - avgDistFromCenter, 2);
    }
    variance /= points.length;

    if (sqrt(variance) < avgDistFromCenter * 0.15) {
      return RecognizedShape(
        type: RecognizedShapeType.circle,
        bounds: bounds,
        points: [],
      );
    }

    // Check for rectangle (simplified: checking if points are near corners)
    // For a more robust solution, we'd use something like the $1 recognizer, but this is a start.
    if (width > 20 && height > 20) {
      // Check if it's more like a triangle or rectangle
      // This is a very basic heuristic
      if (distStartEnd < totalDist * 0.2) {
        // closed shape
        // If aspect ratio is close to 1 and points are roughly distributed
        return RecognizedShape(
          type: RecognizedShapeType.rectangle,
          bounds: bounds,
          points: [],
        );
      }
    }

    return RecognizedShape(
      type: RecognizedShapeType.unknown,
      bounds: bounds,
      points: [],
    );
  }
}
