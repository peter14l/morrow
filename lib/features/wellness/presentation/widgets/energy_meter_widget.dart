import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/models/energy_meter_state.dart';
import 'package:oasis/services/energy_meter_service.dart';

/// Persistent overlay widget displaying user's interaction energy
/// Shows as a subtle, dynamic circular indicator
class EnergyMeterWidget extends StatefulWidget {
  final Widget child;
  final bool showLabel;

  const EnergyMeterWidget({
    super.key,
    required this.child,
    this.showLabel = false,
  });

  @override
  State<EnergyMeterWidget> createState() => _EnergyMeterWidgetState();
}

class _EnergyMeterWidgetState extends State<EnergyMeterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnergyMeterService>(
      builder: (context, energyMeterService, child) {
        final energyMeter = energyMeterService.state;
        final isLowEnergy = energyMeter.isLowEnergy;

        return Stack(
          children: [
            if (isLowEnergy)
              ColorFiltered(
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
                child: widget.child,
              )
            else
              widget.child,

            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: ScaleTransition(
                scale: isLowEnergy
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: _buildEnergyIndicator(energyMeter),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _buildEnergyIndicator(EnergyMeterState energyMeter) {
    final theme = Theme.of(context);
    final percentage = energyMeter.energyPercentage;
    final color = energyMeter.energyColor;
    final currentEnergy = energyMeter.currentEnergy;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(child: Icon(Icons.bolt, size: 16, color: color)),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 8),
            Text(
              '${currentEnergy.toInt()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
