import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

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
    UserSettingsProvider? settings;
    try {
      settings = context.watch<UserSettingsProvider>();
    } catch (_) {}

    final liquidGlassMode = settings?.liquidGlassMode ?? LiquidGlassMode.real;
    final isSolid = ContextX(context).shouldUseSolidBackground;

    Widget fab;
    if (liquidGlassMode == LiquidGlassMode.disabled || isSolid) {
      fab = _buildSolidFAB(context);
    } else if (liquidGlassMode == LiquidGlassMode.fake) {
      fab = _buildBackdropFilterFAB(context);
    } else {
      fab = _buildLiquidGlassFAB(context);
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: fab);
    }

    return fab;
  }

  Widget _buildSolidFAB(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: baseColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildBackdropFilterFAB(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.3));

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
                width: 1.2,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidGlassFAB(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.35));

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: AdaptiveGlass(
          useOwnLayer: true,
          shape: const LiquidOval(),
          settings: LiquidGlassSettings(
            thickness: 12,
            blur: blur > 0 ? blur : 8,
            glassColor: baseColor.withValues(alpha: opacity),
            lightIntensity: 1.2,
            saturation: 1.1,
            refractiveIndex: 1.45,
            lightAngle: -0.75,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
