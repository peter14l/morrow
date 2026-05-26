import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/recovery_key_sheet.dart';
import 'package:oasis/features/auth/presentation/screens/pin_reset_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EncryptionPinOverlay extends StatefulWidget {
  final EncryptionStatus status;
  final VoidCallback onComplete;

  const EncryptionPinOverlay({
    super.key,
    required this.status,
    required this.onComplete,
  });

  @override
  State<EncryptionPinOverlay> createState() => _EncryptionPinOverlayState();
}

class _EncryptionPinOverlayState extends State<EncryptionPinOverlay> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  String? _error;
  bool _isConfirming = false;
  String _firstPin = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_currentPin.length == 6) {
      _handleSubmit();
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleSubmit() async {
    final pin = _currentPin;
    if (pin.length < 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final encryptionService = context.read<EncryptionService>();
      bool success = false;

      if (widget.status == EncryptionStatus.needsSetup ||
          widget.status == EncryptionStatus.needsSecurityUpgrade) {
        if (!_isConfirming) {
          setState(() {
            _firstPin = pin;
            _isConfirming = true;
            _isLoading = false;
            for (var c in _controllers) {
              c.clear();
            }
            _focusNodes[0].requestFocus();
          });
          return;
        } else {
          if (pin != _firstPin) {
            setState(() {
              _error = 'PINs do not match. Try again.';
              _isConfirming = false;
              _firstPin = '';
              for (var c in _controllers) {
                c.clear();
              }
              _focusNodes[0].requestFocus();
              _isLoading = false;
            });
            return;
          }

          String? recoveryKey;
          if (widget.status == EncryptionStatus.needsSetup) {
            final result = await encryptionService.setupEncryption(pin: pin);
            success = result.success;
            recoveryKey = result.recoveryKey;
          } else {
            final result = await encryptionService.upgradeSecurity(pin);
            success = result.success;
            recoveryKey = result.recoveryKey;

            if (!success) {
              setState(() {
                _isLoading = false;
                _error = 'Incorrect PIN. Please try again.';
                for (var c in _controllers) {
                  c.clear();
                }
                _focusNodes[0].requestFocus();
              });
              return;
            }
          }

          if (success && recoveryKey != null) {
            if (mounted) {
              await RecoveryKeySheet.show(context, recoveryKey: recoveryKey);
            }
          }
        }
      } else if (widget.status == EncryptionStatus.needsRestore) {
        success = await encryptionService.restoreSecureKeys(pin);
        if (!success) {
          _error = 'Incorrect PIN. Please try again.';
        }
      }

      if (success) {
        widget.onComplete();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String title = 'Security PIN';
    String subtitle = 'Enter your 6-digit PIN';

    if (widget.status == EncryptionStatus.needsSetup) {
      title = _isConfirming ? 'Confirm PIN' : 'Setup Security PIN';
      subtitle = _isConfirming
          ? 'Re-enter your 6-digit PIN'
          : 'Create a PIN to protect your encrypted messages';
    } else if (widget.status == EncryptionStatus.needsSecurityUpgrade) {
      title = _isConfirming ? 'Confirm PIN' : 'Upgrade Security';
      subtitle = _isConfirming
          ? 'Re-enter your new PIN'
          : 'Set a 6-digit PIN to secure your chat backups';
    } else if (widget.status == EncryptionStatus.needsRestore) {
      title = 'Restore Chats';
      subtitle = 'Enter your 6-digit Security PIN to access your messages';
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Glassmorphic Backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
              ),
            ),

            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_person_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                      ).animate().scale(
                        duration: 400.ms,
                        curve: Curves.easeOutBack,
                      ),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // PIN Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: 45,
                            child: KeyboardListener(
                              focusNode: FocusNode(),
                              onKeyEvent: (event) => _onKeyEvent(event, index),
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
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
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) => _onChanged(value, index),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().shake(),
                      ],

                      const SizedBox(height: 48),

                      // Loading or Buttons
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else if (widget.status == EncryptionStatus.needsRestore)
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PINResetScreen(),
                              ),
                            );
                          },
                          child: const Text('Forgot PIN?'),
                        ),

                      const SizedBox(height: 24),

                      // Branding
                      Opacity(
                        opacity: 0.5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.spa_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Oasis Vault Protection',
                              style: TextStyle(
                                letterSpacing: 1.2,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
