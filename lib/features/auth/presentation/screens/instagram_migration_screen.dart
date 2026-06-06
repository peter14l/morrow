import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:oasis/features/auth/presentation/providers/auth_provider.dart';
import 'package:oasis/features/profile/presentation/providers/profile_provider.dart';
import 'package:oasis/services/instagram_migration_service.dart';
import 'package:oasis/widgets/app_button.dart';
import 'package:oasis/widgets/custom_text_field.dart';
import 'package:oasis/core/theme/oasis_colors.dart';
import 'package:oasis/core/theme/oasis_text_styles.dart';

class InstagramMigrationScreen extends StatefulWidget {
  const InstagramMigrationScreen({super.key});

  @override
  State<InstagramMigrationScreen> createState() => _InstagramMigrationScreenState();
}

class _InstagramMigrationScreenState extends State<InstagramMigrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _migrationService = InstagramMigrationService();

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _usernameFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _bioFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isProcessingZip = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  String? _zipPath;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessZip() async {
    setState(() => _isProcessingZip = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        _zipPath = result.files.single.path;
        final success = await _migrationService.preProcessZip(_zipPath!);

        if (success) {
          setState(() {
            _usernameController.text = _migrationService.username ?? '';
            _nameController.text = _migrationService.fullName ?? '';
            _bioController.text = _migrationService.bio ?? '';
            _emailController.text = _migrationService.email ?? '';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_migrationService.currentStatus)),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    } finally {
      setState(() => _isProcessingZip = false);
    }
  }

  Future<void> _finishMigrationAndRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Sign up the user
      await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim().toLowerCase(),
        fullName: _nameController.text.trim(),
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // 2. Upload profile photo if present
        String? avatarUrl;
        if (_migrationService.profilePhotoFile != null) {
          avatarUrl = await _migrationService.uploadProfilePhoto(user.id);
        }

        // 3. Update public profile details (Bio & Avatar)
        if (mounted) {
          await context.read<ProfileProvider>().updateProfile(
            userId: user.id,
            fullName: _nameController.text.trim(),
            bio: _bioController.text.trim(),
            username: _usernameController.text.trim().toLowerCase(),
            avatarFilePath: _migrationService.profilePhotoFile?.path,
          );
        }

        // 4. Start background posts import (runs asynchronously)
        _migrationService.startBackgroundPostMigration(user.id, _migrationService.availablePosts);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile migrated successfully! Posts syncing in background.'),
            ),
          );
          context.go('/feed');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Migration/Registration failed: $e')),
      );
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: OasisColors.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context) ?? context.go('/register'),
        ),
        title: const Text(
          'Instagram to Oasis',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Migrate Your Account',
                style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Move your profile picture, bio, and posts securely without sharing your Instagram password.',
                style: OasisTextStyles.onboardingSubtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Step 1: Upload instructions & button
              if (_zipPath == null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: OasisColors.sage.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OasisColors.sage.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to get your Instagram export:',
                        style: TextStyle(
                          color: OasisColors.glow,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStepItem('1.', 'Go to Settings -> Your Activity -> Download your information on Instagram.'),
                      _buildStepItem('2.', "Select 'All available information', set Format to 'JSON', and Media Quality to 'High'."),
                      _buildStepItem('3.', 'Submit request. Instagram will email you a ZIP file once generated.'),
                      _buildStepItem('4.', 'Download the ZIP, select it here, and we will do the rest!'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AppButton.primary(
                  text: 'Select Instagram ZIP',
                  onPressed: _isProcessingZip ? null : _pickAndProcessZip,
                  isLoading: _isProcessingZip,
                ),
              ] else ...[
                // Step 2: Display Extracted Profile and Registration Fields
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: OasisColors.sage.withOpacity(0.2),
                        backgroundImage: _migrationService.profilePhotoFile != null
                            ? FileImage(_migrationService.profilePhotoFile!)
                            : null,
                        child: _migrationService.profilePhotoFile == null
                            ? const Icon(Icons.person, size: 54, color: OasisColors.mist)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: OasisColors.glow,
                          child: Icon(Icons.camera_alt, color: OasisColors.deep, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  hint: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  hint: 'Username',
                  prefixIcon: Icons.alternate_email,
                  validator: (val) => val == null || val.isEmpty ? 'Username is required' : null,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _bioController,
                  focusNode: _bioFocus,
                  hint: 'Bio',
                  prefixIcon: Icons.chat_bubble_outline,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  hint: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: 'Create Oasis Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 32),

                // Step 3: Post Selection UI
                if (_migrationService.availablePosts.isNotEmpty) ...[
                  Text(
                    'Select Posts to Migrate',
                    style: OasisTextStyles.onboardingHeadline.copyWith(fontSize: 20),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which posts to import. Type a Circle name below a post to auto-create a private Circle for it, or leave blank for your main feed.',
                    style: OasisTextStyles.onboardingSubtitle,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _migrationService.availablePosts.length,
                      itemBuilder: (context, index) {
                        final post = _migrationService.availablePosts[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: OasisColors.sage.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: post.isSelected ? OasisColors.glow : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                  child: Image.file(
                                    post.tempMediaFile,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: post.isSelected,
                                          activeColor: OasisColors.glow,
                                          onChanged: (val) {
                                            setState(() {
                                              post.isSelected = val ?? false;
                                            });
                                          },
                                        ),
                                        const Expanded(child: Text('Import', style: TextStyle(color: Colors.white, fontSize: 12))),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 32,
                                      child: TextField(
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'Circle Name (Optional)',
                                          hintStyle: TextStyle(color: OasisColors.mist, fontSize: 10),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (val) {
                                          post.targetCircleName = val.trim();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                AppButton.primary(
                  text: 'Finish Migration & Register',
                  onPressed: _isRegistering ? null : _finishMigrationAndRegister,
                  isLoading: _isRegistering,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _zipPath = null;
                      _migrationService.reset();
                    });
                  },
                  child: const Text('Reset / Change File', style: TextStyle(color: OasisColors.mist)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(color: OasisColors.glow, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: OasisColors.mist, fontSize: 13, height: 1.45))),
        ],
      ),
    );
  }
}
