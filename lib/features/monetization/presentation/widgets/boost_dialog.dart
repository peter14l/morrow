import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import '../../data/services/customization_service.dart';

/// Circle Boost dialog widget.
///
/// Lets a user spend one of their boost tokens to boost a Circle.
/// Boosting a circle unlocks perks for all members as boosts accumulate.
class BoostDialog extends StatefulWidget {
  final String circleId;
  final String circleName;

  const BoostDialog({
    super.key,
    required this.circleId,
    required this.circleName,
  });

  /// Shows the boost dialog as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String circleId,
    required String circleName,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BoostDialog(
        circleId: circleId,
        circleName: circleName,
      ),
    );
  }

  @override
  State<BoostDialog> createState() => _BoostDialogState();
}

class _BoostDialogState extends State<BoostDialog> {
  bool _isBoosting = false;

  // Boost tiers and what they unlock
  static const List<Map<String, dynamic>> _boostTiers = [
    {
      'boosts': 3,
      'label': 'Level 1',
      'perk': 'Custom Circle banner & description badge',
      'icon': Icons.looks_one_outlined,
    },
    {
      'boosts': 7,
      'label': 'Level 2',
      'perk': 'High-fidelity audio in Circle Spaces',
      'icon': Icons.looks_two_outlined,
    },
    {
      'boosts': 15,
      'label': 'Level 3',
      'perk': 'Exclusive animated Circle theme for all members',
      'icon': Icons.looks_3_outlined,
    },
  ];

  Future<void> _applyBoost() async {
    setState(() => _isBoosting = true);
    try {
      final service = context.read<CustomizationService>();
      final success = await service.purchaseCircleBoosts(1);
      if (!mounted) return;
      if (success) {
        CustomSnackbar.showSuccess(
          context,
          '🚀 You boosted ${widget.circleName}!',
        );
        Navigator.pop(context);
      } else {
        CustomSnackbar.showError(
          context,
          'Not enough boost tokens. Visit the Shop to buy more!',
        );
      }
    } finally {
      if (mounted) setState(() => _isBoosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Rocket icon & title
          Icon(
            FluentIcons.rocket_24_filled,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Boost ${widget.circleName}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your boost helps unlock perks for everyone in this Circle.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Boost tiers
          ..._boostTiers.map((tier) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      tier['icon'] as IconData,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tier['label']} · ${tier['boosts']} boosts',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            tier['perk'] as String,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 24),

          // Boost button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBoosting ? null : _applyBoost,
              icon: _isBoosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(FluentIcons.rocket_20_regular),
              label: Text(_isBoosting ? 'Boosting...' : 'Boost this Circle'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
