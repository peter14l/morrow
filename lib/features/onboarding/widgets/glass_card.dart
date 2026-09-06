import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../themes/theme_provider.dart';
import '../../../features/settings/presentation/providers/user_settings_provider.dart';
import '../../../features/settings/domain/models/user_settings_entity.dart';
import '../../../core/extensions/context_extensions.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled ||
        ContextX(context).shouldUseSolidBackground;

    UserSettingsProvider? settingsProvider;
    try {
      settingsProvider = Provider.of<UserSettingsProvider>(context, listen: false);
    } catch (_) {}
    final mode = settingsProvider?.liquidGlassMode ?? LiquidGlassMode.real;

    if (disableTransparency || mode == LiquidGlassMode.disabled) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: OasisColors.moss,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ??
              Border.all(
                color: OasisColors.sage.withValues(alpha: 0.4),
                width: 1,
              ),
        ),
        child: child,
      );
    }

    if (mode == LiquidGlassMode.fake) {
      final content = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: OasisColors.moss.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ??
              Border.all(
                color: OasisColors.sage.withValues(alpha: 0.4),
                width: 1,
              ),
        ),
        child: child,
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    // Real Apple-grade Liquid Glass
    return Container(
      width: width,
      height: height,
      padding: padding,
      child: AdaptiveGlass(
        useOwnLayer: true,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        settings: LiquidGlassSettings(
          thickness: 16,
          blur: blur,
          glassColor: OasisColors.moss.withValues(alpha: 0.3),
          lightIntensity: 1.15,
          saturation: 1.1,
          refractiveIndex: 1.45,
          lightAngle: -0.75,
        ),
        child: child,
      ),
    );
  }
}
