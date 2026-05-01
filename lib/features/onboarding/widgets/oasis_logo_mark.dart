import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/oasis_colors.dart';

class OasisLogoMark extends StatefulWidget {
  final double size;
  final bool showRotatingRing;

  const OasisLogoMark({
    super.key,
    this.size = 88,
    this.showRotatingRing = false,
  });

  @override
  State<OasisLogoMark> createState() => _OasisLogoMarkState();
}

class _OasisLogoMarkState extends State<OasisLogoMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showRotatingRing)
            _RotatingRing(size: widget.size * 1.4)
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 12.seconds),
          
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.04).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _OasisLogoPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RotatingRing extends StatelessWidget {
  final double size;
  const _RotatingRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RingPainter(),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OasisColors.glow.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double dashWidth = 4;
    const double dashSpace = 8;
    double currentAngle = 0;
    final double radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    while (currentAngle < 2 * math.pi) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        dashWidth / radius,
        false,
        paint,
      );
      currentAngle += (dashWidth + dashSpace) / radius;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OasisLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = OasisColors.glow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Inner "droplet/ring"
    final path = Path();
    path.moveTo(center.dx, center.dy - radius * 0.8);
    path.quadraticBezierTo(
      center.dx + radius * 0.7,
      center.dy - radius * 0.1,
      center.dx,
      center.dy + radius * 0.8,
    );
    path.quadraticBezierTo(
      center.dx - radius * 0.7,
      center.dy - radius * 0.1,
      center.dx,
      center.dy - radius * 0.8,
    );
    
    // Draw outer glow ring
    canvas.drawCircle(center, radius * 0.9, paint..strokeWidth = 1..color = OasisColors.glow.withOpacity(0.5));
    
    // Draw main logo
    canvas.drawPath(path, paint..strokeWidth = 3..color = OasisColors.glow);
    
    // Inner small circle
    canvas.drawCircle(center, radius * 0.15, Paint()..color = OasisColors.glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
