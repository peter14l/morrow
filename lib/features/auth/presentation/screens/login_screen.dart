import 'package:flutter/material.dart';
// import 'package:passkeys/passkeys.dart' as pk;
import 'package:provider/provider.dart';
import 'package:oasis/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasis/features/auth/presentation/widgets/auth_layout_wrapper.dart';
import 'package:oasis/widgets/app_button.dart';
import 'package:oasis/core/config/app_config.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isResettingPassword = false;
  bool _showPasswordField = false;
  bool _emailSubmitted = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your username or email address first'),
        ),
      );
      return;
    }

    setState(() => _isResettingPassword = true);
    try {
      await context.read<AuthProvider>().resetPassword(identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _onEmailSubmitted() async {
    if (_identifierController.text.trim().isEmpty) return;
    
    setState(() {
      _showPasswordField = true;
      _emailSubmitted = true;
    });
  }

  Future<void> _loginWithEmailAndPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoggingIn = true);
      try {
        debugPrint('[LoginScreen] Starting sign in...');
        await context.read<AuthProvider>().signInWithEmail(
          email: _identifierController.text.trim(),
          password: _passwordController.text,
        );
        debugPrint('[LoginScreen] Sign in completed');
        
        if (mounted) {
          context.go('/feed');
        }
      } catch (e) {
        debugPrint('[LoginScreen] Sign in failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _isLoggingIn = false);
      }
    }
  }

  Future<void> _showGoogleSetPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Set Password for Google Account'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter the email associated with your Google account. We\'ll send a password reset link to set your password.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                final email = emailController.text.trim();

                                if (email.isEmpty || !email.contains('@')) {
                                  setDialogState(
                                    () =>
                                        errorMessage =
                                            'Please enter a valid email',
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                  successMessage = null;
                                });

                                try {
                                  // Use full URL for redirectTo - Supabase requires full URL, not just scheme
                                  // The actual deep link handling is done by the app via App Links/Universal Links
                                  await Supabase.instance.client.auth
                                      .resetPasswordForEmail(
                                        email,
                                        redirectTo:
                                            AppConfig.getWebUrl('/reset-password'),
                                      );

                                  setDialogState(() {
                                    successMessage =
                                        'Password reset email sent! Check your inbox.';
                                  });

                                  await Future.delayed(
                                    const Duration(seconds: 2),
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                    _showPasswordSetInstructions(
                                      context,
                                      email,
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(
                                    () => errorMessage = e.toString(),
                                  );
                                } finally {
                                  setDialogState(() => isLoading = false);
                                }
                              },
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Continue'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showPasswordSetInstructions(BuildContext context, String email) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Check Your Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We sent a password reset link to $email'),
                const SizedBox(height: 12),
                const Text(
                  '📋 Instructions:\n'
                  '1. Click the link in the email\n'
                  '2. You\'ll be taken to a password reset page in the app\n'
                  '3. Enter a new password\n'
                  '4. After setting password, sign in with your email + new password',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final accounts = authProvider.registeredAccounts;
    
    return AuthLayoutWrapper(
      wrapInScroll: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Your Accounts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              final authService = context.read<AuthService>();
                              await authService.switchAccount(context, account.userId);
                              if (mounted) {
                                context.go('/feed');
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to switch: $e')),
                                );
                              }
                            }
                          },
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: (account.avatarUrl ?? '').isNotEmpty
                                    ? NetworkImage(account.avatarUrl!)
                                    : null,
                                child: (account.avatarUrl ?? '').isEmpty
                                    ? Text(account.username[0].toUpperCase())
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                account.username,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ),
                    Expanded(child: Divider(color: Colors.white24)),
                  ],
                ),
              ],
              const SizedBox(height: 16.0),
              Text(
                'Welcome Back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Sign in to continue',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48.0),
              
              // Email Field - Always visible
              TextFormField(
                controller: _identifierController,
                decoration: InputDecoration(
                  labelText: 'Username or Email',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: _emailSubmitted ? IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () {
                      setState(() {
                        _emailSubmitted = false;
                        _showPasswordField = false;
                      });
                    },
                  ) : null,
                ),
                readOnly: _emailSubmitted,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _onEmailSubmitted(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username or email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16.0),
              
              // Animated logic for Password options
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_emailSubmitted 
                  ? AppButton.primary(
                      key: const ValueKey('continue_button'),
                      text: 'Continue',
                      isLoading: _isLoggingIn,
                      onPressed: _onEmailSubmitted,
                    )
                  : Column(
                      key: const ValueKey('auth_options_column'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _loginWithEmailAndPassword(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                (_isLoggingIn || _isResettingPassword)
                                    ? null
                                    : _resetPassword,
                            child:
                                _isResettingPassword
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                    : const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppButton.primary(
                          text: 'Sign In',
                          isLoading: _isLoggingIn,
                          onPressed: _loginWithEmailAndPassword,
                        ),
                      ],
                    ),
              ),
              
              const SizedBox(height: 8.0),
              // Google users: set password link
              if (!_emailSubmitted || _showPasswordField)
                TextButton(
                  onPressed:
                      (_isLoggingIn || _isResettingPassword)
                          ? null
                          : () => _showGoogleSetPasswordDialog(context),
                  child: const Text(
                    'Signed up with Google? Set a password',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16.0),
              TextButton(
                onPressed:
                    (_isLoggingIn || _isResettingPassword)
                        ? null
                        : () {
                          final addAccount =
                              GoRouterState.of(
                                context,
                              ).uri.queryParameters['add_account'];
                          if (addAccount == 'true') {
                            context.go('/register?add_account=true');
                          } else {
                            context.go('/register');
                          }
                        },
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
