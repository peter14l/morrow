import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:oasis/core/utils/haptic_utils.dart';
import 'package:oasis/themes/theme_provider.dart';
import 'package:provider/provider.dart';

/// Interest categories for onboarding discovery quiz
class InterestCategory {
  final String id;
  final String name;
  final String emoji;
  final material.Color color;
  final List<String> subcategories;

  const InterestCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.subcategories = const [],
  });
}

/// Predefined interest categories
class InterestCategories {
  static const List<InterestCategory> all = [
    InterestCategory(
      id: 'art',
      name: 'Art & Design',
      emoji: '🎨',
      color: material.Color(0xFFE91E63),
      subcategories: [
        'Digital Art',
        'Photography',
        'Illustration',
        'UI/UX',
        'Architecture',
      ],
    ),
    InterestCategory(
      id: 'music',
      name: 'Music',
      emoji: '🎵',
      color: material.Color(0xFF9C27B0),
      subcategories: [
        'Pop',
        'Hip Hop',
        'Rock',
        'Electronic',
        'Jazz',
        'Classical',
      ],
    ),
    InterestCategory(
      id: 'tech',
      name: 'Technology',
      emoji: '💻',
      color: material.Color(0xFF2196F3),
      subcategories: ['Programming', 'AI/ML', 'Startups', 'Gaming', 'Gadgets'],
    ),
    InterestCategory(
      id: 'fitness',
      name: 'Fitness & Health',
      emoji: '💪',
      color: material.Color(0xFF4CAF50),
      subcategories: ['Gym', 'Yoga', 'Running', 'Nutrition', 'Mental Health'],
    ),
    InterestCategory(
      id: 'travel',
      name: 'Travel',
      emoji: '✈️',
      color: material.Color(0xFF00BCD4),
      subcategories: ['Adventure', 'Beach', 'City', 'Nature', 'Culture'],
    ),
    InterestCategory(
      id: 'food',
      name: 'Food & Cooking',
      emoji: '🍕',
      color: material.Color(0xFFFF9800),
      subcategories: [
        'Recipes',
        'Restaurants',
        'Baking',
        'Healthy Eating',
        'Coffee',
      ],
    ),
    InterestCategory(
      id: 'fashion',
      name: 'Fashion & Style',
      emoji: '👗',
      color: material.Color(0xFFFF5722),
      subcategories: [
        'Streetwear',
        'Luxury',
        'Vintage',
        'Sustainable',
        'Accessories',
      ],
    ),
    InterestCategory(
      id: 'sports',
      name: 'Sports',
      emoji: '⚽',
      color: material.Color(0xFF795548),
      subcategories: ['Football', 'Basketball', 'Tennis', 'F1', 'Esports'],
    ),
    InterestCategory(
      id: 'entertainment',
      name: 'Entertainment',
      emoji: '🎬',
      color: material.Color(0xFF673AB7),
      subcategories: ['Movies', 'TV Shows', 'Anime', 'K-Drama', 'Podcasts'],
    ),
    InterestCategory(
      id: 'lifestyle',
      name: 'Lifestyle',
      emoji: '🌿',
      color: material.Color(0xFF8BC34A),
      subcategories: [
        'Minimalism',
        'Self-care',
        'Productivity',
        'Home Decor',
        'Pets',
      ],
    ),
    InterestCategory(
      id: 'business',
      name: 'Business',
      emoji: '💼',
      color: material.Color(0xFF607D8B),
      subcategories: [
        'Entrepreneurship',
        'Marketing',
        'Finance',
        'Career',
        'Investing',
      ],
    ),
    InterestCategory(
      id: 'science',
      name: 'Science',
      emoji: '🔬',
      color: material.Color(0xFF3F51B5),
      subcategories: [
        'Space',
        'Biology',
        'Psychology',
        'Physics',
        'Environment',
      ],
    ),
  ];
}

/// User's interest profile
class UserInterests {
  final List<String> selectedCategories;
  final Map<String, List<String>> selectedSubcategories;
  final List<String> customInterests;

