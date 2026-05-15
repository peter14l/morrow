import 'package:flutter/material.dart';
import '../../../core/theme/oasis_colors.dart';

class FeaturePill extends StatelessWidget {
  final String label;
  const FeaturePill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: OasisColors.moss.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OasisColors.sage.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: OasisColors.sand,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class WellbeingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const WellbeingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OasisColors.moss.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OasisColors.sage.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: OasisColors.glow, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: OasisColors.sand,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: OasisColors.mist, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: OasisColors.glow,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
