import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

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

    // Check liquid glass setting
    final settings = context.watch<UserSettingsProvider>();
    final liquidGlassMode = settings.liquidGlassMode;

    Widget fab;
    // Use liquid glass if enabled (real or fake)
    if (liquidGlassMode != LiquidGlassMode.disabled) {
      fab = _buildLiquidGlassFAB(context, liquidGlassMode);
    } else {
      // Fall back to original backdrop filter implementation
      fab = _buildBackdropFilterFAB(context);
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: fab);
    }

    return fab;
  }

  Widget _buildBackdropFilterFAB(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
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

  Widget _buildLiquidGlassFAB(BuildContext context, LiquidGlassMode mode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.3));

    if (mode == LiquidGlassMode.fake) {
      // Fake glass - backdrop filter
      return GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: opacity),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    // Real liquid glass - use LiquidGlass widget
    // Note: For best results, this should be inside a LiquidGlassLayer with background content
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          thickness: 10,
          blur: 5,
          glassColor: baseColor.withValues(alpha: 0.3),
          lightIntensity: 1.0,
          saturation: 1.0,
          refractiveIndex: 1.45,
          outlineIntensity: 1.0,
          lightAngle: -0.75,
        ),
        shape: LiquidRoundedSuperellipse(borderRadius: size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}
