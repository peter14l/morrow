import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:oasis/services/vault_service.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class VaultSettingsScreen extends material.StatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  material.State<VaultSettingsScreen> createState() =>
      _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends material.State<VaultSettingsScreen> {
  bool _isLoading = true;
  bool _isEnabled = false;
  final _pinController = material.TextEditingController();
  final _formKey = material.GlobalKey<material.FormState>();

  @override
  void initState() {
    super.initState();
    _checkVaultStatus();
  }

  Future<void> _checkVaultStatus() async {
    try {
      final service = Provider.of<VaultService>(context, listen: false);
      final enabled = await service.isVaultEnabled();
      if (mounted) {
        setState(() {
          _isEnabled = enabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      material.debugPrint('Error checking vault status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.showError(context, e);
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _enableVault() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = Provider.of<VaultService>(context, listen: false);
      await service.enableVault(pin: _pinController.text);
      await _checkVaultStatus();
      if (mounted) {
        CustomSnackbar.showSuccess(context, 'Vault enabled successfully');
        _pinController.clear();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disableVault() async {
    // Require PIN to disable
    final confirmed = await _showPinDialog(context);
    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final service = Provider.of<VaultService>(context, listen: false);
      await service.disableVault();
      await _checkVaultStatus();
      if (mounted) {
        CustomSnackbar.showSuccess(context, 'Vault disabled');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showPinDialog(material.BuildContext context) async {
    final controller = material.TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS;

    if (themeProvider.useFluentUI && isDesktop) {
      final result = await fluent.showDialog<bool>(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const material.Text('Enter PIN'),
          content: fluent.TextBox(
            controller: controller,
            placeholder: 'Current PIN',
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            fluent.Button(
              onPressed: () => material.Navigator.pop(context, false),
              child: const material.Text('Cancel'),
            ),
            fluent.FilledButton(
              onPressed: () async {
                final service = Provider.of<VaultService>(
                  context,
                  listen: false,
                );
                final isValid = await service.unlockVaultWithPin(
                  controller.text,
                );
                if (context.mounted) {
                  material.Navigator.pop(context, isValid);
                }
              },
              child: const material.Text('Confirm'),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    final result = await material.showDialog<bool>(
      context: context,
      builder: (context) => material.AlertDialog(
        title: const material.Text('Enter PIN'),
        content: material.TextField(
          controller: controller,
          keyboardType: material.TextInputType.number,
          obscureText: true,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const material.InputDecoration(
            hintText: 'Current PIN',
            counterText: '',
          ),
        ),
        actions: [
          material.TextButton(
            onPressed: () => material.Navigator.pop(context, false),
            child: const material.Text('Cancel'),
          ),
          material.TextButton(
            onPressed: () async {
              final service = Provider.of<VaultService>(context, listen: false);
              final isValid = await service.unlockVaultWithPin(controller.text);
              if (context.mounted) {
                material.Navigator.pop(context, isValid);
              }
            },
            child: const material.Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showChangePinDialog(
    material.BuildContext context,
    VaultService service,
  ) async {
    final currentPinController = material.TextEditingController();
    final newPinController = material.TextEditingController();
    final confirmPinController = material.TextEditingController();
    String? errorMessage;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS;

    if (themeProvider.useFluentUI && isDesktop) {
      final result = await fluent.showDialog<bool>(
        context: context,
        builder: (dialogContext) => material.StatefulBuilder(
          builder: (context, setDialogState) => fluent.ContentDialog(
            title: const material.Text('Change PIN'),
            content: material.Column(
              mainAxisSize: material.MainAxisSize.min,
              children: [
                fluent.TextBox(
                  controller: currentPinController,
                  placeholder: 'Current PIN',
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const material.SizedBox(height: 16),
                fluent.TextBox(
                  controller: newPinController,
                  placeholder: 'New PIN',
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const material.SizedBox(height: 16),
                fluent.TextBox(
                  controller: confirmPinController,
                  placeholder: 'Confirm New PIN',
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (errorMessage != null) ...[
                  const material.SizedBox(height: 16),
                  material.Text(
                    errorMessage!,
                    style: const material.TextStyle(
                      color: material.Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              fluent.Button(
                onPressed: () => material.Navigator.pop(dialogContext, false),
                child: const material.Text('Cancel'),
              ),
              fluent.FilledButton(
                onPressed: () async {
                  if (currentPinController.text.length != 4) {
                    setDialogState(
                      () => errorMessage = 'Please enter current PIN',
                    );
                    return;
                  }
                  if (newPinController.text.length != 4) {
                    setDialogState(
                      () => errorMessage = 'New PIN must be 4 digits',
                    );
                    return;
                  }
                  if (newPinController.text != confirmPinController.text) {
                    setDialogState(
                      () => errorMessage = 'New PINs do not match',
                    );
                    return;
                  }
                  final success = await service.changePin(
                    currentPinController.text,
                    newPinController.text,
                  );
                  if (success) {
                    material.Navigator.pop(dialogContext, true);
                  } else {
                    setDialogState(
                      () => errorMessage = 'Current PIN is incorrect',
                    );
                  }
                },
                child: const material.Text('Change'),
              ),
            ],
          ),
        ),
      );
      if (result == true && mounted) {
        CustomSnackbar.showSuccess(context, 'PIN changed successfully!');
      }
      return;
    }

    final result = await material.showDialog<bool>(
      context: context,
      builder: (dialogContext) => material.StatefulBuilder(
        builder: (context, setDialogState) => material.AlertDialog(
          title: const material.Text('Change PIN'),
          content: material.Column(
            mainAxisSize: material.MainAxisSize.min,
            children: [
              material.TextField(
                controller: currentPinController,
                keyboardType: material.TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const material.InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                ),
              ),
              const material.SizedBox(height: 16),
              material.TextField(
                controller: newPinController,
                keyboardType: material.TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const material.InputDecoration(
                  labelText: 'New PIN',
                  counterText: '',
                ),
              ),
              const material.SizedBox(height: 16),
              material.TextField(
                controller: confirmPinController,
                keyboardType: material.TextInputType.number,
                obscureText: true,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const material.InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                ),
              ),
              if (errorMessage != null) ...[
                const material.SizedBox(height: 16),
                material.Text(
                  errorMessage!,
                  style: const material.TextStyle(
                    color: material.Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            material.TextButton(
              onPressed: () => material.Navigator.pop(dialogContext, false),
              child: const material.Text('Cancel'),
            ),
            material.TextButton(
              onPressed: () async {
                if (currentPinController.text.length != 4) {
                  setDialogState(
                    () => errorMessage = 'Please enter current PIN',
                  );
                  return;
                }
                if (newPinController.text.length != 4) {
                  setDialogState(
                    () => errorMessage = 'New PIN must be 4 digits',
                  );
                  return;
                }
                if (newPinController.text != confirmPinController.text) {
                  setDialogState(() => errorMessage = 'New PINs do not match');
                  return;
                }
                if (currentPinController.text == newPinController.text) {
                  setDialogState(
                    () => errorMessage = 'New PIN must be different',
                  );
                  return;
                }

                final success = await service.changePin(
                  currentPinController.text,
                  newPinController.text,
                );

                if (success) {
                  material.Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(
                    () => errorMessage = 'Current PIN is incorrect',
                  );
                }
              },
              child: const material.Text('Change'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      CustomSnackbar.showSuccess(context, 'PIN changed successfully!');
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS;

    if (_isLoading) {
      return const material.Scaffold(
        body: material.Center(child: material.CircularProgressIndicator()),
      );
    }

    final content = material.ListView(
      padding: material.EdgeInsets.all(isDesktop ? 40 : 16),
      children: [
        material.Center(
          child: material.Container(
            constraints: const material.BoxConstraints(maxWidth: 800),
            child: material.Column(
              crossAxisAlignment: material.CrossAxisAlignment.start,
              children: [
                material.Container(
                  padding: const material.EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: material.BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: material.BorderRadius.circular(16),
                  ),
                  child: material.Column(
                    children: [
                      material.Icon(
                        _isEnabled
                            ? material.Icons.lock
                            : material.Icons.lock_open,
                        size: 64,
                        color: _isEnabled
                            ? theme.colorScheme.primary
                            : material.Colors.grey,
                      ),
                      const material.SizedBox(height: 16),
                      material.Text(
                        _isEnabled ? 'Vault is Enabled' : 'Vault is Disabled',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const material.SizedBox(height: 8),
                      material.Text(
                        _isEnabled
                            ? 'Your private content is secured locally'
                            : 'Enable vault to hide sensitive content',
                        textAlign: material.TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const material.SizedBox(height: 32),
                if (!_isEnabled) ...[
                  material.Text(
                    'Setup Vault',
                    style: theme.textTheme.titleMedium,
                  ),
                  const material.SizedBox(height: 16),
                  material.Form(
                    key: _formKey,
                    child: material.TextFormField(
                      controller: _pinController,
                      keyboardType: material.TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const material.InputDecoration(
                        labelText: 'Set a 4-digit PIN',
                        border: material.OutlineInputBorder(),
                        prefixIcon: material.Icon(material.Icons.pin),
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.length != 4) {
                          return 'Please enter a 4-digit PIN';
                        }
                        return null;
                      },
                    ),
                  ),
                  const material.SizedBox(height: 24),
                  material.SizedBox(
                    width: double.infinity,
                    child: material.FilledButton.icon(
                      onPressed: _enableVault,
                      icon: const material.Icon(material.Icons.shield),
                      label: const material.Text('Enable Vault'),
                      style: material.FilledButton.styleFrom(
                        padding: const material.EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ] else ...[
                  material.Container(
                    decoration: material.BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: material.BorderRadius.circular(16),
                      border: material.Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: material.Column(
                      children: [
                        material.ListTile(
                          leading: const material.Icon(material.Icons.password),
                          title: const material.Text('Change PIN'),
                          trailing: const material.Icon(
                            material.Icons.chevron_right,
                          ),
                          onTap: () {
                            final service = Provider.of<VaultService>(
                              context,
                              listen: false,
                            );
                            _showChangePinDialog(context, service);
                          },
                        ),
                        const material.Divider(height: 1),
                        material.ListTile(
                          leading: const material.Icon(
                            material.Icons.delete_outline,
                          ),
                          title: const material.Text('Disable Vault'),
                          subtitle: const material.Text(
                            'This will unhide all secluded content',
                          ),
                          textColor: theme.colorScheme.error,
                          iconColor: theme.colorScheme.error,
                          onTap: _disableVault,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (themeProvider.useFluentUI && isDesktop) {
      return fluent.ScaffoldPage(
        header: const fluent.PageHeader(title: material.Text('Vault Settings')),
        content: material.Material(
          color: material.Colors.transparent,
          child: content,
        ),
      );
    }

    return material.Scaffold(
      appBar: material.AppBar(title: const material.Text('Vault Settings')),
      body: content,
    );
  }
}
