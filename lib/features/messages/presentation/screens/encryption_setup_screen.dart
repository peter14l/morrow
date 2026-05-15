import 'package:flutter/material.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/recovery_key_sheet.dart';

class EncryptionSetupScreen extends StatefulWidget {
  final bool isRestore;

  const EncryptionSetupScreen({super.key, this.isRestore = false});

  @override
  State<EncryptionSetupScreen> createState() => _EncryptionSetupScreenState();
}

class _EncryptionSetupScreenState extends State<EncryptionSetupScreen> {
  final EncryptionService _encryptionService = EncryptionService();

  bool _isLoading = false;
  bool _restoreFailed = false;
  bool _isAlreadyActive = false;
  String? _errorMessage;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialState();
    });
  }

  Future<void> _checkInitialState() async {
    if (_encryptionService.isInitialized) {
      if (mounted) setState(() => _isAlreadyActive = true);
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final status = await _encryptionService.init();
    if (status == EncryptionStatus.ready) {
      if (mounted) {
        setState(() {
          _isAlreadyActive = true;
          _isLoading = false;
        });
      }
      return;
    }

    // Otherwise, start the actual setup
    if (mounted) _runSetup();
  }

  Future<void> _runSetup({bool forceNewKeys = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _restoreFailed = false;
    });

    try {
      bool success = false;
      String? recoveryKey;

      if (forceNewKeys) {
        // User chose to generate brand-new keys (loses old message decryption)
        setState(() {
          _isAlreadyActive = false;
          _progressMessage = 'Generating new encryption keys…';
        });
        success = await _encryptionService.generateNewKeys();
        if (!success) {
          setState(() {
            _errorMessage =
                'Failed to generate new keys. Please check your connection and try again.';
            _isLoading = false;
          });
          return;
        }
      } else if (widget.isRestore) {
        // Step-by-step restore with progress feedback
        setState(() => _progressMessage = 'Fetching your encrypted backup…');
        await Future.delayed(
          const Duration(milliseconds: 200),
        ); // Let UI update

        setState(() => _progressMessage = 'Decrypting your keys…');
        success = await _encryptionService.restoreKeys();

        if (!success) {
          setState(() {
            _restoreFailed = true;
            _errorMessage =
                'Could not restore your keys automatically. This may happen if:\n'
                '• You are on a new device\n'
                '• Your backup is missing or corrupted\n\n'
                'You can try again or generate new keys (old messages will remain locked).';
            _isLoading = false;
          });
          return;
        }
      } else {
        setState(() => _progressMessage = 'Generating encryption keys…');
        final result = await _encryptionService.setupEncryption();
        success = result.success;
        recoveryKey = result.recoveryKey;

        if (!success) {
          setState(() {
            _errorMessage =
                'Failed to set up encryption. Please check your connection and try again.';
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        if (recoveryKey != null) {
          await RecoveryKeySheet.show(context, recoveryKey: recoveryKey);
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon — animated spinner while loading, lock icon otherwise
            Center(
              child: _isLoading
                  ? SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      _restoreFailed
                          ? Icons.lock_reset
                          : (_isAlreadyActive
                                ? Icons.gpp_good
                                : Icons.security),
                      size: 80,
                      color: _restoreFailed
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
            ),

            const SizedBox(height: 24),

            Text(
              _isAlreadyActive
                  ? 'End-to-End Encrypted'
                  : widget.isRestore
                  ? (_restoreFailed ? 'Restore Failed' : 'Restoring Your Keys')
                  : 'Setting Up Security',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Progress message shown while loading
            if (_isLoading && _progressMessage.isNotEmpty)
              Text(
                _progressMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

            // Description when idle and not failed
            if (!_isLoading && !_restoreFailed)
              Text(
                _isAlreadyActive
                    ? 'Secure encryption keys have already been generated. Your text messages are now end-to-end encrypted.'
                    : widget.isRestore
                    ? 'We are restoring your secure encryption keys from your backup. This happens seamlessly using your unique identity.'
                    : 'We are generating secure encryption keys for your account. These will be backed up automatically to your secure profile.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 32),

            // Error box
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Primary button or Done button
            if (_isAlreadyActive)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16)),
              )
            else
              FilledButton(
                onPressed: _isLoading ? null : _runSetup,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _restoreFailed
                            ? 'Try Again'
                            : widget.isRestore
                            ? 'Restore Access'
                            : 'Enable Encryption',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),

            // Fallback button: Generate new keys
            if ((_restoreFailed || _isAlreadyActive) && !_isLoading) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _showGenerateNewKeysConfirmation(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Generate New Keys',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              'Your messages are end-to-end encrypted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (isDesktop) return Material(color: Colors.transparent, child: content);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRestore ? 'Restore Access' : 'Secure Messages'),
        // Don't allow dismissal mid-operation
        automaticallyImplyLeading: !_isLoading,
      ),
      body: content,
    );
  }

  void _showGenerateNewKeysConfirmation(BuildContext ctx) {
    showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Generate New Keys?'),
        content: const Text(
          'This will create a fresh set of encryption keys and upload them to your account.\n\n'
          '⚠️  Previous encrypted messages will no longer be readable since your old private key will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop(true);
            },
            child: const Text('Generate New Keys'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _runSetup(forceNewKeys: true);
      }
    });
  }
}
