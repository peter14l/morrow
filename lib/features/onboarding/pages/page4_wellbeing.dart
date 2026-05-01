import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import '../widgets/onboarding_illustrations.dart';
import '../widgets/feature_pills.dart';

class Page4Wellbeing extends StatelessWidget {
  final bool isActive;
  const Page4Wellbeing({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          'DIGITAL WELLBEING',
          style: OasisTextStyles.onboardingSubtitle.copyWith(
            fontSize: 11,
            color: OasisColors.glow,
            letterSpacing: 2.5,
            fontWeight: FontWeight.bold,
          ),
        ).animate(target: isActive ? 1 : 0).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 10),
        Text(
          'Your attention is\nprecious. We mean it.',
          textAlign: TextAlign.center,
          style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 36, height: 1.2),
        ).animate(target: isActive ? 1 : 0).fadeIn(delay: 200.ms).slideY(begin: 0.06),
        const SizedBox(height: 22),
        if (isActive) const EnergyMeter(),
        const SizedBox(height: 28),
        Column(
          children: [
            const WellbeingCard(
              icon: Icons.bolt_outlined,
              title: 'Energy Metering',
              subtitle: 'Visual gauge of your engagement',
            ),
            const SizedBox(height: 10),
            const WellbeingCard(
              icon: Icons.palette_outlined,
              title: 'Dopamine Detox',
              subtitle: 'Grayscale mode to reset your mind',
            ),
            const SizedBox(height: 10),
            const WellbeingCard(
              icon: Icons.school_outlined,
              title: 'Study Sessions',
              subtitle: 'Earn XP for focused deep work',
            ),
          ]
              .animate(target: isActive ? 1 : 0, interval: 180.ms, delay: 600.ms)
              .fadeIn()
              .slideX(begin: 0.12),
        ),
        const Spacer(),
        Text(
          'Rest is not a reward. It is a right.',
          style: OasisTextStyles.onboardingHeadline.copyWith(
            fontSize: 18,
            color: OasisColors.sand.withOpacity(0.55),
          ),
        ).animate(target: isActive ? 1 : 0).fadeIn(delay: 1400.ms),
        const SizedBox(height: 40),
      ],
    );
  }
}
