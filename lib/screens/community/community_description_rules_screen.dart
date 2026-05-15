import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommunityDescriptionRulesScreen extends StatefulWidget {
  final String name;
  final String theme;

  const CommunityDescriptionRulesScreen({
    super.key,
    required this.name,
    required this.theme,
  });

  @override
  State<CommunityDescriptionRulesScreen> createState() =>
      _CommunityDescriptionRulesScreenState();
}

class _CommunityDescriptionRulesScreenState
    extends State<CommunityDescriptionRulesScreen> {
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState?.validate() ?? false) {
      // Navigate to the next screen
      context.push(
        '/community/create/privacy',
        extra: {
          'name': widget.name,
          'theme': widget.theme,
          'description': _descriptionController.text.trim(),
          'rules': _rulesController.text.trim(),
        },
      );
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
        title: const Text('Community Setup'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Community Description',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tell us about your community...',
                  hintStyle: const TextStyle(color: Color(0xFF9DA6B9)),
                  filled: true,
                  fillColor: const Color(0xFF282E39),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 20) {
                    return 'Description should be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Community Rules',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set clear rules for your community to ensure a positive environment. Each rule should be on a new line.',
                style: TextStyle(color: Color(0xFF9DA6B9), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rulesController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText:
                      '1. Be respectful to others\n2. No spam or self-promotion\n3. Keep discussions on topic\n4. No hate speech or harassment',
                  hintStyle: const TextStyle(color: Color(0xFF9DA6B9)),
                  filled: true,
                  fillColor: const Color(0xFF282E39),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter at least one rule';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Example Rules:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              _buildRuleExample('Respect all community members'),
              _buildRuleExample('No spam or self-promotion'),
              _buildRuleExample('Keep discussions on topic'),
              _buildRuleExample('No hate speech or harassment'),
              _buildRuleExample('No NSFW content'),
              const SizedBox(height: 32),
            ],
          ),
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
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1152D4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Next',
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

  Widget _buildRuleExample(String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
