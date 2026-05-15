import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:oasis/services/community_service.dart';
import 'package:oasis/services/auth_service.dart';
import 'package:oasis/widgets/custom_snackbar.dart';

class CommunityPrivacyModerationScreen extends StatefulWidget {
  final String name;
  final String theme;
  final String description;
  final String rules;

  const CommunityPrivacyModerationScreen({
    super.key,
    required this.name,
    required this.theme,
    required this.description,
    required this.rules,
  });

  @override
  State<CommunityPrivacyModerationScreen> createState() =>
      _CommunityPrivacyModerationScreenState();
}

class _CommunityPrivacyModerationScreenState
    extends State<CommunityPrivacyModerationScreen> {
  bool _isPrivate = false;
  bool _requireApproval = true;
  bool _allowUserPosts = true;
  bool _allowUserComments = true;
  bool _nsfwContent = false;
  bool _isLoading = false;
  final _communityService = CommunityService();

  Future<void> _onCreateCommunity() async {
    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user == null) {
        if (mounted) {
          CustomSnackbar.showError(context, 'Error: User not authenticated');
        }
        return;
      }

      // Create community with backend
      final community = await _communityService.createCommunity(
        creatorId: user.id,
        name: widget.name,
        description: widget.description,
        rules: widget.rules,
        isPrivate: _isPrivate,
      );

      if (!mounted) return;

      // Pass data to confirmation screen, including the new ID
      final communityData = {
        'id': community.id,
        'name': community.name,
        'theme': widget.theme,
        'description': community.description,
        'rules': widget.rules,
        'isPrivate': community.isPrivate,
        'requireApproval': _requireApproval,
        'allowUserPosts': _allowUserPosts,
        'allowUserComments': _allowUserComments,
        'nsfwContent': _nsfwContent,
        'createdAt': community.createdAt,
      };

      // Navigate to confirmation screen
      context.push('/community/create/confirmation', extra: communityData);
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Privacy & Moderation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              title: 'Private Community',
              subtitle:
                  'Only approved members can view and participate in this community',
              value: _isPrivate,
              onChanged: (value) {
                setState(() {
                  _isPrivate = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              title: 'Require Approval to Join',
              subtitle: 'New members must be approved by a moderator',
              value: _requireApproval,
              onChanged: (value) {
                setState(() {
                  _requireApproval = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Content Moderation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              title: 'Allow User Posts',
              subtitle: 'Members can create posts in this community',
              value: _allowUserPosts,
              onChanged: (value) {
                setState(() {
                  _allowUserPosts = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              title: 'Allow User Comments',
              subtitle: 'Members can comment on posts in this community',
              value: _allowUserComments,
              onChanged: (value) {
                setState(() {
                  _allowUserComments = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              title: 'NSFW Content',
              subtitle:
                  'This community contains content intended for mature audiences',
              value: _nsfwContent,
              onChanged: (value) {
                setState(() {
                  _nsfwContent = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Community Moderation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildModeratorSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF3D4451)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onCreateCommunity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1152D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Community',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9DA6B9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.all(const Color(0xFF1152D4)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorSection() {
    // In a real app, you would fetch the list of moderators here
    final moderators = [
      {'name': 'You', 'role': 'Creator'},
      // Add more moderators as needed
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moderators',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...moderators.map(
            (moderator) => _buildModeratorItem(
              name: moderator['name']!,
              role: moderator['role']!,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Add moderator functionality
            },
            child: const Text(
              '+ Add Moderator',
              style: TextStyle(
                color: Color(0xFF1152D4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeratorItem({required String name, required String role}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF282E39),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF9DA6B9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (role != 'Creator')
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 20),
              onPressed: () {
                // Remove moderator functionality
              },
            ),
        ],
      ),
    );
  }
}
