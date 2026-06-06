import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/widgets/recovery_key_sheet.dart';
import 'package:oasis/features/auth/presentation/screens/pin_reset_screen.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

class SecurityPinSheet extends StatefulWidget {
  final EncryptionStatus status;
  final Function(bool success)? onComplete;

  const SecurityPinSheet({super.key, required this.status, this.onComplete});

  static Future<bool?> show(BuildContext context, EncryptionStatus status) {
    return context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SecurityPinSheet(status: status),
    );
  }

  @override
  State<SecurityPinSheet> createState() => _SecurityPinSheetState();
}

class _SecurityPinSheetState extends State<SecurityPinSheet> {
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
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _focusNodes[i - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

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

  Future<void> _handleSubmit() async {
    final pin = _currentPin;
    if (pin.length < 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final encryptionService = context.read<EncryptionService>();
      bool success = false;

      if (widget.status == EncryptionStatus.needsSetup ||
          widget.status == EncryptionStatus.needsSecurityUpgrade ||
          widget.status == EncryptionStatus.needsRecoveryBackup) {
        if (!_isConfirming &&
            widget.status != EncryptionStatus.needsRecoveryBackup) {
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
          if (!_isConfirming &&
              widget.status == EncryptionStatus.needsRecoveryBackup) {
            // For recovery backup, we just need to verify the existing PIN
            // So no double-entry needed if they are just backing up.
          } else if (pin != _firstPin) {
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
            // Both needsSecurityUpgrade and needsRecoveryBackup use upgradeSecurity
            // upgradeSecurity will verify the PIN by attempting to decrypt the backup Slot
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
        if (mounted) {
          Navigator.pop(context, true);
          widget.onComplete?.call(true);
        }
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

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

    final isSolid = context.shouldUseSolidBackground;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 32, 24, 32 + bottomPadding),
      decoration: BoxDecoration(
        color: isSolid
            ? (isDark ? const Color(0xFF1A1D24) : Colors.white)
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 45,
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onChanged(value, index),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (widget.status == EncryptionStatus.needsRestore &&
              !_isLoading) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PINResetScreen()),
                );
              },
              child: const Text('Forgot PIN?'),
            ),
          ],
          const SizedBox(height: 16),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            const SizedBox(height: 48), // Spacer to maintain layout
        ],
      ),
    );
  }
}
