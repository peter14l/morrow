import 'dart:ui';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:universal_io/io.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? footer;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final material.PreferredSizeWidget? appBar; // Only for Material
  final bool resizeToAvoidBottomInset;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.header,
    this.footer,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.appBar,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final useFluent = Provider.of<ThemeProvider>(context).useFluentUI;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final liquidGlassMode = context
        .watch<UserSettingsProvider>()
        .liquidGlassMode;

    if (useFluent && isDesktop) {
      return fluent.ScaffoldPage(
        header:
            header ??
            (title != null || actions != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: fluent.PageHeader(
                      title: title != null
                          ? DefaultTextStyle.merge(
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              child: title!,
                            )
                          : const SizedBox.shrink(),
                      commandBar: actions != null
                          ? fluent.CommandBar(
                              primaryItems: actions!.map<fluent.CommandBarItem>(
                                (w) {
                                  if (w is fluent.CommandBarItem) {
                                    return w as fluent.CommandBarItem;
                                  }
                                  return fluent.CommandBarBuilderItem(
                                    builder: (context, mode, child) => w,
                                    wrappedItem: fluent.CommandBarButton(
                                      onPressed: () {},
                                      icon: const SizedBox.shrink(),
                                    ),
                                  );
                                },
                              ).toList(),
                            )
                          : null,
                    ),
                  )
                : null),
        content: material.ScaffoldMessenger(
          child: material.Material(
            color: material.Colors.transparent,
            child: body,
          ),
        ),
        bottomBar: footer,
      );
    }

    // Material mobile/tablet layout
    material.PreferredSizeWidget? materialAppBar = appBar;

    // Apply liquid glass to AppBar if enabled (and only if we have a title, not custom appBar)
    if (liquidGlassMode != LiquidGlassMode.disabled &&
        materialAppBar == null &&
        title != null) {
      materialAppBar = _buildLiquidGlassAppBar(
        title!,
        actions,
        liquidGlassMode,
      );
    }

    return material.Scaffold(
      appBar: materialAppBar,
      body: body,
      bottomNavigationBar: footer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  /// Build a new AppBar with liquid glass effect
  material.PreferredSizeWidget _buildLiquidGlassAppBar(
    Widget title,
    List<Widget>? actions,
    LiquidGlassMode mode,
  ) {
    final isDarkMode = mode == LiquidGlassMode.real;
    final blurAmount = isDarkMode ? 15.0 : 10.0;

    return material.AppBar(
      title: title,
      actions: actions,
      backgroundColor: material.Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDarkMode
                      ? material.Colors.white.withValues(alpha: 0.1)
                      : material.Colors.white.withValues(alpha: 0.25),
                  material.Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
