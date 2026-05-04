import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

/// Settings for liquid glass appearance
class LiquidGlassConfig {
  final double thickness;
  final double blur;
  final Color glassColor;
  final double lightIntensity;
  final double saturation;

  const LiquidGlassConfig({
    this.thickness = 15,
    this.blur = 8,
    this.glassColor = const Color(0x33FFFFFF),
    this.lightIntensity = 1.2,
    this.saturation = 1.1,
  });

  static const Light = LiquidGlassConfig(
    thickness: 10,
    blur: 6,
    glassColor: Color(0x1AFFFFFF),
    lightIntensity: 1.0,
    saturation: 1.0,
  );

  static const Medium = LiquidGlassConfig(
    thickness: 15,
    blur: 8,
    glassColor: Color(0x33FFFFFF),
    lightIntensity: 1.2,
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

    if (mode == LiquidGlassMode.disabled) {
      // No glass effect - return child as-is
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
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

/// FakeGlass implementation (backdrop filter only - low battery)
class _FakeGlassWrapper extends StatelessWidget {
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color bgColor;
  final Widget child;

  const _FakeGlassWrapper({
    required this.borderRadius,
    this.padding,
    required this.bgColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Real liquid glass implementation (full shader effect)
class _RealLiquidGlassWrapper extends StatelessWidget {
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color bgColor;
  final LiquidGlassConfig config;
  final Widget child;

  const _RealLiquidGlassWrapper({
    required this.borderRadius,
    this.padding,
    required this.bgColor,
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass.withOwnLayer(
      settings: LiquidGlassSettings(
        thickness: config.thickness,
        blur: config.blur,
        glassColor: config.glassColor,
        lightIntensity: config.lightIntensity,
        saturation: config.saturation,
      ),
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      child: Container(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Full liquid glass container with background support
/// Use this for the best real liquid glass results
class LiquidGlassContainer extends StatelessWidget {
  final Widget background;
  final List<Widget> glassChildren;
  final EdgeInsetsGeometry? padding;
  final LiquidGlassConfig config;

  const LiquidGlassContainer({
    super.key,
    required this.background,
    required this.glassChildren,
    this.padding,
    this.config = LiquidGlassConfig.Medium,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();
    final mode = settings.liquidGlassMode;

    if (mode == LiquidGlassMode.disabled) {
      return Stack(
        children: [
          background,
          if (padding != null) Padding(padding: padding!, child: Stack(children: glassChildren)),
          if (padding == null) ...glassChildren,
        ],
      );
    }

    if (mode == LiquidGlassMode.fake) {
      return Stack(
        children: [
          background,
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  padding: padding,
                  child: Stack(children: glassChildren),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Real liquid glass with layer
    return Stack(
      children: [
        background,
        LiquidGlassLayer(
          settings: LiquidGlassSettings(
            thickness: config.thickness,
            blur: config.blur,
            glassColor: config.glassColor,
            lightIntensity: config.lightIntensity,
            saturation: config.saturation,
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Stack(children: glassChildren),
          ),
        ),
      ],
    );
  }
}

/// Standalone LiquidGlass button/fab wrapper
class LiquidGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final LiquidGlassConfig config;

  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.padding,
    this.config = LiquidGlassConfig.Medium,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      padding: padding,
      config: config,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    );
  }
}

/// Check if liquid glass is enabled anywhere in the app
bool isLiquidGlassEnabled(BuildContext context) {
  final settings = context.read<UserSettingsProvider>();
  return settings.liquidGlassMode != LiquidGlassMode.disabled;
}

/// Get current liquid glass mode
LiquidGlassMode getLiquidGlassMode(BuildContext context) {
  final settings = context.read<UserSettingsProvider>();
  return settings.liquidGlassMode;
}

/// Extension to wrap Material FloatingActionButton with liquid glass
extension LiquidGlassFloatingActionButton on Widget {
  Widget asLiquidGlassFAB({
    double borderRadius = 28,
    LiquidGlassConfig config = LiquidGlassConfig.Light,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      config: config,
      child: this,
    );
  }
}

/// Extension to wrap Card with liquid glass
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

/// Extension to wrap Dialog with liquid glass
extension LiquidGlassDialog on Widget {
  Widget asLiquidGlassDialog({
    double borderRadius = 28,
    LiquidGlassConfig config = LiquidGlassConfig.Medium,
  }) {
    return LiquidGlassWrapper(
      borderRadius: borderRadius,
      config: config,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: this,
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