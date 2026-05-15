import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oasis/models/pulse_node_position.dart';

/// Utility class for positioning nodes in the Pulse Map
/// Handles polar to Cartesian conversion and spatial calculations
class MapPositioner {
  /// Convert polar coordinates (distance, angle) to Cartesian offset
  static Offset polarToCartesian(double distance, double angle) {
    return Offset(distance * cos(angle), distance * sin(angle));
  }

  /// Convert Cartesian offset to polar coordinates
  static ({double distance, double angle}) cartesianToPolar(Offset offset) {
    final distance = sqrt(offset.dx * offset.dx + offset.dy * offset.dy);
    final angle = atan2(offset.dy, offset.dx);
    return (distance: distance, angle: angle);
  }

  /// Calculate distance between two offsets
  static double distanceBetween(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    return sqrt(dx * dx + dy * dy);
  }

  /// Check if a point is within the viewport bounds
  static bool isInViewport(
    Offset position,
    Size viewportSize, {
    Offset cameraOffset = Offset.zero,
    double scale = 1.0,
  }) {
    final adjustedPosition = (position * scale) + cameraOffset;
    return adjustedPosition.dx >= -viewportSize.width / 2 &&
        adjustedPosition.dx <= viewportSize.width * 1.5 &&
        adjustedPosition.dy >= -viewportSize.height / 2 &&
        adjustedPosition.dy <= viewportSize.height * 1.5;
  }

  /// Calculate viewport diagonal (for Deep Space threshold)
  static double viewportDiagonal(Size viewportSize) {
    return sqrt(
      viewportSize.width * viewportSize.width +
          viewportSize.height * viewportSize.height,
    );
  }

  /// Generate positions for a list of items using clustered algorithm
  static List<PulseNodePosition> generateClusteredPositions({
    required int count,
    required List<DateTime> timestamps,
    int clusterSize = 8,
    double clusterRadius = 120.0,
    double clusterSpacing = 250.0,
  }) {
    final positions = <PulseNodePosition>[];
    for (int i = 0; i < count; i++) {
      positions.add(
        PulseNodePosition.generateClusteredPosition(
          index: i,
          postTimestamp: timestamps[i],
          clusterSize: clusterSize,
          clusterRadius: clusterRadius,
          clusterSpacing: clusterSpacing,
        ),
      );
    }
    return positions;
  }

  /// Generate positions using Fibonacci spiral
  static List<PulseNodePosition> generateFibonacciPositions({
    required int count,
    required List<DateTime> timestamps,
    double baseDistance = 150.0,
    double distanceIncrement = 80.0,
  }) {
    final positions = <PulseNodePosition>[];
    for (int i = 0; i < count; i++) {
      positions.add(
        PulseNodePosition.generateFibonacciPosition(
          index: i,
          postTimestamp: timestamps[i],
          baseDistance: baseDistance,
          distanceIncrement: distanceIncrement,
        ),
      );
    }
    return positions;
  }

  /// Calculate camera offset to center on a specific position
  static Offset calculateCenterOffset(
    Offset targetPosition,
    Size viewportSize,
  ) {
    return Offset(
      targetPosition.dx - viewportSize.width / 2,
      targetPosition.dy - viewportSize.height / 2,
    );
  }

  /// Smoothly interpolate between two offsets
  static Offset lerpOffset(Offset a, Offset b, double t) {
    return Offset.lerp(a, b, t)!;
  }
}