  UserInterests({
    this.selectedCategories = const [],
    this.selectedSubcategories = const {},
    this.customInterests = const [],
  });

  factory UserInterests.fromJson(Map<String, dynamic> json) {
    return UserInterests(
      selectedCategories: (json['categories'] as List?)?.cast<String>() ?? [],
      selectedSubcategories:
          (json['subcategories'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as List).cast<String>()),
          ) ??
          {},
      customInterests: (json['custom'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': selectedCategories,
      'subcategories': selectedSubcategories,
      'custom': customInterests,
    };
  }
}

/// Interest Discovery Quiz Widget
class InterestDiscoveryQuiz extends StatefulWidget {
  final Function(UserInterests) onComplete;
  final UserInterests? existingInterests;

  const InterestDiscoveryQuiz({
    super.key,
    required this.onComplete,
    this.existingInterests,
  });

  @override
  State<InterestDiscoveryQuiz> createState() => _InterestDiscoveryQuizState();
}

class _InterestDiscoveryQuizState extends State<InterestDiscoveryQuiz> {
  final Set<String> _selectedCategories = {};
  final Map<String, Set<String>> _selectedSubcategories = {};
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    if (widget.existingInterests != null) {
      _selectedCategories.addAll(widget.existingInterests!.selectedCategories);
      for (final entry
          in widget.existingInterests!.selectedSubcategories.entries) {
        _selectedSubcategories[entry.key] = entry.value.toSet();
      }
    }
  }

  void _toggleCategory(String categoryId) {
    HapticUtils.selectionClick();
    setState(() {
      if (_selectedCategories.contains(categoryId)) {
        _selectedCategories.remove(categoryId);
        _selectedSubcategories.remove(categoryId);
      } else {
        _selectedCategories.add(categoryId);
      }
    });
  }

  void _toggleSubcategory(String categoryId, String subcategory) {
    HapticUtils.lightImpact();
    setState(() {
      _selectedSubcategories.putIfAbsent(categoryId, () => {});
      if (_selectedSubcategories[categoryId]!.contains(subcategory)) {
        _selectedSubcategories[categoryId]!.remove(subcategory);
      } else {
        _selectedSubcategories[categoryId]!.add(subcategory);
      }
    });
  }

  void _complete() {
    HapticUtils.success();
    widget.onComplete(
      UserInterests(
        selectedCategories: _selectedCategories.toList(),
        selectedSubcategories: _selectedSubcategories.map(
          (k, v) => MapEntry(k, v.toList()),
        ),
      ),
    );
  }

  @override
  Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final useFluent = themeProvider.useFluentUI;
    final fluentTheme = useFluent ? fluent.FluentTheme.of(context) : null;

