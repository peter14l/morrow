import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'package:oasis/features/canvas/domain/models/canvas_models.dart';

class ScatteredPolaroidSpread extends StatefulWidget {
  final List<CanvasItemEntity> items;
  const ScatteredPolaroidSpread({super.key, required this.items});

  @override
  State<ScatteredPolaroidSpread> createState() =>
      _ScatteredPolaroidSpreadState();
}

class _ScatteredPolaroidSpreadState extends State<ScatteredPolaroidSpread>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExpanded = false;
  final List<double> _rotations = [];
  final List<Offset> _offsets = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final random = math.Random(widget.items.first.id.hashCode);
    for (int i = 0; i < widget.items.length; i++) {
      _rotations.add((random.nextDouble() - 0.5) * 0.4); // Random rotation
      _offsets.add(
        Offset(
          (random.nextDouble() - 0.5) * 30, // Random X offset
          (random.nextDouble() - 0.5) * 30, // Random Y offset
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SizedBox(
            height: 350,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children:
                  List.generate(widget.items.length, (index) {
                        final item = widget.items[index];

                        // Fan out logic
                        double fanRotation = 0;
                        Offset fanOffset = Offset.zero;

                        if (widget.items.length > 1) {
                          const double fanRange = 0.8; // Total arc
                          final double step =
                              fanRange / (widget.items.length - 1);
                          fanRotation = -fanRange / 2 + (index * step);
                          fanOffset = Offset(
                            math.sin(fanRotation) * 120,
                            -math.cos(fanRotation) * 40 + 40,
                          );
                        }

                        final currentRotation = uiLerp(
                          _rotations[index],
                          fanRotation,
                          _controller.value,
                        );
                        final currentOffset = Offset(
                          uiLerp(
                            _offsets[index].dx,
                            fanOffset.dx,
                            _controller.value,
                          ),
                          uiLerp(
                            _offsets[index].dy,
                            fanOffset.dy,
                            _controller.value,
                          ),
                        );

                        return Transform.translate(
                          offset: currentOffset,
                          child: Transform.rotate(
                            angle: currentRotation,
                            child: _PolaroidFrame(imageUrl: item.content),
                          ),
                        );
                      }).reversed
                      .toList(), // Reverse so first item is on top when collapsed
            ),
          );
        },
      ),
    );
  }

  double uiLerp(double a, double b, double t) => a + (b - a) * t;
}

class _PolaroidFrame extends StatelessWidget {
  final String imageUrl;
  const _PolaroidFrame({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey[200],
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[300]),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
      ),
    );
  }
}
