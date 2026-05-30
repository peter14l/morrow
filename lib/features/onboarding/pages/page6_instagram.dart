import 'package:flutter/material.dart';
import '../../../../core/theme/oasis_colors.dart';
import '../../../../core/theme/oasis_text_styles.dart';

class Page6Instagram extends StatelessWidget {
  final bool isActive;

  const Page6Instagram({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE1306C).withOpacity(0.2),
                    const Color(0xFFC13584).withOpacity(0.2),
                    OasisColors.glow.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.import_export,
                size: 72,
                color: OasisColors.glow,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Migrate from Instagram',
              style: OasisTextStyles.onboardingHeadline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Import your profile picture, bio, and posts via a secure ZIP file. No Instagram password required.',
              style: OasisTextStyles.onboardingSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildInstructionItem('1', 'Request data download on Instagram (JSON format)'),
            _buildInstructionItem('2', 'Receive the ZIP file via email'),
            _buildInstructionItem('3', 'Select the ZIP file during signup to populate your profile'),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String step, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: OasisColors.glow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: OasisColors.deep,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: OasisTextStyles.onboardingSubtitle.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
