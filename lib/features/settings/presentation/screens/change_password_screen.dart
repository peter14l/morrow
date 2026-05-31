import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/core/utils/responsive_layout.dart';
import 'package:oasis/widgets/app_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null || currentUser.email.isEmpty) {
        throw Exception('User email not found. Cannot verify current password.');
      }

      // Verify current password by attempting sign in
      try {
        await authService.signInWithEmailAndPassword(
          currentUser.email,
          _currentPasswordController.text,
        );
      } catch (e) {
        throw Exception('Current password is incorrect.');
      }

      // Update to new password
      await authService.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    final content = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 64, color: Colors.teal),
          const SizedBox(height: 24),
          const Text(
            'Change Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your password must be at least 6 characters long.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              labelText: 'Current Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your current password';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a new password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              if (value == _currentPasswordController.text) {
                return 'New password cannot be the same as the current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your new password';
              if (value != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          AppButton.primary(
            onPressed: _isLoading ? () {} : _handleChangePassword,
            text: 'Change Password',
            isLoading: _isLoading,
            width: double.infinity,
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: MaxWidthContainer(
            maxWidth: 500,
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: content,
      ),
    );
  }
}
