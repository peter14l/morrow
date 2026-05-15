import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/energy_meter_service.dart';
import 'package:oasis/services/wellness_service.dart';

class GlobalWellnessWrapper extends StatelessWidget {
  final Widget child;

  const GlobalWellnessWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer2<EnergyMeterService, WellnessService>(
      builder: (context, energyMeter, wellness, child) {
        final isLowEnergy = energyMeter.state.isLowEnergy;
        final isWindDownActive = wellness.isWindDownActive;
        final dimLevel = wellness.windDownDimLevel;

        Widget current = child!;

        // Apply Greyscale if energy is low (Anti-Dopamine)
        if (isLowEnergy) {
          current = ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: current,
          );
        }

        // Apply Wind-down Dimming
        if (isWindDownActive && dimLevel > 0) {
          current = Stack(
            children: [
              current,
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: dimLevel),
                  ),
                ),
              ),
            ],
          );
        }

        return current;
      },
      child: child,
    );
  }
}
