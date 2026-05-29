import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

/// Configuration for the liquid glass effect
class LiquidGlassConfig {
  final double thickness;
  final double blur;
  final Color glassColor;
  final double lightIntensity;
  final double saturation;

  const LiquidGlassConfig({
    required this.thickness,
    required this.blur,
    required this.glassColor,
    this.lightIntensity = 1.0,
    this.saturation = 1.0,
  });

  static const Light = LiquidGlassConfig(
    thickness: 8,
    blur: 4,
    glassColor: Color(0x1AFFFFFF),
    lightIntensity: 0.8,
    saturation: 1.0,
  );

  static const Medium = LiquidGlassConfig(
    thickness: 12,
    blur: 8,
    glassColor: Color(0x33FFFFFF),
    lightIntensity: 1.0,
    saturation: 1.1,
  );

  static const Strong = LiquidGlassConfig(
    thickness: 20,
    blur: 12,
    glassColor: Color(0x4DFFFFFF),
    lightIntensity: 1.5,
    saturation: 1.2,
  );
}

/// A simplified renderer for liquid glass effect
class LiquidGlassRenderer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double thickness;
  final double blur;
  final Color glassColor;
  final double lightIntensity;
  final double saturation;

  const LiquidGlassRenderer({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.thickness,
    required this.blur,
    required this.glassColor,
    this.lightIntensity = 1.0,
    this.saturation = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass.withOwnLayer(
      shape: LiquidRoundedRectangle(
        borderRadius: borderRadius,
      ),
      settings: LiquidGlassSettings(
        thickness: thickness,
        blur: blur,
        glassColor: glassColor,
        lightIntensity: lightIntensity,
        saturation: saturation,
        refractiveIndex: 1.45,
        outlineIntensity: 1.0,
        lightAngle: -0.75,
      ),
      child: child,
    );
  }
}

/// Wrapper that provides liquid glass effect based on user settings
class LiquidGlassWrapper extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final LiquidGlassConfig config;

  const LiquidGlassWrapper({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.config = LiquidGlassConfig.Medium,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();
    final mode = settings.liquidGlassMode;
    final isSolid = ContextX(context).shouldUseSolidBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (mode == LiquidGlassMode.disabled || isSolid) {
      // No glass effect - return child with solid background if isSolid
      if (isSolid) {
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(borderRadius ?? 20),
          ),
          child: child,
        );
      }
      return child;
    }

    final bgColor =
        backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.3));

    if (mode == LiquidGlassMode.fake) {
      return _FakeGlassWrapper(
        borderRadius: borderRadius ?? 20,
        padding: padding,
        bgColor: bgColor,
        child: child,
      );
    }

    // Real liquid glass
    return _RealLiquidGlassWrapper(
      borderRadius: borderRadius ?? 20,
      padding: padding,
      bgColor: bgColor,
      config: config,
      child: child,
    );
  }
}

class _FakeGlassWrapper extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color bgColor;

  const _FakeGlassWrapper({
    required this.child,
    required this.borderRadius,
    this.padding,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

class _RealLiquidGlassWrapper extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color bgColor;
  final LiquidGlassConfig config;

  const _RealLiquidGlassWrapper({
    required this.child,
    required this.borderRadius,
    this.padding,
    required this.bgColor,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      child: LiquidGlassRenderer(
        borderRadius: borderRadius,
        thickness: config.thickness,
        blur: config.blur,
        glassColor: config.glassColor,
        lightIntensity: config.lightIntensity,
        saturation: config.saturation,
        child: child,
      ),
    );
  }
}

/// Extension to wrap any widget with liquid glass
extension LiquidGlassExtension on Widget {
  Widget withLiquidGlass({
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      padding: padding,
      backgroundColor: backgroundColor,
      config: config,
      child: this,
    );
  }
}

/// Extension to wrap Material FAB with liquid glass
extension LiquidGlassFAB on Widget {
  Widget asLiquidGlassFAB({
    double borderRadius = 100,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      config: config,
      child: this,
    );
  }
}

/// Extension to wrap Material Card with liquid glass
extension LiquidGlassCard on Widget {
  Widget asLiquidGlassCard({
    double borderRadius = 20,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      config: config,
      child: this,
    );
  }
}

/// Extension to wrap Material Dialog with liquid glass
extension LiquidGlassDialog on Widget {
  Widget asLiquidGlassDialog({
    double borderRadius = 28,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: LiquidGlassWrapper(
          borderRadius: borderRadius,
          config: config,
          child: Material(color: Colors.transparent, child: this),
        ),
      ),
    );
  }
}

/// Extension to wrap BottomSheet with liquid glass
extension LiquidGlassBottomSheet on Widget {
  Widget asLiquidGlassBottomSheet({
    double borderRadius = 24,
    LiquidGlassConfig config = LiquidGlassConfig.Light,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      config: config,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        child: this,
      ),
    );
  }
}
