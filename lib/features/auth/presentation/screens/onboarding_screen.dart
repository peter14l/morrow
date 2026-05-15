import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart'
    as system_icons;
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:oasis/services/app_initializer.dart';
import 'package:oasis/themes/theme_provider.dart';

/// Onboarding Screen
/// Displays a multi-page introduction to the app's key features
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// Key for storing whether user has seen onboarding
  static const String hasSeenOnboardingKey = 'has_seen_onboarding';

  /// Check if user has completed onboarding
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(hasSeenOnboardingKey) ?? false;
  }

  /// Mark onboarding as complete
  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(hasSeenOnboardingKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  double _scrollOffset = 0.0;
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    const OnboardingPageData(
      icon: system_icons.FluentIcons.chat_multiple_24_filled,
      title: 'Connect Securely',
      description:
          'Share your life through Feed and Stories, and chat privately with world-class end-to-end encryption.',
      colors: [material.Color(0xFF6B9EFF), material.Color(0xFF8E54E9)],
    ),
    const OnboardingPageData(
      icon: system_icons.FluentIcons.board_24_filled,
      title: 'Creative Canvas',
      description:
          'Experience a new way to create together. Interact in real-time on a shared canvas with timelines and audio.',
      colors: [material.Color(0xFFF093FB), material.Color(0xFFF5576C)],
    ),
    const OnboardingPageData(
      icon: system_icons.FluentIcons.video_clip_24_filled,
      title: 'Mindful Discovery',
      description:
          'Discover short-form videos through Ripples, designed with digital wellbeing limits to keep your usage healthy.',
      colors: [material.Color(0xFF4FACFE), material.Color(0xFF00F2FE)],
    ),
    const OnboardingPageData(
      icon: system_icons.FluentIcons.heart_pulse_24_filled,
      title: 'Time & Wellness',
      description:
          'Connect with your future self using Time Capsules and monitor your digital habits in the Wellness Center.',
      colors: [material.Color(0xFFF6D365), material.Color(0xFFFDA085)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutQuint,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await OnboardingScreen.setOnboardingComplete();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return material.Scaffold(
      body: Stack(
        children: [
          // Dynamic Background
          _buildDynamicBackground(),

          // Glassmorphic Content
          SafeArea(
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Builder(
                      builder: (context) {
                        return material.TextButton(
                          onPressed: _completeOnboarding,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: material.Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], index);
                    },
                  ),
                ),

                // Footer
                _buildFooter(isLastPage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBackground() {
    final int nextIndex = (_scrollOffset.ceil()).clamp(0, _pages.length - 1);
    final int prevIndex = (_scrollOffset.floor()).clamp(0, _pages.length - 1);
    final double t = _scrollOffset - prevIndex;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            material.Color.lerp(
              _pages[prevIndex].colors[0],
              _pages[nextIndex].colors[0],
              t,
            )!,
            material.Color.lerp(
              _pages[prevIndex].colors[1],
              _pages[nextIndex].colors[1],
              t,
            )!,
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page, int index) {
    final isCurrent = index == _currentPage;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final disableTransparency = themeProvider.isM3ETransparencyDisabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon with Pulse Effect
          Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: material.Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: material.Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: material.Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(page.icon, size: 80, color: material.Colors.white),
              )
              .animate(target: isCurrent ? 1 : 0)
              .scale(
                duration: 600.ms,
                curve: Curves.easeOutBack,
                begin: const Offset(0.5, 0.5),
              )
              .fadeIn()
              .shimmer(
                delay: 800.ms,
                duration: 1500.ms,
                color: material.Colors.white24,
              ),

          const SizedBox(height: 60),

          // Glassmorphic Content Box
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: disableTransparency
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: material.Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: material.Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: _buildOnboardingPageContent(page, isCurrent),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: material.Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: material.Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: _buildOnboardingPageContent(page, isCurrent),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPageContent(OnboardingPageData page, bool isCurrent) {
    return Column(
      children: [
        Text(
              page.title,
              style: const TextStyle(
                color: material.Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 28,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            )
            .animate(target: isCurrent ? 1 : 0)
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.2, curve: Curves.easeOutQuad),

        const SizedBox(height: 20),

        Text(
              page.description,
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.9),
                height: 1.6,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            )
            .animate(target: isCurrent ? 1 : 0)
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.2, curve: Curves.easeOutQuad),
      ],
    );
  }

  Widget _buildFooter(bool isLastPage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
      child: Column(
        children: [
          // Animated Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isActive ? 32 : 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive
                      ? material.Colors.white
                      : material.Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),

          const SizedBox(height: 48),

          // Primary Action Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child:
                Builder(
                      builder: (context) {
                        return material.ElevatedButton(
                          onPressed: _onNextPage,
                          style: material.ElevatedButton.styleFrom(
                            backgroundColor: material.Colors.white,
                            foregroundColor: _pages[_currentPage].colors[1],
                            elevation: 0,
                            shape: material.RoundedRectangleBorder(
                              borderRadius: material.BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            isLastPage ? 'GET STARTED' : 'CONTINUE',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        );
                      },
                    )
                    .animate(target: isLastPage ? 1 : 0)
                    .shake(delay: 200.ms, duration: 500.ms),
          ),
        ],
      ),
    );
  }
}

/// Data class for onboarding page content
class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<material.Color> colors;

  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
  });
}
