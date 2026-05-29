import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/domain/models/user_settings_entity.dart';
import 'package:oasis/features/settings/presentation/providers/user_settings_provider.dart';

/// A morphing liquid glass FAB that provides real-time light refraction
/// and organic liquid movement with jelly-like touch response.
class MorphingLiquidFAB extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;
  final Color? glowColor;
  final double morphIntensity;

  const MorphingLiquidFAB({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 56,
    this.tooltip,
    this.glowColor,
    this.morphIntensity = 0.15,
  });

  @override
  State<MorphingLiquidFAB> createState() => _MorphingLiquidFABState();
}

class _MorphingLiquidFABState extends State<MorphingLiquidFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _morphController;
  bool _isPressed = false;
  double _pressScale = 1.0;

  @override
  void initState() {
    super.initState();
    // Continuous organic morphing animation
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
      _pressScale = 1.0 - (widget.morphIntensity * 0.5);
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
      _pressScale = 1.0;
    });
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
      _pressScale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<UserSettingsProvider>();
    final liquidGlassMode = settings.liquidGlassMode;

    // Calculate morphing values
    final morphValue = _morphController.value;
    final morphAmount =
        math.sin(morphValue * math.pi * 2) * widget.morphIntensity;
    final morphAmount2 =
        math.cos(morphValue * math.pi * 3) * (widget.morphIntensity * 0.6);

    // Determine the border radius with morphing for liquid feel
    final baseRadius = widget.size / 2;
    final morphRadius = baseRadius + (morphAmount * 8);

    // Glow color
    final glowColor = widget.glowColor ?? theme.colorScheme.primary;

    Widget fab = AnimatedBuilder(
      animation: _morphController,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedScale(
            scale: _pressScale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: _buildLiquidGlassFAB(
              context,
              liquidGlassMode,
              isDark,
              morphRadius,
              morphAmount2,
              glowColor,
            ),
          ),
        );
      },
    );

    if (widget.tooltip != null) {
      fab = Tooltip(message: widget.tooltip, child: fab);
    }

    return fab;
  }

  Widget _buildLiquidGlassFAB(
    BuildContext context,
    LiquidGlassMode mode,
    bool isDark,
    double morphRadius,
    double morphAmount2,
    Color glowColor,
  ) {
    if (mode == LiquidGlassMode.disabled) {
      return _buildFallbackFAB(context, isDark);
    }

    if (mode == LiquidGlassMode.fake) {
      return _buildFakeLiquidFAB(
        context,
        isDark,
        morphRadius,
        morphAmount2,
        glowColor,
      );
    }

    // Real liquid glass - the authentic refraction effect
    return _buildRealLiquidFAB(
      context,
      isDark,
      morphRadius,
      morphAmount2,
      glowColor,
    );
  }

  Widget _buildFallbackFAB(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0.05),
                ]
              : [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.4),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: widget.child),
    );
  }

  Widget _buildFakeLiquidFAB(
    BuildContext context,
    bool isDark,
    double morphRadius,
    double morphAmount2,
    Color glowColor,
  ) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.white.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.5),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(child: widget.child),
    );
  }

  Widget _buildRealLiquidFAB(
    BuildContext context,
    bool isDark,
    double morphRadius,
    double morphAmount2,
    Color glowColor,
  ) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.35);

    // Use superellipse shape for organic liquid feel
    final shape = LiquidRoundedSuperellipse(borderRadius: morphRadius);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Outer glow
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          // Inner glow
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 48,
            spreadRadius: 8,
          ),
        ],
      ),
      child: LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          thickness: 12,
          blur: 6,
          glassColor: baseColor.withValues(alpha: 0.4),
          lightIntensity: 1.4,
          saturation: 1.2,
          refractiveIndex: 1.45,
          outlineIntensity: 1.0,
          lightAngle: -0.75,
        ),
        shape: shape,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// Configuration for each option in the liquid FAB cluster
class LiquidFABOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const LiquidFABOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// An expandable FAB cluster that "spills out" options with liquid animation
class LiquidFABCluster extends StatefulWidget {
  final List<LiquidFABOption> options;
  final double mainFABSize;
  final double childFABSize;
  final Color? mainGlowColor;
  final double animationDuration;

  const LiquidFABCluster({
    super.key,
    required this.options,
    this.mainFABSize = 56,
    this.childFABSize = 48,
    this.mainGlowColor,
    this.animationDuration = 500,
  });

  @override
  State<LiquidFABCluster> createState() => _LiquidFABClusterState();
}

