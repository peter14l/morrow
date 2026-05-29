import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/oasis_colors.dart';
import '../../../core/theme/oasis_text_styles.dart';

class Page5Contacts extends StatefulWidget {
  final bool isActive;
  const Page5Contacts({super.key, required this.isActive});

  @override
  State<Page5Contacts> createState() => _Page5ContactsState();
}

class _Page5ContactsState extends State<Page5Contacts> {
  bool _granted = false;
  bool _checking = false;

  Future<void> _requestPermission() async {
    setState(() => _checking = true);
    try {
      final status = await Permission.contacts.request();
      if (status.isGranted) {
        setState(() => _granted = true);
      }
    } catch (e) {
      debugPrint('[ContactsPermission] Error requesting contacts: $e');
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          'FIND YOUR PEOPLE',
          style: OasisTextStyles.onboardingSubtitle.copyWith(
            fontSize: 11,
            color: OasisColors.glow,
            letterSpacing: 2.5,
            fontWeight: FontWeight.bold,
          ),
        ).animate(target: widget.isActive ? 1 : 0).fadeIn().slideX(begin: -0.1),
        const SizedBox(height: 10),
        Text(
          'Connect with Friends\non Oasis',
          textAlign: TextAlign.center,
          style: OasisTextStyles.onboardingHeadline.copyWith(
            fontSize: 36,
            height: 1.2,
          ),
        )
            .animate(target: widget.isActive ? 1 : 0)
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.06),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OasisColors.sage.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: OasisColors.sage.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 48,
                  color: OasisColors.glow,
                ),
                const SizedBox(height: 16),
                Text(
                  'Privacy-First Contacts Search',
                  style: OasisTextStyles.onboardingHeadline.copyWith(
                    fontSize: 18,
                    color: OasisColors.sand,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Allows Oasis to find which of your contacts are already here. We normalize and hash your contacts' phone numbers & emails locally on your device before matching, so your raw address book never leaves your phone.",
                  textAlign: TextAlign.center,
                  style: OasisTextStyles.onboardingSubtitle.copyWith(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _granted
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: OasisColors.glow),
                          const SizedBox(width: 8),
                          Text(
                            'Contacts Access Enabled',
                            style: OasisTextStyles.ctaLabel.copyWith(
                              color: OasisColors.glow,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: _checking ? null : _requestPermission,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: OasisColors.glow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _checking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      OasisColors.deep,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Enable Access',
                                  style: OasisTextStyles.ctaLabel.copyWith(
                                    color: OasisColors.deep,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
              ],
            ),
          ).animate(target: widget.isActive ? 1 : 0).fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
        ),
        const Spacer(),
        Text(
          'You control who you connect with.',
          style: OasisTextStyles.onboardingHeadline.copyWith(
            fontSize: 16,
            color: OasisColors.sand.withOpacity(0.55),
          ),
        ).animate(target: widget.isActive ? 1 : 0).fadeIn(delay: 800.ms),
        const SizedBox(height: 40),
      ],
    );
  }
}
