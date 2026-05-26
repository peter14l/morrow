import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/responsive_layout.dart';

class CustomTextField extends StatelessWidget {
  final material.TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final material.IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final material.TextInputType? keyboardType;
  final material.TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final material.TextCapitalization textCapitalization;
  final bool autofocus;
  final bool readOnly;
  final bool showCursor;
  final void Function()? onTap;
  final void Function(String)? onChanged;
  final String? initialValue;
  final String? label;
  final bool enabled;
  final material.Color? fillColor;
  final material.Color? textColor;
  final material.Color? hintColor;
  final double? borderRadius;
  final material.EdgeInsetsGeometry? contentPadding;
  final material.EdgeInsetsGeometry? margin;
  final bool isDense;
  final Widget? prefix;
  final Widget? suffix;
  final material.InputBorder? border;
  final material.InputBorder? enabledBorder;
  final material.InputBorder? focusedBorder;
  final material.BoxConstraints? prefixIconConstraints;
  final material.BoxConstraints? suffixIconConstraints;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = material.TextCapitalization.none,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor = true,
    this.onTap,
    this.onChanged,
    this.initialValue,
    this.label,
    this.enabled = true,
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.borderRadius,
    this.contentPadding,
    this.margin,
    this.isDense = false,
    this.prefix,
    this.suffix,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
  });

  @override
  Widget build(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(context).useFluentUI;

    if (useFluent) {
      return _buildFluentTextBox(context);
    }

    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isM3E = Provider.of<ThemeProvider>(context).isM3EEnabled;
    final isMobile = ResponsiveLayout.isMobile(context);

    final effectiveFillColor =
        fillColor ??
        (isM3E
            ? colorScheme.primary.withValues(alpha: 0.05)
            : theme.inputDecorationTheme.fillColor);
    final effectiveTextColor = textColor ?? colorScheme.onSurface;
    final effectiveHintColor =
        hintColor ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final effectiveRadius = borderRadius ?? (isM3E ? 24.0 : 16.0);

    return Container(
      margin: margin ?? const material.EdgeInsets.only(bottom: 8),
      child: material.TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        readOnly: readOnly,
        showCursor: showCursor,
        onTap: onTap,
        onChanged: onChanged,
        initialValue: initialValue,
        enabled: enabled,
        style: theme.textTheme.bodyLarge?.copyWith(color: effectiveTextColor),
        decoration: material.InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: effectiveHintColor,
          ),
          labelStyle: theme.textTheme.bodyLarge?.copyWith(
            color: effectiveHintColor,
          ),
          filled: true,
          fillColor: effectiveFillColor,
          isDense: isDense,
          prefixIcon:
              prefix ??
              (prefixIcon != null
                  ? material.Icon(prefixIcon, color: effectiveHintColor)
                  : null),
          prefixIconConstraints: prefixIconConstraints,
          suffixIcon: suffix ?? suffixIcon,
          suffixIconConstraints: suffixIconConstraints,
          border:
              border ??
              material.OutlineInputBorder(
                borderRadius: material.BorderRadius.circular(effectiveRadius),
                borderSide: isM3E
                    ? material.BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      )
                    : material.BorderSide.none,
              ),
          enabledBorder:
              enabledBorder ??
              material.OutlineInputBorder(
                borderRadius: material.BorderRadius.circular(effectiveRadius),
                borderSide: isM3E
                    ? material.BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      )
                    : material.BorderSide.none,
              ),
          focusedBorder:
              focusedBorder ??
              material.OutlineInputBorder(
                borderRadius: material.BorderRadius.circular(effectiveRadius),
                borderSide: material.BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
          contentPadding:
              contentPadding ??
              material.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 12 : 16,
              ),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildFluentTextBox(BuildContext context) {
    final isM3E = Provider.of<ThemeProvider>(context).isM3EEnabled;
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveRadius = borderRadius ?? (isM3E ? 12.0 : 8.0);
    final effectiveFillColor =
        fillColor ??
        (isM3E ? colorScheme.primary.withValues(alpha: 0.05) : null);

    // Check if we should hide the border (e.g. when used inside another decorated container)
    final hideBorder =
        border == material.InputBorder.none ||
        enabledBorder == material.InputBorder.none ||
        focusedBorder == material.InputBorder.none;

    return Container(
      margin: margin ?? const material.EdgeInsets.only(bottom: 8),
      child: fluent.InfoLabel(
        label: label ?? '',
        child: fluent.TextBox(
          controller: controller,
          focusNode: focusNode,
          placeholder: hint,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onFieldSubmitted,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofocus: autofocus,
          readOnly: readOnly,
          showCursor: showCursor,
          onTap: onTap,
          onChanged: onChanged,
          enabled: enabled,
          prefix: prefixIcon != null
              ? material.Padding(
                  padding: const material.EdgeInsets.only(left: 8.0),
                  child: material.Icon(prefixIcon, size: 16),
                )
              : null,
          suffix: suffixIcon,
          padding:
              (contentPadding as material.EdgeInsets?) ??
              const material.EdgeInsets.all(8.0),
          decoration: fluent.WidgetStatePropertyAll(
            hideBorder
                ? fluent.BoxDecoration(
                    color: effectiveFillColor,
                    border: const fluent.Border(), // Empty border to hide it
                  )
                : fluent.BoxDecoration(
                    color: effectiveFillColor,
                    borderRadius: material.BorderRadius.circular(
                      effectiveRadius,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// Extension for easy creation of common text fields
extension CustomTextFieldExtension on CustomTextField {
  static Widget email({
    required material.TextEditingController controller,
    required FocusNode focusNode,
    required void Function(String) onFieldSubmitted,
    String? Function(String?)? validator,
    String hint = 'Email',
    material.TextInputAction? textInputAction,
    FocusNode? nextFocus,
  }) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      prefixIcon: material.Icons.email_outlined,
      keyboardType: material.TextInputType.emailAddress,
      textInputAction: textInputAction ?? material.TextInputAction.next,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
      onFieldSubmitted: (value) {
        onFieldSubmitted(value);
        if (nextFocus != null) {
          focusNode.unfocus();
          FocusScope.of(focusNode.context!).requestFocus(nextFocus);
        }
      },
    );
  }

  static Widget password({
    required material.TextEditingController controller,
    required FocusNode focusNode,
    required bool obscureText,
    required material.VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
    String hint = 'Password',
    material.TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      prefixIcon: material.Icons.lock_outline,
      obscureText: obscureText,
      textInputAction: textInputAction ?? material.TextInputAction.done,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
      onFieldSubmitted: onFieldSubmitted,
      suffixIcon: material.IconButton(
        icon: material.Icon(
          obscureText
              ? material.Icons.visibility_off
              : material.Icons.visibility,
          color: const material.Color(0xFF9DA6B9),
        ),
        onPressed: onToggleVisibility,
      ),
    );
  }

  static Widget name({
    required material.TextEditingController controller,
    required FocusNode focusNode,
    String? Function(String?)? validator,
    String hint = 'Name',
    material.TextInputAction? textInputAction,
    FocusNode? nextFocus,
  }) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      prefixIcon: material.Icons.person_outline,
      textInputAction: textInputAction ?? material.TextInputAction.next,
      textCapitalization: material.TextCapitalization.words,
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
      onFieldSubmitted: nextFocus != null
          ? (_) => FocusScope.of(focusNode.context!).requestFocus(nextFocus)
          : null,
    );
  }
}
