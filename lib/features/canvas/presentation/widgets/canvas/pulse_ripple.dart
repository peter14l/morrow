import 'package:flutter/material.dart';

class PulseRipple extends StatefulWidget {
  final Offset position;
  final Color color;

  const PulseRipple({
    super.key,
    required this.position,
    this.color = Colors.white,
  });

  @override
  State<PulseRipple> createState() => _PulseRippleState();
}

class _PulseRippleState extends State<PulseRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _radiusAnimation = Tween<double>(
      begin: 0,
      end: 500,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.6), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.0), weight: 80),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        // We don't dispose here, the parent should remove this from the stack
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - _radiusAnimation.value,
          top: widget.position.dy - _radiusAnimation.value,
          child: Container(
            width: _radiusAnimation.value * 2,
            height: _radiusAnimation.value * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: _opacityAnimation.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(
                    alpha: _opacityAnimation.value * 0.5,
                  ),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension CurvesExt on Curves {
  static const Curve outQuietly = Cubic(0.19, 1, 0.22, 1);
}
