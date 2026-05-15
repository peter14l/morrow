import 'package:flutter/material.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/security_pin_sheet.dart';

class SecurityUpgradeBanner extends StatefulWidget {
  const SecurityUpgradeBanner({super.key});

  @override
  State<SecurityUpgradeBanner> createState() => _SecurityUpgradeBannerState();
}

class _SecurityUpgradeBannerState extends State<SecurityUpgradeBanner> {
  EncryptionStatus? _status;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await EncryptionService().init();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null ||
        (_status != EncryptionStatus.needsSecurityUpgrade &&
            _status != EncryptionStatus.needsRecoveryBackup)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isRecoveryOnly = _status == EncryptionStatus.needsRecoveryBackup;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isRecoveryOnly
            ? Colors.orange.withValues(alpha: 0.9)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isRecoveryOnly
                ? Colors.orange
                : theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRecoveryOnly
                ? Icons.warning_amber_rounded
                : Icons.security_rounded,
            color: isRecoveryOnly
                ? Colors.black87
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRecoveryOnly
                      ? 'Complete Backup Setup'
                      : 'Upgrade Chat Security',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isRecoveryOnly
                        ? Colors.black87
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isRecoveryOnly
                      ? 'Protect your account with a recovery key.'
                      : 'Set a PIN to secure your chat backups.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isRecoveryOnly
                        ? Colors.black87
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await SecurityPinSheet.show(context, _status!);
              if (success == true) _checkStatus();
            },
            child: Text(
              isRecoveryOnly ? 'SETUP NOW' : 'UPGRADE',
              style: TextStyle(
                color: isRecoveryOnly
                    ? Colors.black
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
