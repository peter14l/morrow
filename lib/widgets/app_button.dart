import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:flutter/services.dart';
class AppButton extends StatelessWidget {
  final String text;
  final material.VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isFullWidth;
  final material.Color? backgroundColor;
  final material.Color? textColor;
  final double borderRadius;
  final material.EdgeInsetsGeometry? padding;
  final Widget? icon;
  final double? width;
  final double? height;
  final bool disabled;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 28.0,
    this.padding,
    this.icon,
    this.width,
    this.height = 56.0,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(context).useFluentUI;

    if (useFluent) {
      return _buildFluentButton(context);
    }

    final theme = material.Theme.of(context);
    final isM3E = Provider.of<ThemeProvider>(context).isM3EEnabled;
    final buttonStyle = _getMaterialButtonStyle(theme, isM3E);
    final buttonChild = _buildMaterialButtonChild(theme);

    final void Function()? wrappedOnPressed = disabled || isLoading || onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };

    final button = isOutlined
        ? material.OutlinedButton(
            onPressed: wrappedOnPressed,
            style: buttonStyle,
            child: buttonChild,
          )
        : material.ElevatedButton(
            onPressed: wrappedOnPressed,
            style: buttonStyle,
            child: buttonChild,
          );

    if (isFullWidth) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: button,
      );
    }

    return SizedBox(width: width, height: height, child: button);
  }

  Widget _buildFluentButton(BuildContext context) {
    // final fluentTheme = fluent.FluentTheme.of(context);

    final Widget child = isLoading
        ? const fluent.ProgressRing(strokeWidth: 2)
        : material.Row(
            mainAxisSize: material.MainAxisSize.min,
            mainAxisAlignment: material.MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const material.SizedBox(width: 8)],
              Text(text),
            ],
          );

    final void Function()? wrappedOnPressed = disabled || isLoading || onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed!();
          };

    Widget button;

    if (isOutlined) {
      button = fluent.Button(
        onPressed: wrappedOnPressed,
        child: child,
      );
    } else {
      button = fluent.FilledButton(
        onPressed: wrappedOnPressed,
        child: child,
      );
    }

    if (isFullWidth) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: button,
      );
    }

    return SizedBox(width: width, height: height, child: button);
  }

  Widget _buildMaterialButtonChild(material.ThemeData theme) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: material.CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: material.AlwaysStoppedAnimation<material.Color>(
            material.Colors.white,
          ),
        ),
      );
    }

    final textWidget = material.Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color:
            textColor ??
            (isOutlined ? theme.colorScheme.primary : material.Colors.white),
        fontWeight: material.FontWeight.w600,
      ),
      maxLines: 1,
      overflow: material.TextOverflow.ellipsis,
    );

    if (icon != null) {
      return material.Row(
        mainAxisSize: material.MainAxisSize.min,
        children: [icon!, const material.SizedBox(width: 8), textWidget],
      );
    }

    return textWidget;
  }

  material.ButtonStyle _getMaterialButtonStyle(
    material.ThemeData theme,
    bool isM3E,
  ) {
    final colorScheme = theme.colorScheme;
    final backgroundColor = this.backgroundColor ?? colorScheme.primary;
    final foregroundColor =
        textColor ?? (isOutlined ? colorScheme.primary : material.Colors.white);
    final shape = isM3E
        ? const material.StadiumBorder()
        : material.RoundedRectangleBorder(
            borderRadius: material.BorderRadius.circular(borderRadius),
          );

    final baseStyle = isOutlined
        ? material.OutlinedButton.styleFrom(
            foregroundColor: foregroundColor,
            backgroundColor: material.Colors.transparent,
            side: material.BorderSide(
              color: disabled
                  ? colorScheme.onSurface.withValues(alpha: 0.12)
                  : colorScheme.primary,
              width: isM3E ? 2.0 : 1.5,
            ),
            padding:
                padding ??
                const material.EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
            shape: shape,
          )
        : material.ElevatedButton.styleFrom(
            foregroundColor: foregroundColor,
            backgroundColor: disabled
                ? colorScheme.onSurface.withValues(alpha: 0.12)
                : backgroundColor,
            padding:
                padding ??
                const material.EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
            shape: shape,
            elevation: isM3E ? 0 : 0,
          );

    return baseStyle.copyWith(
      overlayColor: material.WidgetStateProperty.resolveWith<material.Color>((
        states,
      ) {
        if (states.contains(material.WidgetState.pressed)) {
          return foregroundColor.withValues(alpha: 0.1);
        }
        if (states.contains(material.WidgetState.hovered)) {
          return foregroundColor.withValues(alpha: 0.05);
        }
        return material.Colors.transparent;
      }),
    );
  }

  // Primary Button
  factory AppButton.primary({
    material.Key? key,
    required String text,
    required material.VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    material.Color? backgroundColor,
    material.Color? textColor,
    double borderRadius = 28.0,
    material.EdgeInsetsGeometry? padding,
    Widget? icon,
    double? width,
    double? height = 56.0,
    bool disabled = false,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isOutlined: false,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      borderRadius: borderRadius,
      padding: padding,
      icon: icon,
      width: width,
      height: height,
      disabled: disabled,
    );
  }

  // Secondary Button
  factory AppButton.secondary({
    material.Key? key,
    required String text,
    required material.VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    material.Color? backgroundColor,
    material.Color? textColor,
    double borderRadius = 28.0,
    material.EdgeInsetsGeometry? padding,
    Widget? icon,
    double? width,
    double? height = 56.0,
    bool disabled = false,
  }) {
    return AppButton(
      key: key,
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isOutlined: true,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      borderRadius: borderRadius,
      padding: padding,
      icon: icon,
      width: width,
      height: height,
      disabled: disabled,
    );
  }
}
