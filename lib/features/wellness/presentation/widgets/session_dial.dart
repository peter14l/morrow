import 'dart:math';
import 'package:flutter/material.dart';
import 'package:oasis/themes/app_colors.dart';

class SessionDial extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String label;
  final String subLabel;

  const SessionDial({
    super.key,
    required this.progress,
    required this.label,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer decorative rings
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: OasisColors.sage.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),

          // Main Painter
          CustomPaint(
            size: const Size(160, 160),
            painter: DialPainter(
              progress: progress,
              color: OasisColors.glow,
              trackColor: OasisColors.moss,
            ),
          ),

          // Labels
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'Space Mono',
                  fontWeight: FontWeight.bold,
                  color: OasisColors.white,
                ),
              ),
              Text(
                subLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: OasisColors.mist,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  DialPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Halo Glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = OasisColors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2;

    for (var i = 0; i < 8; i++) {
      final angle = (i * pi / 4) - pi / 2;
      final start = Offset(
        center.dx + (radius - 15) * cos(angle),
        center.dy + (radius - 15) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 5) * cos(angle),
        center.dy + (radius - 5) * sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant DialPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
