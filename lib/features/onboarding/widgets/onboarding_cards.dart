import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import 'glass_card.dart';

class TimeCapsuleCard extends StatelessWidget {
  const TimeCapsuleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: MediaQuery.of(context).size.width * 0.78,
      height: 220,
      borderRadius: 28,
      blur: 20,
      border: Border.all(color: OasisColors.sage.withOpacity(0.3)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: OasisColors.glow, size: 18),
              const SizedBox(width: 8),
              Text(
                'Time Capsule',
                style: OasisTextStyles.onboardingSubtitle.copyWith(
                  color: OasisColors.sand,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: OasisColors.sage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Locked',
                  style: TextStyle(color: OasisColors.glow, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: OasisColors.sage.withOpacity(0.3), height: 1),
          const Spacer(),
          Text(
            'Trip to Kyoto 🌸',
            style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Opens in 47 days',
            style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 13),
          ),
          const Spacer(),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: OasisColors.sage.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 4,
                width: MediaQuery.of(context).size.width * 0.78 * 0.62,
                decoration: BoxDecoration(
                  color: OasisColors.glow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ).animate().scaleX(
                    begin: 0,
                    duration: 1400.ms,
                    delay: 600.ms,
                    curve: Curves.easeOut,
                    alignment: Alignment.centerLeft,
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 28,
                child: Stack(
                  children: List.generate(3, (index) {
                    return Positioned(
                      left: index * 16.0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: OasisColors.moss,
                          shape: BoxShape.circle,
                          border: Border.all(color: OasisColors.sage, width: 1),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'From your Circle',
                style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CanvasMockup extends StatelessWidget {
  const CanvasMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.88,
      height: 260,
      decoration: BoxDecoration(
        color: OasisColors.deep,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OasisColors.sage.withOpacity(0.25)),
      ),
      child: Stack(
        children: [
          // Dot Grid
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _DotGridPainter(),
          ),
          
          // Item A — Photo block (top-left)
          Positioned(
            top: 20,
            left: 20,
            child: _CanvasItem(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, color: OasisColors.glow, size: 24),
                  Text('Kyoto Trip', style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 9)),
                ],
              ),
            ).animate().scale(begin: const Offset(0.8, 0.8), delay: 300.ms).fadeIn(delay: 300.ms),
          ),

          // Item B — Text sticky (center-right)
          Positioned(
            top: 100,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: OasisColors.sand.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OasisColors.sand.withOpacity(0.2)),
              ),
              child: Text(
                'remember this ✨',
                style: OasisTextStyles.onboardingHeadline.copyWith(
                  fontSize: 11,
                  color: OasisColors.sand,
                ),
              ),
            ).animate().slideX(begin: 0.1, delay: 500.ms).fadeIn(delay: 500.ms),
          ),

          // Item C — Voice note (bottom-left)
          Positioned(
            bottom: 30,
            left: 20,
            child: Row(
              children: [
                const Icon(Icons.mic_none, color: OasisColors.glow, size: 14),
                const SizedBox(width: 4),
                // Using placeholder for WaveformBars here
                const Text('|||||', style: TextStyle(color: OasisColors.glow, letterSpacing: 1)),
                const SizedBox(width: 4),
                Text('0:32', style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 11)),
              ],
            ).animate().fadeIn(delay: 700.ms),
          ),
          
          // Item E — Milestone badge (bottom-center)
          Positioned(
            bottom: 20,
            left: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: OasisColors.sand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🎉 1 Year Together',
                style: TextStyle(color: OasisColors.deep, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ).animate().scale(begin: Offset.zero, delay: 1100.ms, curve: Curves.elasticOut),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = OasisColors.sage.withOpacity(0.18);
    const spacing = 22.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.5, paint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CanvasItem extends StatelessWidget {
  final Widget child;
  const _CanvasItem({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: OasisColors.moss,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OasisColors.sage.withOpacity(0.4)),
      ),
      child: child,
    );
  }
}
