import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import '../widgets/oasis_logo_mark.dart';

class Page5CTA extends StatelessWidget {
  final bool isActive;
  final VoidCallback onComplete;
  final VoidCallback onSignIn;

  const Page5CTA({
    super.key,
    required this.isActive,
    required this.onComplete,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const OasisLogoMark(size: 72, showRotatingRing: true)
            .animate(target: isActive ? 1 : 0)
            .scale(begin: Offset.zero, curve: Curves.elasticOut)
            .fadeIn(),
        const SizedBox(height: 20),
        Text(
              "You're home.",
              style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 52),
            )
            .animate(target: isActive ? 1 : 0)
            .fadeIn(delay: 300.ms)
            .slideY(begin: 0.08),
        const SizedBox(height: 12),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.75,
          child: Text(
            'No noise. No performance. Just you and the people who matter.',
            textAlign: TextAlign.center,
            style: OasisTextStyles.onboardingSubtitle.copyWith(
              fontSize: 16,
              height: 1.65,
            ),
          ),
        ).animate(target: isActive ? 1 : 0).fadeIn(delay: 500.ms),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              _PrimaryButton(
                    onTap: onComplete,
                    label: 'Create Your Oasis',
                    icon: Icons.auto_awesome,
                  )
                  .animate(target: isActive ? 1 : 0)
                  .scale(delay: 700.ms, curve: Curves.elasticOut)
                  .fadeIn(delay: 700.ms),
              const SizedBox(height: 12),
              _SecondaryButton(
                onTap: onSignIn,
                label: 'Sign In',
              ).animate(target: isActive ? 1 : 0).fadeIn(delay: 900.ms),
              const SizedBox(height: 14),
              Text.rich(
                const TextSpan(
                  text: 'By continuing, you agree to our ',
                  children: [
                    TextSpan(
                      text: 'Privacy Promise',
                      style: TextStyle(
                        color: OasisColors.glow,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
                style: OasisTextStyles.onboardingSubtitle.copyWith(
                  fontSize: 11,
                  color: OasisColors.mist.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ).animate(target: isActive ? 1 : 0).fadeIn(delay: 1100.ms),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            color: OasisColors.glow,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: OasisColors.glow.withOpacity(0.45),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: OasisColors.deep, size: 18),
              const SizedBox(width: 8),
              Text(widget.label, style: OasisTextStyles.ctaLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _SecondaryButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OasisColors.sage.withOpacity(0.5)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: OasisTextStyles.onboardingSubtitle.copyWith(
            color: OasisColors.mist,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