class _LiquidFABClusterState extends State<LiquidFABCluster>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _morphController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animationDuration.toInt()),
    );

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _expandController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<UserSettingsProvider>();
    final liquidGlassMode = settings.liquidGlassMode;
    final glowColor = widget.mainGlowColor ?? theme.colorScheme.primary;

    // Calculate positions for child FABs (arc distribution above main FAB)
    final count = widget.options.length;
    const angleSpread = math.pi * 0.6; // 60 degrees spread
    const startAngle = -math.pi / 2 - angleSpread / 2;
    const radius = 90.0;

    return SizedBox(
      width: 200,
      height: 250,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Child FABs that "spill out"
          ...List.generate(count, (index) {
            final angle =
                startAngle +
                (angleSpread * index / (count - 1).clamp(1, count));
            final x = math.cos(angle) * radius;
            final y = math.sin(angle) * radius - 20;

            return AnimatedBuilder(
              animation: _expandController,
              builder: (context, child) {
                final progress = CurvedAnimation(
                  parent: _expandController,
                  curve: Curves.easeOutBack,
                ).value;

                // Stagger each FAB's animation
                final delay = index * 0.15;
                final staggeredProgress = ((progress - delay) / (1 - delay))
                    .clamp(0.0, 1.0);

                // Add liquid wobble
                final wobble =
                    math.sin(_morphController.value * math.pi * 2 + index) *
                    0.1;

                final scale = _isExpanded
                    ? Curves.elasticOut.transform(staggeredProgress) *
                          (1 + wobble)
                    : staggeredProgress;
                final opacity = scale.clamp(0.0, 1.0);

                if (opacity <= 0) return const SizedBox.shrink();

                return Positioned(
                  bottom: 12 - y,
                  right: 72 - x,
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: _buildChildFAB(
                        context,
                        liquidGlassMode,
                        isDark,
                        theme,
                        index,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main FAB
          Positioned(
            bottom: 0,
            right: 72,
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _expandController,
                builder: (context, child) {
                  // Morph main FAB when expanding - squeeze and twist
                  final expandProgress = _expandController.value;
                  final squeeze = 1.0 - (expandProgress * 0.1);
                  final rotate = expandProgress * 0.1;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(squeeze, squeeze)
                      ..rotateZ(rotate),
                    child: _buildMainFAB(
                      context,
                      liquidGlassMode,
                      isDark,
                      glowColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainFAB(
    BuildContext context,
    LiquidGlassMode mode,
    bool isDark,
    Color glowColor,
  ) {
    final theme = Theme.of(context);
    final morphValue = _morphController.value;
    final morphAmount = math.sin(morphValue * math.pi * 2) * 0.1;
    final morphRadius = (widget.mainFABSize / 2) + (morphAmount * 6);

    if (mode == LiquidGlassMode.disabled) {
      return Container(
        width: widget.mainFABSize,
        height: widget.mainFABSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.4),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: _isExpanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 28),
        ),
      );
    }

    if (mode == LiquidGlassMode.fake) {
      return Container(
        width: widget.mainFABSize,
        height: widget.mainFABSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.9),
                    Colors.white.withValues(alpha: 0.5),
                  ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: glowColor.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: _isExpanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 28),
        ),
      );
    }

    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      width: widget.mainFABSize,
      height: widget.mainFABSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.3),
            blurRadius: 48,
            spreadRadius: 8,
          ),
        ],
      ),
      child: LiquidGlass.withOwnLayer(
        settings: LiquidGlassSettings(
          thickness: 12,
          blur: 6,
          glassColor: baseColor.withValues(alpha: 0.4),
          lightIntensity: 1.4,
          saturation: 1.2,
          refractiveIndex: 1.45,
          outlineIntensity: 1.0,
          lightAngle: -0.75,
        ),
        shape: LiquidRoundedSuperellipse(borderRadius: morphRadius),
        child: Center(
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              Icons.add,
              color: theme.colorScheme.onPrimary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildFAB(
    BuildContext context,
    LiquidGlassMode mode,
    bool isDark,
    ThemeData theme,
    int index,
  ) {
    final option = widget.options[index];
    final color = option.color ?? theme.colorScheme.primary;
    final morphValue = _morphController.value;
    final morphAmount = math.sin(morphValue * math.pi * 2 + index * 0.5) * 0.08;
    final morphRadius = (widget.childFABSize / 2) + (morphAmount * 4);

    final Widget fab = Tooltip(
      message: option.label,
      child: GestureDetector(
        onTap: () {
          _toggle();
          option.onTap();
        },
        child: Container(
          width: widget.childFABSize,
          height: widget.childFABSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: mode == LiquidGlassMode.disabled
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: Icon(option.icon, color: Colors.white, size: 22),
                )
              : mode == LiquidGlassMode.fake
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.3),
                              Colors.white.withValues(alpha: 0.1),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.6),
                            ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(option.icon, color: color, size: 22),
                )
              : LiquidGlass.withOwnLayer(
                  settings: LiquidGlassSettings(
                    thickness: 8,
                    blur: 4,
                    glassColor: (isDark ? Colors.white : Colors.white)
                        .withValues(alpha: 0.3),
                    lightIntensity: 1.2,
                    saturation: 1.1,
                    refractiveIndex: 1.45,
                    outlineIntensity: 1.0,
                    lightAngle: -0.75,
                  ),
                  shape: LiquidRoundedSuperellipse(borderRadius: morphRadius),
                  child: Center(
                    child: Icon(option.icon, color: color, size: 22),
                  ),
                ),
        ),
      ),
    );

    return fab;
  }
}

/// Extension for easy usage
extension LiquidFABClusterExtension on List<LiquidFABOption> {
  Widget asLiquidFABCluster({
    double mainFABSize = 56,
    double childFABSize = 48,
    Color? mainGlowColor,
    double animationDuration = 500,
  }) {
    return LiquidFABCluster(
      options: this,
      mainFABSize: mainFABSize,
      childFABSize: childFABSize,
      mainGlowColor: mainGlowColor,
      animationDuration: animationDuration,
    );
  }
}
