import 'package:flutter/material.dart';

/// Domain entity representing the user's interaction energy state
/// Energy depletes with interactions and recovers passively over time
class EnergyMeterEntity {
  final double currentEnergy;
  final DateTime lastInteraction;
  final int interactionsToday;
  final DateTime dayStart;

  // Constants for energy mechanics
  static const double maxEnergy = 100.0;
  static const double expansionCost = 15.0;
  static const double viewCost = 2.0;
  static const double likeCost = 1.0;
  static const double recoveryRate = 5.0;
  static const double lowEnergyThreshold = 10.0;

  const EnergyMeterEntity({
    required this.currentEnergy,
    required this.lastInteraction,
    required this.interactionsToday,
    required this.dayStart,
  });

  factory EnergyMeterEntity.initial() {
    final now = DateTime.now();
    return EnergyMeterEntity(
      currentEnergy: maxEnergy,
      lastInteraction: now,
      interactionsToday: 0,
      dayStart: DateTime(now.year, now.month, now.day),
    );
  }

  EnergyMeterEntity withRecovery() {
    final now = DateTime.now();
    final minutesElapsed = now.difference(lastInteraction).inMinutes;
    final recoveredEnergy = (currentEnergy + (minutesElapsed * recoveryRate))
        .clamp(0.0, maxEnergy);

    final isNewDay =
        now.day != dayStart.day ||
        now.month != dayStart.month ||
        now.year != dayStart.year;

    return EnergyMeterEntity(
      currentEnergy: recoveredEnergy,
      lastInteraction: lastInteraction,
      interactionsToday: isNewDay ? 0 : interactionsToday,
      dayStart: isNewDay ? DateTime(now.year, now.month, now.day) : dayStart,
    );
  }

  EnergyMeterEntity deductEnergy(double cost) {
    final now = DateTime.now();
    return EnergyMeterEntity(
      currentEnergy: (currentEnergy - cost).clamp(0.0, maxEnergy),
      lastInteraction: now,
      interactionsToday: interactionsToday + 1,
      dayStart: dayStart,
    );
  }

  bool get isLowEnergy => currentEnergy < lowEnergyThreshold;

  double get energyPercentage => currentEnergy / maxEnergy;

  Color get energyColor {
    if (currentEnergy >= 70) {
      return Colors.green;
    } else if (currentEnergy >= 40) {
      return Colors.yellow;
    } else if (currentEnergy >= lowEnergyThreshold) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'currentEnergy': currentEnergy,
      'lastInteraction': lastInteraction.toIso8601String(),
      'interactionsToday': interactionsToday,
      'dayStart': dayStart.toIso8601String(),
    };
  }

  factory EnergyMeterEntity.fromJson(Map<String, dynamic> json) {
    return EnergyMeterEntity(
      currentEnergy: (json['currentEnergy'] as num?)?.toDouble() ?? maxEnergy,
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'] as String)
          : DateTime.now(),
      interactionsToday: json['interactionsToday'] as int? ?? 0,
      dayStart: json['dayStart'] != null
          ? DateTime.parse(json['dayStart'] as String)
          : DateTime.now(),
    );
  }

  EnergyMeterEntity copyWith({
    double? currentEnergy,
    DateTime? lastInteraction,
    int? interactionsToday,
    DateTime? dayStart,
  }) {
    return EnergyMeterEntity(
      currentEnergy: currentEnergy ?? this.currentEnergy,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      interactionsToday: interactionsToday ?? this.interactionsToday,
      dayStart: dayStart ?? this.dayStart,
    );
  }

  @override
  String toString() {
    return 'EnergyMeterEntity(energy: ${currentEnergy.toStringAsFixed(1)}, '
        'interactions: $interactionsToday)';
  }
}

/// Interaction types that cost energy
enum InteractionType { expand, view, like, comment, share, bookmark }
