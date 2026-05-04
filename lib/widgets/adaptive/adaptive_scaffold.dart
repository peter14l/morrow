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
    final liquidGlassMode = context.watch<UserSettingsProvider>().liquidGlassMode;

    if (useFluent && isDesktop) {
      return fluent.ScaffoldPage(
        header: header ?? (title != null || actions != null
            ? fluent.PageHeader(
                title: title ?? const SizedBox.shrink(),
                commandBar: actions != null
                    ? fluent.CommandBar(
                        primaryItems: actions!.map<fluent.CommandBarItem>((w) {
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
                        }).toList(),
                      )
                    : null,
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
    material.AppBar? materialAppBar;
    if (appBar != null) {
      materialAppBar = appBar;
    } else if (title != null) {
      materialAppBar = material.AppBar(
        title: title,
        actions: actions,
        backgroundColor: material.Colors.transparent,
        elevation: 0,
      );
    }

    // Apply liquid glass to AppBar if enabled
    if (liquidGlassMode != LiquidGlassMode.disabled && materialAppBar != null) {
      materialAppBar = _applyLiquidGlassToAppBar(materialAppBar, liquidGlassMode);
    }

    return material.Scaffold(
      appBar: materialAppBar,
      body: body,
      bottomNavigationBar: footer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }

  material.AppBar _applyLiquidGlassToAppBar(material.AppBar appBar, LiquidGlassMode mode) {
    final brightness = appBar.backgroundColor == material.Colors.transparent 
        ? material.Brightness.dark 
        : material.Brightness.light;
    
    if (mode == LiquidGlassMode.fake) {
      return appBar.copyWith(
        backgroundColor: material.Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: brightness == material.Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
    }
    
    // Real mode - use enhanced blur
    return appBar.copyWith(
      backgroundColor: material.Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  brightness == material.Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
