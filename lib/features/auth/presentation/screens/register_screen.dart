import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasis/widgets/app_button.dart';
import 'package:oasis/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/auth/presentation/widgets/auth_layout_wrapper.dart';

import 'package:oasis/widgets/security_pin_sheet.dart';
import 'package:oasis/features/messages/data/encryption_service.dart';
import 'package:oasis/core/config/app_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _hasAcceptedTerms = false;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim().toLowerCase(),
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // --- NEW: Security PIN Setup for E2E Encryption ---
        if (mounted) {
          final pinSuccess = await SecurityPinSheet.show(
            context, 
            EncryptionStatus.needsSetup
          );
          
          if (pinSuccess != true) {
            // If they cancel PIN setup, we still let them in, but they'll 
            // see the "Upgrade Security" banner later.
            debugPrint('User skipped initial PIN setup.');
          }
        }

        try {
          // Note: signUp already sends the confirmation email if enabled in Supabase.
          // Explicit resend here is only needed if the user requests it later,
          // but doing it immediately after signUp can cause rate limit errors.

          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Verify Your Email'),
                    content: Text(
                      'A verification email has been sent to ${user.email}. '
                      'Please verify your email to continue using the app. '
                      'You can verify later from your profile settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (mounted) {
                            context.go('/feed');
                          }
                        },
                        child: const Text('Continue to App'),
                      ),
                    ],
                  ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! You can verify your email later from profile settings.',
                ),
              ),
            );
            context.go('/feed');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please sign in.'),
            ),
          );
          context.go('/login');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Registration error: $e');
      debugPrint('Registration stack trace: $stackTrace');
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // Log specific error for debugging
        debugPrint('[RegisterScreen] Detailed error message: $errorMessage');
        
        // Handle specific SMTP failure from Supabase
        if (errorMessage.contains('Error sending confirmation email')) {
          errorMessage = 'The app failed to send a verification email. Please check the email address or try again later.';
          
          // Provide additional help in a dialog if it's a known configuration issue
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email Error'),
              content: const Text(
                'We encountered an issue sending your confirmation email. This is usually due to a configuration problem with the email service.\n\n'
                'Please contact support or try a different email address.',
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $errorMessage'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AuthLayoutWrapper(
      wrapInScroll: true,
      topBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Sign up',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _nameController,
                focusNode: _nameFocus,
                hint: 'Name',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_usernameFocus);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                hint: 'Username',
                prefixIcon: Icons.alternate_email,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_emailFocus);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  if (value.contains(' ')) {
                    return 'Username cannot contain spaces';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_passwordFocus);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                hint: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 16),
              // --- Terms and Conditions Checkbox ---
              material.Theme(
                data: theme.copyWith(unselectedWidgetColor: colorScheme.onSurfaceVariant),
                child: CheckboxListTile(
                  value: _hasAcceptedTerms,
                  onChanged: (val) => setState(() => _hasAcceptedTerms = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: colorScheme.primary,
                  title: Wrap(
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/terms'),
                        child: Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(
                        ' and ',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppButton.primary(
                text: 'Sign up with Password',
                onPressed: (_isLoading || !_hasAcceptedTerms) ? null : _register,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16.0),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Color(0xFF9DA6B9), fontSize: 14),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: Color(0xFF1152D4),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
