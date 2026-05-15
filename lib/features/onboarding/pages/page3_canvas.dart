import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import '../widgets/onboarding_cards.dart';

class Page3Canvas extends StatelessWidget {
  final bool isActive;
  const Page3Canvas({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Text(
            'OASIS CANVAS',
            style: OasisTextStyles.onboardingSubtitle.copyWith(
              fontSize: 11,
              color: OasisColors.glow,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
            ),
          ).animate(target: isActive ? 1 : 0).fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 10),
          Text(
                'Your shared world,\nalive and infinite.',
                textAlign: TextAlign.center,
                style: OasisTextStyles.onboardingHeadline.copyWith(
                  fontSize: 36,
                  height: 1.2,
                ),
              )
              .animate(target: isActive ? 1 : 0)
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.06),
          const SizedBox(height: 18),
          const CanvasMockup()
              .animate(target: isActive ? 1 : 0)
              .scale(
                duration: 800.ms,
                delay: 200.ms,
                begin: const Offset(0.92, 0.92),
              )
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 20),
          Text(
            'A living mural of your relationships. Place anything, anywhere.\nScrub back through time and watch your story unfold.',
            textAlign: TextAlign.center,
            style: OasisTextStyles.onboardingSubtitle.copyWith(
              fontSize: 15,
              height: 1.65,
            ),
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 700.ms),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FeatureIcon(
                    icon: Icons.grid_view_outlined,
                    label: 'Infinite Space',
                  )
                  .animate(target: isActive ? 1 : 0)
                  .fadeIn(delay: 800.ms)
                  .slideY(begin: 0.1),
              _FeatureIcon(icon: Icons.history, label: 'Timeline Scrub')
                  .animate(target: isActive ? 1 : 0)
                  .fadeIn(delay: 950.ms)
                  .slideY(begin: 0.1),
              _FeatureIcon(icon: Icons.group_outlined, label: 'Shared Circles')
                  .animate(target: isActive ? 1 : 0)
                  .fadeIn(delay: 1100.ms)
                  .slideY(begin: 0.1),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: OasisColors.glow, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