    return material.Column(
      children: [
        // Progress indicator
        material.Padding(
          padding: const material.EdgeInsets.symmetric(vertical: 16),
          child: useFluent
              ? fluent.PipsPager(
                  numberOfPages: 2,
                  currentIndex: _currentStep,
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                )
              : material.Row(
                  mainAxisAlignment: material.MainAxisAlignment.center,
                  children: List.generate(2, (index) {
                    return material.Container(
                      width: 8,
                      height: 8,
                      margin: const material.EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      decoration: material.BoxDecoration(
                        shape: material.BoxShape.circle,
                        color: _currentStep == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    );
                  }),
                ),
        ),

        material.Expanded(
          child: _currentStep == 0
              ? _buildCategorySelection(theme, useFluent, fluentTheme)
              : _buildSubcategorySelection(theme, useFluent, fluentTheme),
        ),

        // Navigation buttons
        material.Padding(
          padding: const material.EdgeInsets.all(16),
          child: material.Row(
            children: [
              if (_currentStep > 0)
                useFluent
                    ? fluent.Button(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: const material.Text('Back'),
                      )
                    : material.OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 0),
                        child: const material.Text('Back'),
                      ),
              const material.Spacer(),
              useFluent
                  ? fluent.FilledButton(
                      onPressed:
                          _currentStep == 0 && _selectedCategories.isNotEmpty
                          ? () => setState(() => _currentStep = 1)
                          : _currentStep == 1
                          ? _complete
                          : null,
                      child: material.Text(_currentStep == 0 ? 'Next' : 'Done'),
                    )
                  : material.FilledButton(
                      onPressed:
                          _currentStep == 0 && _selectedCategories.isNotEmpty
                          ? () => setState(() => _currentStep = 1)
                          : _currentStep == 1
                          ? _complete
                          : null,
                      child: material.Text(_currentStep == 0 ? 'Next' : 'Done'),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  material.Widget _buildCategorySelection(
    material.ThemeData theme,
    bool useFluent,
    fluent.FluentThemeData? fluentTheme,
  ) {
    return material.SingleChildScrollView(
      padding: const material.EdgeInsets.all(16),
      child: material.Column(
        crossAxisAlignment: material.CrossAxisAlignment.start,
        children: [
          material.Text(
            'What are you interested in?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: material.FontWeight.bold,
            ),
          ),
          const material.SizedBox(height: 8),
          material.Text(
            'Select at least 3 topics to personalize your feed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const material.SizedBox(height: 24),
          material.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: InterestCategories.all.map((category) {
              final isSelected = _selectedCategories.contains(category.id);
              final cardChild = material.Padding(
                padding: const material.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: material.Row(
                  mainAxisSize: material.MainAxisSize.min,
                  children: [
                    material.Text(
                      category.emoji,
                      style: const material.TextStyle(fontSize: 20),
                    ),
                    const material.SizedBox(width: 8),
                    material.Text(
                      category.name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: isSelected
                            ? material.FontWeight.bold
                            : material.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );

              if (useFluent) {
                return fluent.Card(
                  padding: material.EdgeInsets.zero,
                  backgroundColor: isSelected
                      ? category.color.withValues(alpha: 0.1)
                      : fluentTheme?.cardColor,
                  borderColor: isSelected ? category.color : null,
                  child: material.InkWell(
                    onTap: () => _toggleCategory(category.id),
                    borderRadius: material.BorderRadius.circular(8),
                    child: cardChild,
                  ),
                );
              }

              return material.Material(
                color: material.Colors.transparent,
                child: material.InkWell(
                  onTap: () => _toggleCategory(category.id),
                  borderRadius: material.BorderRadius.circular(16),
                  child: material.Container(
                    decoration: material.BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: material.BorderRadius.circular(16),
                      border: material.Border.all(
                        color: isSelected
                            ? category.color
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                        width: 1.5,
                      ),
                    ),
                    child: cardChild,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  material.Widget _buildSubcategorySelection(
    material.ThemeData theme,
    bool useFluent,
    fluent.FluentThemeData? fluentTheme,
  ) {
    final selectedCategoryList = InterestCategories.all
        .where((c) => _selectedCategories.contains(c.id))
        .toList();

    return material.ListView.builder(
      padding: const material.EdgeInsets.all(16),
      itemCount: selectedCategoryList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return material.Padding(
            padding: const material.EdgeInsets.only(bottom: 16),
            child: material.Column(
              crossAxisAlignment: material.CrossAxisAlignment.start,
              children: [
                material.Text(
                  'Fine-tune your interests',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: material.FontWeight.bold,
                  ),
                ),
                const material.SizedBox(height: 8),
                material.Text(
                  'Select specific topics you love',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final category = selectedCategoryList[index - 1];
        final selectedSubs = _selectedSubcategories[category.id] ?? {};

        return material.Padding(
          padding: const material.EdgeInsets.only(bottom: 16),
          child: material.Column(
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              material.Row(
                children: [
                  material.Text(
                    category.emoji,
                    style: const material.TextStyle(fontSize: 18),
                  ),
                  const material.SizedBox(width: 8),
                  material.Text(
                    category.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: material.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const material.SizedBox(height: 8),
              material.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: category.subcategories.map((sub) {
                  final isSelected = selectedSubs.contains(sub);
                  return material.FilterChip(
                    label: material.Text(sub),
                    selected: isSelected,
                    selectedColor: category.color.withValues(alpha: 0.3),
                    onSelected: (_) => _toggleSubcategory(category.id, sub),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
