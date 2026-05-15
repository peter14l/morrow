import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommunityNameThemeScreen extends StatefulWidget {
  const CommunityNameThemeScreen({super.key});

  @override
  State<CommunityNameThemeScreen> createState() =>
      _CommunityNameThemeScreenState();
}

class _CommunityNameThemeScreenState extends State<CommunityNameThemeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedTheme = 'General';
  final List<String> _themes = [
    'Gaming',
    'Music',
    'Art',
    'Sports',
    'Technology',
    'Travel',
    'Food',
    'Fashion',
    'Health',
    'Education',
    'Business',
    'Entertainment',
    'General',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_formKey.currentState?.validate() ?? false) {
      // Navigate to the next screen with the community name and theme
      context.push(
        '/community/create/guidelines',
        extra: {'name': _nameController.text.trim(), 'theme': _selectedTheme},
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
        title: const Text('Create a community'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Name your community',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Community name',
                  hintStyle: const TextStyle(color: Color(0xFF9DA6B9)),
                  filled: true,
                  fillColor: const Color(0xFF282E39),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a community name';
                  }
                  if (value.trim().length > 21) {
                    return 'Community name must be 21 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Community names can be up to 21 characters and can\'t be changed later.',
                style: TextStyle(color: Color(0xFF9DA6B9), fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose a theme',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _themes.map((theme) {
                  final isSelected = _selectedTheme == theme;
                  return FilterChip(
                    label: Text(theme),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTheme = selected ? theme : 'General';
                      });
                    },
                    backgroundColor: const Color(0xFF282E39),
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : const Color(0xFF3D4451),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
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
    );
  }
}
