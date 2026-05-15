import 'package:flutter/material.dart';

class AuthLayoutWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? topBar;
  final bool wrapInScroll;

  const AuthLayoutWrapper({
    super.key,
    required this.child,
    this.topBar,
    this.wrapInScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The content constrained
    final contentContainer = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: wrapInScroll ? SingleChildScrollView(child: child) : child,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        if (screenWidth >= 1000) {
          // Desktop Layout - Split screen
          return Scaffold(
            backgroundColor: const Color(0xFF0C0F14), // Dark base
            body: Row(
              children: [
                // Left Panel - Branding
                Expanded(
                  flex: 1,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 80,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Oasis',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Connecting your world',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right Panel - Forms
                Expanded(
                  flex: 1,
                  child: Container(
                    color: const Color(0xFF111318),
                    child: ClipRect(
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        appBar: topBar,
                        body: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: contentContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile/Tablet Layout - Simple and clean over dark background
          return Scaffold(
            backgroundColor: const Color(0xFF111318), // Deep dark for auth
            appBar: topBar,
            body: Stack(
              children: [SafeArea(child: Center(child: contentContainer))],
            ),
          );
        }
      },
    );
  }
}
