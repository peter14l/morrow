import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:oasis/core/theme/oasis_colors.dart';

class OnboardingCelebrationScreen extends StatefulWidget {
  const OnboardingCelebrationScreen({super.key});

  @override
  State<OnboardingCelebrationScreen> createState() => _OnboardingCelebrationScreenState();
}

class _OnboardingCelebrationScreenState extends State<OnboardingCelebrationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();

    // Auto navigate to feed after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        context.go('/feed');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasisColors.deep,
      body: Stack(
        children: [
          // Centered content
          Center(
            child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OasisColors.sage.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: OasisColors.glow.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: OasisColors.glow,
                        size: 80,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Welcome to your Oasis.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your data is yours again.',
                      style: TextStyle(
                        color: OasisColors.mist,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
          ),
          
          // Confetti overlay at top center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2, // blast downwards
              maxBlastForce: 20, 
              minBlastForce: 5, 
              emissionFrequency: 0.05,
              numberOfParticles: 30, // a lot of confetti
              gravity: 0.2,
              colors: const [
                OasisColors.glow,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }
}
