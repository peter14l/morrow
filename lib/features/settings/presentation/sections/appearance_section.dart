import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:universal_io/io.dart';

import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';

class AppearanceSection extends StatelessWidget {
  final int index;
  final void Function(String title, Widget page) onNavigateToSubPage;

  const AppearanceSection({
    super.key,
    required this.index,
    required this.onNavigateToSubPage,
  });

  static const List<String> _fonts = [
    'System',
    'Outfit',
    'Inter',
    'Comfortaa',
    'Lexend',
    'Times New Roman',
    'Arial',
    'Verdana',
    'Georgia',
    'Garamond',
    'Courier New',
    'Lucida Console',
    'Monaco',
    'Open Dyslexic',
    'Comic Sans',
  ];

  String _getThemeModeName(material.ThemeMode mode) {
    switch (mode) {
      case material.ThemeMode.system:
        return 'System';
      case material.ThemeMode.light:
        return 'Light';
      case material.ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getPaletteName(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return 'None (Default)';
      case ColorPalette.emerald:
        return 'Emerald';
      case ColorPalette.ocean:
        return 'Ocean';
      case ColorPalette.sunset:
        return 'Sunset';
      case ColorPalette.lavender:
        return 'Lavender';
      case ColorPalette.rose:
        return 'Rose';
      case ColorPalette.teal:
        return 'Teal';
      case ColorPalette.aurora:
        return 'Aurora (Pro)';
      case ColorPalette.wildfire:
        return 'Wildfire (Pro)';
      case ColorPalette.neonDreams:
        return 'Neon Dreams (Pro)';
      case ColorPalette.oceanDepths:
        return 'Ocean Depths (Pro)';
    }
  }

  material.Color _getPaletteColor(ColorPalette palette) {
    switch (palette) {
      case ColorPalette.none:
        return material.Colors.grey;
      case ColorPalette.emerald:
        return const material.Color(0xFF1C6758);
      case ColorPalette.ocean:
        return const material.Color(0xFF0D47A1);
      case ColorPalette.sunset:
        return const material.Color(0xFFE65100);
      case ColorPalette.lavender:
        return const material.Color(0xFF7E57C2);
      case ColorPalette.rose:
        return const material.Color(0xFFC2185B);
      case ColorPalette.teal:
        return const material.Color(0xFF00796B);
      case ColorPalette.aurora:
        return const material.Color(0xFF00D9FF);
      case ColorPalette.wildfire:
        return const material.Color(0xFFFF6B35);
      case ColorPalette.neonDreams:
        return const material.Color(0xFFB967FF);
      case ColorPalette.oceanDepths:
        return const material.Color(0xFF0066FF);
    }
  }

  String _getLiquidGlassModeName(LiquidGlassMode mode) {
    switch (mode) {
      case LiquidGlassMode.disabled:
        return 'Disabled';
      case LiquidGlassMode.fake:
        return 'Fake (Low battery)';
      case LiquidGlassMode.real:
        return 'Real (Full effect)';
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = material.Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userSettingsProvider = Provider.of<UserSettingsProvider>(context);
    final theme = material.Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useFluent = themeProvider.useFluentUI;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsGroup(
          index: index,
          children: [
            SettingsTile(
              icon: material.Icons.palette_outlined,
              title: 'Theme',
              subtitle: _getThemeModeName(themeProvider.themeMode),
              iconColor: material.Colors.blue,
              trailing: useFluent
                  ? fluent.ComboBox<material.ThemeMode>(
                      value: themeProvider.themeMode,
                      items: const [
                        fluent.ComboBoxItem(
                          value: material.ThemeMode.system,
                          child: fluent.Text('System'),
                        ),
                        fluent.ComboBoxItem(
                          value: material.ThemeMode.light,
                          child: fluent.Text('Light'),
                        ),
                        fluent.ComboBoxItem(
                          value: material.ThemeMode.dark,
                          child: fluent.Text('Dark'),
                        ),
                      ],
                      onChanged: (mode) =>
                          mode != null ? themeProvider.setTheme(mode) : null,
                    )
                  : material.DropdownButton<material.ThemeMode>(
                      value: themeProvider.themeMode,
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      underline: const SizedBox(),
                      onChanged: (mode) =>
                          mode != null ? themeProvider.setTheme(mode) : null,
                      items: const [
                        material.DropdownMenuItem(
                          value: material.ThemeMode.system,
                          child: material.Text('System'),
                        ),
                        material.DropdownMenuItem(
                          value: material.ThemeMode.light,
                          child: material.Text('Light'),
                        ),
                        material.DropdownMenuItem(
                          value: material.ThemeMode.dark,
                          child: material.Text('Dark'),
                        ),
                      ],
                    ),
            ),
            SettingsTile(
              icon: material.Icons.font_download_outlined,
              title: 'App Font',
              subtitle: userSettingsProvider.fontFamily,
              iconColor: material.Colors.teal,
              trailing: useFluent
                  ? fluent.ComboBox<String>(
                      value: userSettingsProvider.fontFamily,
                      onChanged: (font) => font != null
                          ? userSettingsProvider.setFontFamily(font)
                          : null,
                      items: _fonts
                          .map(
                            (font) => fluent.ComboBoxItem(
                              value: font,
                              child: fluent.Text(
                                font,
                                style: TextStyle(
                                  fontFamily: font == 'System' ? null : font,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : material.DropdownButton<String>(
                      value: userSettingsProvider.fontFamily,
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      underline: const SizedBox(),
                      onChanged: (font) {
                        if (font != null) {
                          userSettingsProvider.setFontFamily(font);
                        }
                      },
                      items: _fonts.map((font) {
                        return material.DropdownMenuItem(
                          value: font,
                          child: material.Text(
                            font,
                            style: TextStyle(
                              fontFamily: font == 'System' ? null : font,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            SettingsTile(
              icon: material.Icons.rocket_launch_outlined,
              title: 'M3 Expressive',
              subtitle: 'Vibrant & high-contrast design.',
              iconColor: material.Colors.pink,
              trailing: useFluent
                  ? fluent.ToggleSwitch(
                      checked: themeProvider.isM3EEnabled,
                      onChanged: (v) {
                        themeProvider.setM3EEnabled(v);
                      },
                    )
                  : material.Switch(
                      value: themeProvider.isM3EEnabled,
                      onChanged: (v) {
                        themeProvider.setM3EEnabled(v);
                      },
                    ),
            ),
            SettingsTile(
              icon: material.Icons.blur_on_outlined,
              title: 'Transparency Effects',
              subtitle: 'Glassmorphism and blur effects.',
              iconColor: material.Colors.cyan,
              trailing: useFluent
                  ? fluent.ToggleSwitch(
                      checked: !themeProvider.isM3ETransparencyDisabled,
                      onChanged: (v) => themeProvider.setM3ETransparencyDisabled(!v),
                    )
                  : material.Switch(
                      value: !themeProvider.isM3ETransparencyDisabled,
                      onChanged: (v) => themeProvider.setM3ETransparencyDisabled(!v),
                    ),
            ),
            if (themeProvider.isM3ETransparencyDisabled && (kIsWeb || !Platform.isAndroid && !Platform.isIOS))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: material.Text(
                  'Note: Transparency is disabled on this platform for performance.',
                  style: TextStyle(fontSize: 11, color: material.Colors.orange),
                ),
              ),
            if (themeProvider.isM3EEnabled)
              SettingsTile(
                icon: material.Icons.color_lens_outlined,
                title: 'Dynamic Theme',
                subtitle: 'Use system colors (Material You).',
                iconColor: material.Colors.orange,
                trailing: useFluent
                    ? fluent.ToggleSwitch(
                        checked: themeProvider.useMaterialYou,
                        onChanged: (v) => themeProvider.setMaterialYou(v),
                      )
                    : material.Switch(
                        value: themeProvider.useMaterialYou,
                        onChanged: (v) => themeProvider.setMaterialYou(v),
                      ),
              ),
            if (themeProvider.isM3EEnabled && !themeProvider.useMaterialYou)
              SettingsTile(
                icon: material.Icons.palette_outlined,
                title: 'Color Palette',
                subtitle: _getPaletteName(themeProvider.colorPalette),
                iconColor: _getPaletteColor(themeProvider.colorPalette),
                trailing: useFluent
                    ? fluent.ComboBox<ColorPalette>(
                        value: themeProvider.colorPalette,
                        onChanged: (p) =>
                            p != null ? themeProvider.setColorPalette(p) : null,
                        items: ColorPalette.values
                            .map(
                              (p) => fluent.ComboBoxItem(
                                value: p,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _getPaletteColor(p),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    fluent.Text(_getPaletteName(p)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : material.DropdownButton<ColorPalette>(
                        value: themeProvider.colorPalette,
                        dropdownColor: colorScheme.surfaceContainerHigh,
                        underline: const SizedBox(),
                        onChanged: (palette) {
                          if (palette != null) {
                            themeProvider.setColorPalette(palette);
                          }
                        },
                        items: ColorPalette.values.map((palette) {
                          return material.DropdownMenuItem(
                            value: palette,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _getPaletteColor(palette),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                material.Text(_getPaletteName(palette)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(context, 'Visual Effects'),
        SettingsGroup(
          index: 11,
          children: [
            SettingsTile(
              icon: material.Icons.auto_awesome_outlined,
              title: 'Liquid Glass',
              subtitle: _getLiquidGlassModeName(userSettingsProvider.liquidGlassMode),
              iconColor: material.Colors.purple,
              trailing: useFluent
                  ? fluent.ComboBox<LiquidGlassMode>(
                      value: userSettingsProvider.liquidGlassMode,
                      onChanged: (mode) => mode != null
                          ? userSettingsProvider.setLiquidGlassMode(mode)
                          : null,
                      items: LiquidGlassMode.values
                          .map(
                            (mode) => fluent.ComboBoxItem(
                              value: mode,
                              child: fluent.Text(_getLiquidGlassModeName(mode)),
                            ),
                          )
                          .toList(),
                    )
                  : material.DropdownButton<LiquidGlassMode>(
                      value: userSettingsProvider.liquidGlassMode,
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      underline: const SizedBox(),
                      onChanged: (mode) {
                        if (mode != null) {
                          userSettingsProvider.setLiquidGlassMode(mode);
                        }
                      },
                      items: LiquidGlassMode.values.map((mode) {
                        return material.DropdownMenuItem(
                          value: mode,
                          child: material.Text(_getLiquidGlassModeName(mode)),
                        );
                      }).toList(),
                    ),
            ),
            if (userSettingsProvider.liquidGlassMode != LiquidGlassMode.disabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: material.Text(
                  userSettingsProvider.liquidGlassMode == LiquidGlassMode.real
                      ? 'Real liquid glass may affect battery life on mobile devices.'
                      : 'Fake glass uses less battery but has fewer visual effects.',
                  style: material.TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (kIsWeb == false && Platform.isWindows) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Windows Effects'),
          SettingsGroup(
            index: 10,
            children: [
              SettingsTile(
                icon: FluentIcons.window_apps_24_regular,
                title: 'Window Transparency',
                subtitle: 'Enable Mica/Acrylic background effects.',
                iconColor: material.Colors.blue,
                trailing: useFluent
                    ? fluent.ToggleSwitch(
                        checked: userSettingsProvider.micaEnabled,
                        onChanged: (v) => userSettingsProvider.setMicaEnabled(v),
                      )
                    : material.Switch(
                        value: userSettingsProvider.micaEnabled,
                        onChanged: (v) => userSettingsProvider.setMicaEnabled(v),
                      ),
              ),
              if (userSettingsProvider.micaEnabled)
                SettingsTile(
                  icon: FluentIcons.blur_24_regular,
                  title: 'Effect Type',
                  subtitle: userSettingsProvider.windowEffect.toUpperCase(),
                  iconColor: material.Colors.teal,
                  trailing: useFluent
                      ? fluent.ComboBox<String>(
                          value: userSettingsProvider.windowEffect,
                          onChanged: (v) => v != null
                              ? userSettingsProvider.setWindowEffect(v)
                              : null,
                          items: const [
                            fluent.ComboBoxItem(
                              value: 'mica',
                              child: fluent.Text('Mica (Default)'),
                            ),
                            fluent.ComboBoxItem(
                              value: 'acrylic',
                              child: fluent.Text('Acrylic'),
                            ),
                          ],
                        )
                      : material.DropdownButton<String>(
                          value: userSettingsProvider.windowEffect,
                          dropdownColor: colorScheme.surfaceContainerHigh,
                          underline: const SizedBox(),
                          onChanged: (v) => v != null
                              ? userSettingsProvider.setWindowEffect(v)
                              : null,
                          items: const [
                            material.DropdownMenuItem(
                              value: 'mica',
                              child: material.Text('Mica'),
                            ),
                            material.DropdownMenuItem(
                              value: 'acrylic',
                              child: material.Text('Acrylic'),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
