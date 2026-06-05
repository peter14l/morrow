import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oasis/features/auth/presentation/screens/pin_reset_screen.dart';
import 'package:oasis/core/extensions/context_extensions.dart';

class RecoveryKeySheet extends StatefulWidget {
  final String?
  recoveryKey; // If provided, shows the key (Mode 1). If null, prompts for entry (Mode 2).
  final bool isConfirmMode;

  const RecoveryKeySheet({
    super.key,
    this.recoveryKey,
    this.isConfirmMode = false,
  });

  static Future<String?> show(
    BuildContext context, {
    String? recoveryKey,
    bool isConfirmMode = false,
  }) {
    return context.showResponsiveSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecoveryKeySheet(
        recoveryKey: recoveryKey,
        isConfirmMode: isConfirmMode,
      ),
    );
  }

  @override
  State<RecoveryKeySheet> createState() => _RecoveryKeySheetState();
}

class _RecoveryKeySheetState extends State<RecoveryKeySheet> {
  late final TextEditingController _controller;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isDisplayMode = widget.recoveryKey != null;
    final isSolid = ContextX(context).shouldUseSolidBackground;
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
          Icon(
            isDisplayMode ? Icons.key : Icons.keyboard,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            isDisplayMode ? 'Your Recovery Key' : 'Enter Recovery Key',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isDisplayMode
                ? 'If you forget your PIN, this key is the ONLY way to recover your messages. Save it in a safe place (like a password manager).'
                : 'Enter your 24-character recovery key to restore access to your messages.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (isDisplayMode) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SelectableText(
                widget.recoveryKey!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.recoveryKey!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recovery key copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy to Clipboard'),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _hasSaved,
              onChanged: (val) => setState(() => _hasSaved = val ?? false),
              title: const Text(
                'I have saved this recovery key in a safe place',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hasSaved
                    ? () => Navigator.pop(context, widget.recoveryKey)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'ABCD-1234-...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.key),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) {
                setState(() {});
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _controller.text.length >= 24
                    ? () => Navigator.pop(context, _controller.text)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Verify Recovery Key'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PINResetScreen()),
                );
              },
              child: const Text('Lost your recovery code?'),
            ),
          ],
        ],
      ),
    );
  }
}
