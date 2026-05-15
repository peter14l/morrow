import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import '../widgets/oasis_logo_mark.dart';
import '../widgets/glass_card.dart';

class Page1Welcome extends StatelessWidget {
  final bool isActive;
  const Page1Welcome({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),
        const OasisLogoMark()
            .animate(target: isActive ? 1 : 0)
            .scale(
              duration: 900.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.6, 0.6),
            )
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 16),
        if (isActive)
          DefaultTextStyle(
            style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 52),
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'oasis',
                  speed: const Duration(milliseconds: 80),
                ),
              ],
              isRepeatingAnimation: false,
            ),
          )
        else
          Text(
            'oasis',
            style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 52),
          ),
        const SizedBox(height: 8),
        Text(
          'YOUR DIGITAL SANCTUARY.',
          style: OasisTextStyles.onboardingSubtitle.copyWith(
            fontSize: 15,
            letterSpacing: 1.8,
            fontWeight: FontWeight.bold,
          ),
        ).animate(target: isActive ? 1 : 0).fadeIn(delay: 1200.ms),
        const SizedBox(height: 48),
        GlassCard(
              width: MediaQuery.of(context).size.width * 0.82,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Text(
                'No algorithms. No data markets.\nJust the people and moments that matter.',
                textAlign: TextAlign.center,
                style: OasisTextStyles.onboardingSubtitle.copyWith(
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            )
            .animate(target: isActive ? 1 : 0)
            .slideY(begin: 0.15, delay: 1600.ms)
            .fadeIn(delay: 1600.ms),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down, color: OasisColors.glow, size: 22)
            .animate(onPlay: (c) => c.repeat())
            .moveY(
              begin: 0,
              end: 8,
              duration: 1.4.seconds,
              curve: Curves.easeInOut,
            ),
        Text(
          'Swipe to explore',
          style: OasisTextStyles.onboardingSubtitle.copyWith(
            fontSize: 12,
            color: OasisColors.mist.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}
