import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/features/messages/data/signal/signal_service.dart';
import 'package:oasis/widgets/recovery_key_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen for resetting chat encryption PIN when user has forgotten PIN
/// and lost their recovery code. Uses email/password for identity verification.
class PINResetScreen extends StatefulWidget {
  const PINResetScreen({super.key});

  @override
  State<PINResetScreen> createState() => _PINResetScreenState();
}

class _PINResetScreenState extends State<PINResetScreen> {
  final _supabase = Supabase.instance.client;

  // Step tracking: 0=email/password, 1=warning, 2=new PIN, 3=processing, 4=success
  int _currentStep = 0;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final List<TextEditingController> _pinControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<TextEditingController> _confirmPinControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  // Focus nodes
  final List<FocusNode> _pinFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  final List<FocusNode> _confirmPinFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  final List<FocusNode> _keyboardFocusNodes = List.generate(
    12,
    (index) => FocusNode(),
  );

  // State
  bool _isLoading = false;
  String? _error;
  bool _isConfirmingPin = false;
  String _firstPin = '';
  bool _understandsDataLoss = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    for (var c in _pinControllers) c.dispose();
    for (var c in _confirmPinControllers) c.dispose();
    for (var n in _pinFocusNodes) n.dispose();
    for (var n in _confirmPinFocusNodes) n.dispose();
    for (var n in _keyboardFocusNodes) n.dispose();
    super.dispose();
  }

  String get _currentPin => _pinControllers.map((c) => c.text).join();
  String get _confirmPin => _confirmPinControllers.map((c) => c.text).join();

  void _onPinChanged(String value, int index, bool isConfirm) {
    setState(() {}); // Ensure UI rebuilds to update button enabled state

    if (value.length == 1) {
      if (isConfirm && index < 5) {
        _confirmPinFocusNodes[index + 1].requestFocus();
      } else if (!isConfirm && index < 5) {
        _pinFocusNodes[index + 1].requestFocus();
      }
    }
  }

  Future<void> _verifyIdentity() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verify credentials by attempting to sign in
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.session == null) {
        // Sign in failed - invalid credentials
        setState(() {
          _error = 'Invalid email or password';
          _isLoading = false;
        });
        return;
      }

      // Credentials verified - move to warning step
      if (mounted) {
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Verification failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewKeys() async {
    final pin = _confirmPin;
    if (pin.length != 6) return;

    setState(() {
      _currentStep = 3;
      _isLoading = true;
      _error = null;
    });

    try {
      final encryptionService = EncryptionService();
      final result = await encryptionService.generateNewKeysWithPin(pin);

      if (mounted) {
        if (result.success) {
          // Reset Signal identity as old sessions are now invalid
          try {
            final signalService = SignalService();
            await signalService.clearData();
            await signalService.init();
          } catch (e) {
            debugPrint('[Signal] Reset error during PIN change: $e');
          }

          // Show recovery key
          if (result.recoveryKey != null) {
            await RecoveryKeySheet.show(
              context,
              recoveryKey: result.recoveryKey,
            );
          }
          setState(() {
            _currentStep = 4;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Failed to generate new keys. Please try again.';
            _currentStep = 2;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred. Please try again.';
          _currentStep = 2;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset PIN'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _buildStepContent(theme)),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildEmailVerification(theme);
      case 1:
        return _buildWarning(theme);
      case 2:
        return _buildNewPinEntry(theme);
      case 3:
        return _buildProcessing(theme);
      case 4:
        return _buildSuccess(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmailVerification(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            'Verify Your Identity',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your email and password to verify your identity before resetting your PIN.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outlined),
            ),
            enabled: !_isLoading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _verifyIdentity,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify Identity'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Important Warning',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.error.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 32,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Resetting your PIN will make your old encrypted messages permanently inaccessible.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This cannot be undone. Your previous messages are encrypted with your old PIN and cannot be recovered.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _understandsDataLoss,
            onChanged: (val) =>
                setState(() => _understandsDataLoss = val ?? false),
            title: const Text(
              'I understand my old messages will be lost forever',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !_understandsDataLoss
                ? null
                : () {
                    setState(() {
                      _currentStep = 2;
                    });
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('I Understand - Continue'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _understandsDataLoss = false;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPinEntry(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.pin_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            _isConfirmingPin ? 'Confirm New PIN' : 'Set New PIN',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _isConfirmingPin
                ? 'Re-enter your 6-digit PIN to confirm'
                : 'Enter a new 6-digit PIN to protect your messages',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // PIN Entry (either first entry or confirmation)
          if (!_isConfirmingPin) ...[
            _buildPinInput(
              'New PIN',
              _pinControllers,
              _pinFocusNodes,
              false,
              theme,
            ),
          ] else ...[
            _buildPinInput(
              'Confirm PIN',
              _confirmPinControllers,
              _confirmPinFocusNodes,
              true,
              theme,
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          if (!_isConfirmingPin)
            FilledButton(
              onPressed: _currentPin.length == 6
                  ? () {
                      if (_currentPin.length == 6) {
                        setState(() {
                          _firstPin = _currentPin;
                          _isConfirmingPin = true;
                          for (var c in _pinControllers) {
                            c.clear();
                          }
                          _pinFocusNodes[0].requestFocus();
                        });
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Continue'),
            )
          else
            FilledButton(
              onPressed: _confirmPin.length == 6
                  ? () {
                      if (_confirmPin != _firstPin) {
                        setState(() {
                          _error = 'PINs do not match. Try again.';
                          _firstPin = '';
                          _isConfirmingPin = false;
                          for (var c in _confirmPinControllers) {
                            c.clear();
                          }
                          _pinFocusNodes[0].requestFocus();
                        });
                      } else {
                        _generateNewKeys();
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Set New PIN'),
            ),
        ],
      ),
    );
  }

  Widget _buildPinInput(
    String label,
    List<TextEditingController> controllers,
    List<FocusNode> focusNodes,
    bool isConfirm,
    ThemeData theme,
  ) {
    // Determine which managed focus nodes to use for KeyboardListener
    final keyboardNodesOffset = isConfirm ? 6 : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        6,
        (index) => SizedBox(
          width: 45,
          child: KeyboardListener(
            focusNode: _keyboardFocusNodes[keyboardNodesOffset + index],
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  controllers[index].text.isEmpty &&
                  index > 0) {
                focusNodes[index - 1].requestFocus();
              }
            },
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 1,
              style: theme.textTheme.headlineMedium,
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => _onPinChanged(value, index, isConfirm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 64),
          const CircularProgressIndicator(),
          const SizedBox(height: 32),
          Text(
            'Generating New Keys',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please wait while we generate new encryption keys for you...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'PIN Reset Complete',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your new PIN has been set. You can now access your messages with your new PIN.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Remember: Your old messages are now inaccessible. '
                  'Make sure to save your new recovery key in a safe place!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              // Navigate back to app - user should be logged in already
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Continue to App'),
          ),
        ],
      ),
    );
  }
}
