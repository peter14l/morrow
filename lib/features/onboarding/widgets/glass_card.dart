import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/oasis_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.blur = 16,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: OasisColors.moss.withOpacity(0.35),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: OasisColors.sage.withOpacity(0.4),
                  width: 1,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
