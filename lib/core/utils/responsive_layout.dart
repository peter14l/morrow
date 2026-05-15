import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Responsive layout breakpoints and utilities
class ResponsiveLayout {
  // Breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1024;

  // Max widths
  static const double maxContentWidth = 1400;
  static const double maxFeedWidth = 700;
  static const double maxFormWidth = 700;
  static const double maxCommentsWidth = 800;
  static const double sidebarWidth = 350;
  static const double navigationRailWidth = 80;

  /// Check if current width is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current width is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if current width is desktop
  static bool isDesktop(BuildContext context) {
    // Only allow desktop layout on non-mobile platforms
    final bool isMobilePlatform =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    if (isMobilePlatform) return false;

    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive value based on screen size
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  /// Get number of grid columns based on screen size
  static int getGridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return getValue(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }
}

/// Widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout.getValue(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile,
      desktop: desktop ?? tablet ?? mobile,
    );
  }
}

/// Widget that constrains content width on larger screens
class MaxWidthContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MaxWidthContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Adaptive padding based on screen size
class AdaptivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.mobilePadding = const EdgeInsets.all(16),
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.getValue(
      context,
      mobile: mobilePadding,
      tablet: tabletPadding,
      desktop: desktopPadding,
    );

    return Padding(padding: padding, child: child);
  }
}
