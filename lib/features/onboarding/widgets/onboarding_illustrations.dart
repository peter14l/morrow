import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';

class EnergyMeter extends StatefulWidget {
  const EnergyMeter({super.key});

  @override
  State<EnergyMeter> createState() => _EnergyMeterState();
}

class _EnergyMeterState extends State<EnergyMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _animation = Tween<double>(begin: 0, end: 73).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: _EnergyArcPainter(
                      sweepAngle: (_animation.value / 100) * 360,
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Text(
                        '${_animation.value.toInt()}',
                        style: OasisTextStyles.onboardingHeadline.copyWith(
                          fontSize: 48,
                        ),
                      );
                    },
                  ),
                  Text(
                    'ENERGY',
                    style: OasisTextStyles.onboardingSubtitle.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your focus, beautifully tracked.',
          style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

class _EnergyArcPainter extends CustomPainter {
  final double sweepAngle;

  _EnergyArcPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = OasisColors.sage.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = OasisColors.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, bgPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle * (math.pi / 180),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _EnergyArcPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle;
}

class WaveformBars extends StatefulWidget {
  const WaveformBars({super.key});

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(5, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + index * 100),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              width: 3,
              height: 8 + (_controllers[index].value * 12),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: OasisColors.glow,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}
