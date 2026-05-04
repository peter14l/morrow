import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:oasis/themes/app_colors.dart';

class GlassmorphicFAB extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double size;
  final double blur;
  final double opacity;
  final Color? color;
  final String? tooltip;

  const GlassmorphicFAB({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 48,
    this.blur = 10,
    this.opacity = 0.4,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: opacity),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
