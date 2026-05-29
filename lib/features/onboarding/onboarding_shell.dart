import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';
import 'widgets/oasis_background.dart';
import 'pages/page1_welcome.dart';
import 'pages/page2_slow_social.dart';
import 'pages/page3_canvas.dart';
import 'pages/page4_wellbeing.dart';
import 'pages/page5_contacts.dart';
import 'pages/page5_cta.dart';
import '../auth/presentation/screens/onboarding_screen.dart';

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key});

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final page = _pageController.page?.round();
      if (page != null && page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onSkip() {
    _pageController.animateToPage(
      5,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _completeOnboarding({String route = '/login'}) async {
    await OnboardingScreen.setOnboardingComplete();
    if (mounted) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == 5;

    return Scaffold(
      body: OasisBackground(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                return PageView.builder(
                  controller: _pageController,
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    double offset = 0.0;
                    if (_pageController.position.haveDimensions) {
                      offset = (_pageController.page ?? 0) - index;
                    }

                    final scale = 1.0 - (offset.abs() * 0.04);
                    final opacity = 1.0 - (offset.abs() * 0.3);

                    return Transform.scale(
                      scale: scale.clamp(0.9, 1.0),
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: _buildPage(index),
                      ),
                    );
                  },
                );
              },
            ),

            if (!isLastPage)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _onSkip,
                        child: Text(
                          'Skip',
                          style: OasisTextStyles.onboardingSubtitle.copyWith(
                            color: OasisColors.mist,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: 6,
                        effect: const WormEffect(
                          activeDotColor: OasisColors.glow,
                          dotColor: OasisColors.sage,
                          dotHeight: 6,
                          dotWidth: 6,
                          spacing: 8,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _onNext,
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: OasisColors.glow,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return Page1Welcome(isActive: _currentPage == 0);
      case 1:
        return Page2SlowSocial(isActive: _currentPage == 1);
      case 2:
        return Page3Canvas(isActive: _currentPage == 2);
      case 3:
        return Page4Wellbeing(isActive: _currentPage == 3);
      case 4:
        return Page5Contacts(isActive: _currentPage == 4);
      case 5:
        return Page5CTA(
          isActive: _currentPage == 5,
          onComplete: () => _completeOnboarding(route: '/register'),
          onSignIn: () => _completeOnboarding(route: '/login'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
