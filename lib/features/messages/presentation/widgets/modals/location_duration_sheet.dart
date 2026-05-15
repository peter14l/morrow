import 'package:flutter/material.dart';

class LocationDurationSheet extends StatelessWidget {
  const LocationDurationSheet({super.key, required this.onDurationSelected});

  final Function(Duration) onDurationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha((255 * 0.85).toInt()),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.onSurface.withAlpha((255 * 0.1).toInt()),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.2).toInt()),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Share Live Location',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.onSurface.withAlpha(
                          (255 * 0.05).toInt(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _buildDurationOption(
                      context,
                      '30 minutes',
                      const Duration(minutes: 30),
                    ),
                    const SizedBox(height: 8),
                    _buildDurationOption(
                      context,
                      '1 hour',
                      const Duration(hours: 1),
                    ),
                    const SizedBox(height: 8),
                    _buildDurationOption(
                      context,
                      '2 hours',
                      const Duration(hours: 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationOption(
    BuildContext context,
    String title,
    Duration duration,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onDurationSelected(duration);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceVariant.withAlpha(
            (255 * 0.5).toInt(),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
