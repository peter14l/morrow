import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated heart burst effect for like interactions
class HeartBurstAnimation extends StatefulWidget {
  final bool isLiked;
  final Widget child;
  final VoidCallback? onTap;
  final double burstRadius;

  const HeartBurstAnimation({
    super.key,
    required this.isLiked,
    required this.child,
    this.onTap,
    this.burstRadius = 50.0,
  });

  @override
  State<HeartBurstAnimation> createState() => _HeartBurstAnimationState();
}

class _HeartBurstAnimationState extends State<HeartBurstAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;
  bool _showBurst = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _burstAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(HeartBurstAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked && !oldWidget.isLiked) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    setState(() => _showBurst = true);
    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _showBurst = false);
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
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (_showBurst)
                ...List.generate(8, (index) {
                  final angle = (index * math.pi / 4);
                  final distance = widget.burstRadius * _burstAnimation.value;
                  return Positioned(
                    left: math.cos(angle) * distance,
                    top: math.sin(angle) * distance,
                    child: Opacity(
                      opacity: 1 - _burstAnimation.value,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  );
                }),
              Transform.scale(
                scale: _scaleAnimation.value,
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ripple effect for profile avatar taps
class AvatarRippleAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;

  const AvatarRippleAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor = Colors.white,
  });

  @override
  State<AvatarRippleAnimation> createState() => _AvatarRippleAnimationState();
}

class _AvatarRippleAnimationState extends State<AvatarRippleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rippleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showRipple = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rippleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  void _triggerRipple() {
    setState(() => _showRipple = true);
    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _showRipple = false);
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
    return GestureDetector(
      onTap: () {
        _triggerRipple();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_showRipple)
                Transform.scale(
                  scale: _rippleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.rippleColor.withValues(
                          alpha: _opacityAnimation.value,
                        ),
                        width: 3,
                      ),
                    ),
                    child: Opacity(opacity: 0, child: widget.child),
                  ),
                ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

/// Smooth scale animation for tab transitions
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleValue;
  final Duration duration;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleValue = 0.95,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Upload progress ring animation
class UploadProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Widget? child;

  const UploadProgressRing({
    super.key,
    required this.progress,
    this.size = 60,
    this.strokeWidth = 4,
    this.backgroundColor = Colors.grey,
    this.progressColor = Colors.blue,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _ProgressRingPainter(
                  progress: value,
                  strokeWidth: strokeWidth,
                  backgroundColor: backgroundColor,
                  progressColor: progressColor,
                ),
              );
            },
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Shimmer loading effect wrapper
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gradientPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _gradientPosition = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    final theme = Theme.of(context);
    final baseColor =
        widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _gradientPosition,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                _gradientPosition.value - 0.3,
                _gradientPosition.value,
                _gradientPosition.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Bouncy scroll physics for a more playful feel
class BouncyScrollPhysics extends BouncingScrollPhysics {
  const BouncyScrollPhysics({super.parent});

  @override
  BouncyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BouncyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}
