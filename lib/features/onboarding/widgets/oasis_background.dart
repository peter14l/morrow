import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/theme/oasis_colors.dart';

class OasisBackground extends StatefulWidget {
  final Widget? child;
  const OasisBackground({super.key, this.child});

  @override
  State<OasisBackground> createState() => _OasisBackgroundState();
}

class _OasisBackgroundState extends State<OasisBackground>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late List<AnimationController> _particleControllers;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  double _gyroX = 0;
  double _gyroY = 0;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _particleControllers = List.generate(24, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(seconds: 4 + math.Random().nextInt(6)),
      )..repeat(reverse: true);
    });

    _initGyroscope();
  }

  void _initGyroscope() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
          setState(() {
            // Map rotation to offset, clamp to ±12px
            _gyroX = (_gyroX + event.y * 2).clamp(-12.0, 12.0);
            _gyroY = (_gyroY + event.x * 2).clamp(-12.0, 12.0);
          });
        });
      } catch (e) {
        debugPrint('Gyroscope not available: $e');
      }
    }
  }

  @override
  void dispose() {
    _driftController.dispose();
    for (var controller in _particleControllers) {
      controller.dispose();
    }
    _gyroscopeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0F14),
        body: widget.child ?? const SizedBox(),
      );
    }

    return Scaffold(
      backgroundColor: OasisColors.deep,
      body: Stack(
        children: [
          // Blobs
          AnimatedBuilder(
            animation: _driftController,
            builder: (context, child) {
              final drift = math.sin(_driftController.value * 2 * math.pi) * 18;
              return Stack(
                children: [
                  _Blob(
                    alignment: Alignment.topLeft,
                    color: OasisColors.glow.withOpacity(0.07),
                    radius: 320,
                    offsetX: drift + _gyroX,
                    offsetY: drift + _gyroY,
                  ),
                  _Blob(
                    alignment: Alignment.bottomRight,
                    color: OasisColors.sage.withOpacity(0.12),
                    radius: 280,
                    offsetX: -drift - _gyroX,
                    offsetY: -drift - _gyroY,
                  ),
                  _Blob(
                    alignment: const Alignment(0.8, 0.0),
                    color: OasisColors.moss.withOpacity(0.4),
                    radius: 200,
                    offsetX: drift * 0.5 + _gyroX * 0.5,
                    offsetY: -drift * 0.5 - _gyroY * 0.5,
                  ),
                ],
              );
            },
          ),

          // Particles (disabled on Web to prevent GPU/CPU lag)
          if (!kIsWeb)
            ...List.generate(24, (index) {
              final random = math.Random(index);
              final left = random.nextDouble() * 1.0;
              final top = random.nextDouble() * 1.0;
              return AnimatedBuilder(
                animation: _particleControllers[index],
                builder: (context, child) {
                  final ty =
                      math.sin(_particleControllers[index].value * 2 * math.pi) *
                      30;
                  return Align(
                    alignment: Alignment(left * 2 - 1, top * 2 - 1),
                    child: Transform.translate(
                      offset: Offset(0, ty),
                      child: Container(
                        width: 2,
                        height: 2,
                        decoration: BoxDecoration(
                          color: OasisColors.glow.withOpacity(
                            0.15 + random.nextDouble() * 0.2,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double radius;
  final double offsetX;
  final double offsetY;

  const _Blob({
    required this.alignment,
    required this.color,
    required this.radius,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
          ),
        ),
      ),
    );
  }
}
