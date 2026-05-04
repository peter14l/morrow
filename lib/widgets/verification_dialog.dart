import 'package:flutter/material.dart';
import 'package:oasis/core/utils/haptic_utils.dart';

/// Verification dialog shown when user arrives home.
///
/// Asks: "Did you actually reach home?"
///
/// Flow:
/// 1. Show on app open after home arrival detected
/// 2. User taps "Yes" → confirm check-in, plays heartbeat haptic
/// 3. User taps "No" → warn partner, plays warning haptic
class VerificationDialog extends StatelessWidget {
  /// Called when user confirms "Yes, I reached home"
  final VoidCallback? onConfirm;

  /// Called when user denies "No, I didn't reach home"
  final VoidCallback? onDeny;

  const VerificationDialog({
    super.key,
    this.onConfirm,
    this.onDeny,
  });

  /// Show as a modal dialog
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onConfirm,
    VoidCallback? onDeny,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => VerificationDialog(
        onConfirm: onConfirm,
        onDeny: onDeny,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Heart/Home icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home_rounded,
                size: 40,
                color: Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Did you actually reach home?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Tap "Yes" to confirm your arrival and let your partner know you\'re safe.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Yes button (primary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Play heartbeat haptic pattern
                  await HapticUtils.heartbeatPulse();
                  if (onConfirm != null) {
                    onConfirm!();
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_rounded),
                    SizedBox(width: 8),
                    Text(
                      'Yes, I\'m home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // No button (secondary)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  // Play warning haptic pattern
                  await HapticUtils.warningPulse();
                  if (onDeny != null) {
                    onDeny!();
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).textTheme.bodySmall?.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded),
                    SizedBox(width: 8),
                    Text(
                      'No, not yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
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
}