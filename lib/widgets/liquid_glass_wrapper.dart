import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
export 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        LiquidShape,
        LiquidOval,
        LiquidRoundedSuperellipse,
        LiquidRoundedRectangle,
        LiquidGlassSettings,
        GlassQuality;
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
  final double refractiveIndex;
  final double lightAngle;
  final double chromaticAberration;

  const LiquidGlassConfig({
    required this.thickness,
    required this.blur,
    required this.glassColor,
    this.lightIntensity = 1.0,
    this.saturation = 1.0,
    this.refractiveIndex = 1.45,
    this.lightAngle = -0.75,
    this.chromaticAberration = 0.01,
  });

  LiquidGlassSettings toSettings() {
    return LiquidGlassSettings(
      thickness: thickness,
      blur: blur,
      glassColor: glassColor,
      lightIntensity: lightIntensity,
      saturation: saturation,
      refractiveIndex: refractiveIndex,
      lightAngle: lightAngle,
      chromaticAberration: chromaticAberration,
    );
  }

  static const Light = LiquidGlassConfig(
    thickness: 16,
    blur: 2.5,
    glassColor: Color(0x0AFFFFFF),
    lightIntensity: 1.4,
    saturation: 1.35,
    refractiveIndex: 1.35,
    lightAngle: -0.75,
    chromaticAberration: 0.02,
  );

  static const Medium = LiquidGlassConfig(
    thickness: 24,
    blur: 4.0,
    glassColor: Color(0x14FFFFFF),
    lightIntensity: 1.6,
    saturation: 1.45,
    refractiveIndex: 1.40,
    lightAngle: -0.75,
    chromaticAberration: 0.025,
  );

  static const Strong = LiquidGlassConfig(
    thickness: 36,
    blur: 6.0,
    glassColor: Color(0x22FFFFFF),
    lightIntensity: 1.8,
    saturation: 1.55,
    refractiveIndex: 1.48,
    lightAngle: -0.75,
    chromaticAberration: 0.035,
  );
}

/// A simplified renderer for liquid glass effect using liquid_glass_widgets
class LiquidGlassRenderer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double thickness;
  final double blur;
  final Color glassColor;
  final double lightIntensity;
  final double saturation;
  final double refractiveIndex;
  final double lightAngle;
  final double chromaticAberration;
  final LiquidShape? shape;
  final GlassQuality? quality;
  final Clip clipBehavior;

  const LiquidGlassRenderer({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.thickness,
    required this.blur,
    required this.glassColor,
    this.lightIntensity = 1.0,
    this.saturation = 1.0,
    this.refractiveIndex = 1.45,
    this.lightAngle = -0.75,
    this.chromaticAberration = 0.01,
    this.shape,
    this.quality,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final liquidShape = shape ??
        LiquidRoundedSuperellipse(borderRadius: borderRadius);

    final settings = LiquidGlassSettings(
      thickness: thickness,
      blur: blur,
      glassColor: glassColor,
      lightIntensity: lightIntensity,
      saturation: saturation,
      refractiveIndex: refractiveIndex,
      lightAngle: lightAngle,
      chromaticAberration: chromaticAberration,
    );

    return AdaptiveGlass(
      useOwnLayer: true,
      shape: liquidShape,
      settings: settings,
      quality: quality ?? GlassQuality.standard,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Wrapper that provides liquid glass effect based on user settings
class LiquidGlassWrapper extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final LiquidGlassConfig config;
  final LiquidShape? shape;
  final GlassQuality? quality;
  final Clip clipBehavior;

  const LiquidGlassWrapper({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.config = LiquidGlassConfig.Medium,
    this.shape,
    this.quality,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    UserSettingsProvider? settings;
    try {
      settings = context.watch<UserSettingsProvider>();
    } catch (_) {}

    final mode = settings?.liquidGlassMode ?? LiquidGlassMode.real;
    final isSolid = ContextX(context).shouldUseSolidBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? 20.0;

    if (mode == LiquidGlassMode.disabled || isSolid) {
      if (isSolid) {
        return Container(
          margin: margin,
          padding: padding,
          clipBehavior: clipBehavior,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D24) : Colors.white,
            borderRadius: BorderRadius.circular(effectiveRadius),
          ),
          child: child,
        );
      }
      return Container(
        margin: margin,
        padding: padding,
        child: child,
      );
    }

    final bgColor =
        backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.3));

    if (mode == LiquidGlassMode.fake) {
      return _FakeGlassWrapper(
        borderRadius: effectiveRadius,
        padding: padding,
        margin: margin,
        bgColor: bgColor,
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    // Real Apple-grade liquid glass
    final glassColor = backgroundColor ??
        (isDark
            ? config.glassColor.withValues(alpha: (config.glassColor.a * 0.7).clamp(0.0, 1.0))
            : config.glassColor);

    return Container(
      margin: margin,
      padding: padding,
      child: LiquidGlassRenderer(
        borderRadius: effectiveRadius,
        shape: shape,
        thickness: config.thickness,
        blur: config.blur,
        glassColor: glassColor,
        lightIntensity: config.lightIntensity,
        saturation: config.saturation,
        refractiveIndex: config.refractiveIndex,
        lightAngle: config.lightAngle,
        chromaticAberration: config.chromaticAberration,
        quality: quality,
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }
}

class _FakeGlassWrapper extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color bgColor;
  final Clip clipBehavior;

  const _FakeGlassWrapper({
    required this.child,
    required this.borderRadius,
    this.padding,
    this.margin,
    required this.bgColor,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        margin: margin,
        padding: padding,
        clipBehavior: clipBehavior,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: child,
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}

/// Extension to wrap any widget with liquid glass
extension LiquidGlassExtension on Widget {
  Widget withLiquidGlass({
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
    LiquidShape? shape,
    GlassQuality? quality,
    Clip clipBehavior = Clip.none,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      config: config,
      shape: shape,
      quality: quality,
      clipBehavior: clipBehavior,
      child: this,
    );
  }
}

/// Extension to wrap Material FAB with liquid glass
extension LiquidGlassFAB on Widget {
  Widget asLiquidGlassFAB({
    double borderRadius = 100,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
    GlassQuality? quality,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      shape: const LiquidOval(),
      config: config,
      quality: quality,
      child: this,
    );
  }
}

/// Extension to wrap Material Card with liquid glass
extension LiquidGlassCard on Widget {
  Widget asLiquidGlassCard({
    double borderRadius = 20,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
    GlassQuality? quality,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      padding: padding,
      margin: margin,
      config: config,
      quality: quality,
      child: this,
    );
  }
}

/// Extension to wrap Material Dialog with liquid glass
extension LiquidGlassDialog on Widget {
  Widget asLiquidGlassDialog({
    double borderRadius = 28,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
    GlassQuality? quality,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: LiquidGlassWrapper(
          borderRadius: borderRadius,
          shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
          config: config,
          quality: quality,
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
    GlassQuality? quality,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      shape: LiquidRoundedRectangle(borderRadius: borderRadius),
      config: config,
      quality: quality,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
        child: this,
      ),
    );
  }
}
