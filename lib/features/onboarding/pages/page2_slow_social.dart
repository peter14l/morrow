import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import '../widgets/onboarding_cards.dart';
import '../widgets/feature_pills.dart';

class Page2SlowSocial extends StatelessWidget {
  final bool isActive;
  const Page2SlowSocial({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Text(
            'A NEW WAY TO CONNECT',
            style: OasisTextStyles.onboardingSubtitle.copyWith(
              fontSize: 11,
              color: OasisColors.glow,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
            ),
          ).animate(target: isActive ? 1 : 0).fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 12),
          Text(
            'Meaningful moments\nare worth the wait.',
            textAlign: TextAlign.center,
            style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 36, height: 1.2),
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 200.ms).slideY(begin: 0.06),
          const SizedBox(height: 20),
          const TimeCapsuleCard()
              .animate(target: isActive ? 1 : 0)
              .scale(duration: 700.ms, delay: 400.ms, curve: Curves.easeOutBack, begin: const Offset(0.88, 0.88))
              .fadeIn(delay: 400.ms),
          const SizedBox(height: 24),
          Text(
            'Send memories, videos, and messages into the future.\nSet them free on the exact moment they matter most.',
            textAlign: TextAlign.center,
            style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 15, height: 1.65),
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 700.ms),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              const FeaturePill(label: '🕰 Time Capsules'),
              const FeaturePill(label: '🔒 Locked Content'),
              const FeaturePill(label: '✨ Unlock Dates'),
            ]
                .animate(target: isActive ? 1 : 0, interval: 120.ms, delay: 900.ms)
                .fadeIn()
                .slideY(begin: 0.1),
          ),
        ],
      ),
    );
  }
}
