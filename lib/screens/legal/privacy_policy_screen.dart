import 'package:oasis/core/config/app_config.dart';
import 'package:flutter/material.dart';

/// Privacy Policy Screen
/// Displays the app's privacy policy with proper formatting
class PrivacyPolicyScreen extends StatelessWidget {
  /// Optional callback when user accepts the policy (for registration flow)
  final VoidCallback? onAccept;

  /// Whether this is being shown during registration (shows accept button)
  final bool showAcceptButton;

  const PrivacyPolicyScreen({
    super.key,
    this.onAccept,
    this.showAcceptButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final webDomain = AppConfig.webBaseUrl
        .replaceAll('https://', '')
        .replaceAll('http://', '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oasis Privacy Policy',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: April 2026',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSection(
                    context,
                    '1. Data Sovereignty & Minimization',
                    '''Oasis is designed with "Privacy by Architecture." We follow the principle of data minimization:

• We only collect the absolute minimum data required to provide the service.
• Direct messages and media are End-to-End Encrypted (E2EE).
• We do not track your location in the background unless explicitly enabled for specific features (like the Pulse Map).
• We do not sell, rent, or trade your personal data to any third party, ever.''',
                  ),

                  _buildSection(
                    context,
                    '2. Information We Collect (Data Categories)',
                    '''To comply with the Indian DPDP Act (2023) and GDPR, we disclose the following categories of data processed:

• Account Identifiers: Email, username, and hashed credentials.
• Encrypted Content: Your messages and media (stored in encrypted form; we do not hold the keys).
• Cryptographic Metadata: Public keys and salt used for your E2EE identity.
• Subscription Data: Managed via Razorpay/RevenueCat to process payments (we do not store your credit card numbers locally).
• Device Telemetry: Opt-in crash reports (Sentry) and basic device type for compatibility.''',
                  ),

                  _buildSection(
                    context,
                    '3. End-to-End Encryption (E2EE)',
                    '''Your privacy is mathematically protected:

• Messages and media are encrypted using RSA-2048 and AES-256 before leaving your device.
• Your private key is encrypted with a key derived from your PIN using the Argon2id protocol.
• IMPORTANT: Because we do not store your PIN or your unencrypted private key, we cannot recover your messages if you lose both your PIN and your recovery code.''',
                  ),

                  _buildSection(
                    context,
                    '4. Your Rights (DPDP & GDPR Compliance)',
                    '''You have full control over your digital footprint:

• Right to Erasure: You can delete your account and all associated data instantly from Settings.
• Data Portability: You can request a full export of your data (Technical Manifest).
• Right to Correction: You can update your profile information at any time.
• Right to Withdraw Consent: You can toggle sync for analytics and wellness data at any time.''',
                  ),

                  _buildSection(
                    context,
                    '5. Children\'s Privacy (Verifiable Consent)',
                    '''Oasis is intended for users aged 13 and older. 

• For users between 13 and 18, we may require verifiable parental consent in certain jurisdictions (like India under the DPDP Act).
• We do not engage in behavioral tracking or targeted advertising directed at minors.''',
                  ),

                  _buildSection(
                    context,
                    '6. Data Storage & Local-First Media',
                    '''Oasis prioritizes on-device storage:

• Your shared media is stored locally by default. 
• Cloud backups are an optional opt-in feature to protect your data during device loss.
• Data stored on our servers is protected by Row Level Security (RLS) at the database engine level.''',
                  ),

                  _buildSection(
                    context,
                    '7. Wellness & Intentionality Data',
                    '''Digital wellbeing data (Screen Time, Energy Meter) is processed primarily on your device. We do not use this data for profiling or third-party marketing.''',
                  ),

                  _buildSection(
                    context,
                    '8. Contact our Data Protection Officer',
                    '''For legal inquiries or data requests:
• Email: privacy@oasis.com
• Address: Oasis Tech Support, Delhi, India.''',
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          if (showAcceptButton)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('I Accept'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
