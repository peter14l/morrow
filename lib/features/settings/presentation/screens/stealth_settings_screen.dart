import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/settings/presentation/providers/decoy_provider.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_group.dart';
import 'package:oasis/features/settings/presentation/widgets/settings_tile.dart';

class StealthSettingsScreen extends StatefulWidget {
  const StealthSettingsScreen({super.key});

  @override
  State<StealthSettingsScreen> createState() => _StealthSettingsScreenState();
}

class _StealthSettingsScreenState extends State<StealthSettingsScreen> {
  Future<void> _toggleStealthMode(bool enable, DecoyProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (enable) {
      // Prompt setup PIN
      final newPin = await _showSetupPinDialog();
      if (newPin != null) {
        final success = await provider.enableDecoy(newPin);
        if (mounted && success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Stealth Mode enabled! Disguised as Calendar.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // Prompt verification PIN to disable
      final verified = await _showVerifyPinDialog(
        title: 'Disable Stealth Mode',
        subtitle: 'Enter your 6-digit PIN to disable Stealth Mode',
      );
      if (verified) {
        final success = await provider.disableDecoy();
        if (mounted && success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Stealth Mode disabled. Normal icon restored.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _changePin(DecoyProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // 1. Verify current PIN
    final currentVerified = await _showVerifyPinDialog(
      title: 'Verify Current PIN',
      subtitle: 'Enter your current 6-digit PIN',
    );
    if (!currentVerified) return;

    // 2. Prompt for new PIN
    final newPin = await _showSetupPinDialog(title: 'Enter New PIN');
    if (newPin == null) return;

    // 3. Update PIN
    final currentPin = await _showInputPinOnlyDialog(
      title: 'Current PIN Again',
      subtitle: 'Re-enter your current PIN to confirm changes',
    );
    if (currentPin == null) return;

    final success = await provider.changePin(currentPin, newPin);
    if (mounted) {
      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('PIN successfully changed!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to change PIN. Verify current PIN.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showSetupPinDialog({String title = 'Setup Security PIN'}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SetupPinDialog(title: title),
    );
  }

  Future<bool> _showVerifyPinDialog({required String title, required String subtitle}) async {
    final decoyProvider = context.read<DecoyProvider>();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VerifyPinDialog(title: title, subtitle: subtitle),
    );
    if (pin == null) return false;
    return decoyProvider.verifyPin(pin);
  }

  Future<String?> _showInputPinOnlyDialog({required String title, required String subtitle}) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VerifyPinDialog(title: title, subtitle: subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final decoyProvider = Provider.of<DecoyProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Stealth Mode'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stealth Disguise',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Disguise Oasis on your phone as a fully functional Calendar app. '
                    'To open Oasis, perform a triple-finger swipe down gesture '
                    'on the Calendar screen and enter your 6-digit PIN.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.vpn_key_outlined,
                title: 'Stealth Mode',
                subtitle: decoyProvider.isDecoyEnabled
                    ? 'Oasis is currently disguised'
                    : 'Disguise the app logo and name',
                trailing: Switch.adaptive(
                  value: decoyProvider.isDecoyEnabled,
                  onChanged: (val) => _toggleStealthMode(val, decoyProvider),
                ),
              ),
              if (decoyProvider.isDecoyEnabled)
                SettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: 'Change Security PIN',
                  subtitle: 'Update your 6-digit unlock PIN',
                  onTap: () => _changePin(decoyProvider),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper PIN Setup Dialog
// ---------------------------------------------------------------------------

class _SetupPinDialog extends StatefulWidget {
  final String title;
  const _SetupPinDialog({required this.title});

  @override
  State<_SetupPinDialog> createState() => _SetupPinDialogState();
}

class _SetupPinDialogState extends State<_SetupPinDialog> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isConfirming = false;
  String _firstPin = '';
  String? _error;

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
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
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

  void _handleSubmit() {
    final pin = _currentPin;
    if (pin.length < 6) return;

    if (!_isConfirming) {
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
        _error = null;
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    } else {
      if (pin == _firstPin) {
        Navigator.pop(context, pin);
      } else {
        setState(() {
          _error = 'PINs do not match. Restarting setup.';
          _isConfirming = false;
          _firstPin = '';
          for (var c in _controllers) {
            c.clear();
          }
          _focusNodes[0].requestFocus();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(
        _isConfirming ? 'Confirm PIN' : widget.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isConfirming
                ? 'Re-enter your 6-digit PIN to confirm'
                : 'Create a 6-digit PIN to protect access to Oasis',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 32,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 1,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
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
            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper PIN Verification Dialog
// ---------------------------------------------------------------------------

class _VerifyPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  const _VerifyPinDialog({required this.title, required this.subtitle});

  @override
  State<_VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<_VerifyPinDialog> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_currentPin.length == 6) {
      Navigator.pop(context, _currentPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 32,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 1,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    counterText: '',
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onChanged(value, index),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
