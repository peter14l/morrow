import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a post's position in the Pulse Map using polar coordinates
/// Positions are calculated based on post age and clustering algorithm
class PulseNodePosition {
  final double distance; // Distance from center (user node)
  final double angle; // Angle in radians
  final DateTime calculatedAt;

  const PulseNodePosition({
    required this.distance,
    required this.angle,
    required this.calculatedAt,
  });

  /// Convert polar coordinates to Cartesian offset
  Offset toCartesian() {
    return Offset(distance * cos(angle), distance * sin(angle));
  }

  /// Calculate dynamic distance based on time elapsed since post creation
  /// Older posts drift further away (gravity effect)
  static double calculateDynamicDistance({
    required double baseDistance,
    required DateTime postTimestamp,
    double driftRate = 0.5, // units per minute
  }) {
    final minutesElapsed = DateTime.now().difference(postTimestamp).inMinutes;
    return baseDistance + (minutesElapsed * driftRate);
  }

  /// Generate position using Fibonacci spiral for even distribution
  /// This creates a natural, organic clustering pattern
  static PulseNodePosition generateFibonacciPosition({
    required int index,
    required DateTime postTimestamp,
    double baseDistance = 150.0,
    double distanceIncrement = 80.0,
  }) {
    // Golden angle in radians (~137.5 degrees)
    final goldenAngle = pi * (3.0 - sqrt(5.0));

    // Calculate base position
    final angle = (index * goldenAngle) % (2 * pi);
    final spiralDistance =
        baseDistance + (sqrt(index.toDouble()) * distanceIncrement);

    // Apply time-based drift
    final dynamicDistance = calculateDynamicDistance(
      baseDistance: spiralDistance,
      postTimestamp: postTimestamp,
    );

    return PulseNodePosition(
      distance: dynamicDistance,
      angle: angle,
      calculatedAt: DateTime.now(),
    );
  }

  /// Generate clustered position (internet-based)
  /// Posts are grouped in clusters with some randomness
  static PulseNodePosition generateClusteredPosition({
    required int index,
    required DateTime postTimestamp,
    int clusterSize = 8,
    double clusterRadius = 120.0,
    double clusterSpacing = 250.0,
  }) {
    final clusterIndex = index ~/ clusterSize;
    final positionInCluster = index % clusterSize;

    // Cluster center position (hexagonal packing)
    final clusterAngle = (clusterIndex * (pi / 3)) % (2 * pi);
    final clusterDistance = clusterIndex == 0
        ? 0.0
        : clusterSpacing * sqrt(clusterIndex.toDouble());

    // Position within cluster (circular arrangement)
    final inClusterAngle =
        (positionInCluster * 2 * pi / clusterSize) +
        (Random(index).nextDouble() * 0.3); // Add slight randomness
    final inClusterDistance =
        clusterRadius * (0.5 + Random(index).nextDouble() * 0.5);

    // Combine cluster position with in-cluster offset
    final finalAngle = clusterAngle + (inClusterAngle * 0.3);
    final finalDistance = clusterDistance + inClusterDistance;

    // Apply time-based drift
    final dynamicDistance = calculateDynamicDistance(
      baseDistance: finalDistance,
      postTimestamp: postTimestamp,
      driftRate: 0.3, // Slower drift for clustered layout
    );

    return PulseNodePosition(
      distance: dynamicDistance,
      angle: finalAngle,
      calculatedAt: DateTime.now(),
    );
  }

  /// Check if position is in "Deep Space" (beyond viewport)
  bool isInDeepSpace(Size viewportSize) {
    final viewportDiagonal = sqrt(
      viewportSize.width * viewportSize.width +
          viewportSize.height * viewportSize.height,
    );
    return distance > viewportDiagonal * 2;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'angle': angle,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PulseNodePosition.fromJson(Map<String, dynamic> json) {
    return PulseNodePosition(
      distance: (json['distance'] as num).toDouble(),
      angle: (json['angle'] as num).toDouble(),
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'PulseNodePosition(distance: ${distance.toStringAsFixed(1)}, '
        'angle: ${(angle * 180 / pi).toStringAsFixed(1)}°)';
  }
}
