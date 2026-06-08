import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:oasis/themes/app_colors.dart';
import 'package:oasis/widgets/custom_snackbar.dart';
import '../../data/services/customization_service.dart';

class ShopItem {
  final String id;
  final String name;
  final String description;
  final String price;
  final String category; // 'theme', 'boost', 'storage'
  final IconData icon;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.icon,
  });
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final List<ShopItem> _items = [
    ShopItem(
      id: 'theme_e_ink',
      name: 'E-Ink Minimalist',
      description: 'Zero-distraction paper-like UI theme.',
      price: '\$0.99',
      category: 'theme',
      icon: FluentIcons.text_bullet_list_tree_16_regular,
    ),
    ShopItem(
      id: 'theme_cyberpunk',
      name: 'Cyberpunk Glass',
      description: 'Vibrant neon outlines and deep dark blur effects.',
      price: '\$0.99',
      category: 'theme',
      icon: FluentIcons.window_multiple_20_regular,
    ),
    ShopItem(
      id: 'boost_1',
      name: '1x Circle Boost',
      description: 'Support your favorite Circle and unlock custom styles.',
      price: '\$1.49',
      category: 'boost',
      icon: FluentIcons.rocket_20_regular,
    ),
    ShopItem(
      id: 'boost_3',
      name: '3x Circle Boost Bundle',
      description: 'Maximize your support for your communities.',
      price: '\$2.99',
      category: 'boost',
      icon: FluentIcons.rocket_24_filled,
    ),
    ShopItem(
      id: 'storage_10gb',
      name: '+10GB Media Storage',
      description: 'Increase your Cloudflare R2 limit for photos & videos.',
      price: '\$2.99',
      category: 'storage',
      icon: FluentIcons.cloud_words_20_regular,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomizationService>().fetchOwnedCustomizations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<CustomizationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oasis Storefront'),
        elevation: 0,
      ),
      body: service.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildCategorySection('Custom Themes (Aura)', 'theme', service, theme),
                  const SizedBox(height: 24),
                  _buildCategorySection('Circle Boosting Tokens', 'boost', service, theme),
                  const SizedBox(height: 24),
                  _buildCategorySection('Storage Upgrades', 'storage', service, theme),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            OasisColors.moss,
            OasisColors.sage,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oasis Aura Shop',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: OasisColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Support the platform directly via single micro-transactions. Buy only what you love, zero subscriptions required.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: OasisColors.mist,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String title,
    String category,
    CustomizationService service,
    ThemeData theme,
  ) {
    final categoryItems = _items.where((i) => i.category == category).toList();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 800 ? 3 : (width > 600 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categoryItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 200,
          ),
          itemBuilder: (context, index) {
            final item = categoryItems[index];
            final isOwned = service.hasItem(item.id);
            final isActive = service.isItemActive(item.id);

            Color accentColor;
            if (category == 'theme') {
              accentColor = Colors.purpleAccent;
            } else if (category == 'boost') {
              accentColor = Colors.pinkAccent;
            } else {
              accentColor = Colors.blueAccent;
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isActive
                      ? accentColor
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: isOwned
                              ? (item.category == 'theme'
                                  ? OutlinedButton(
                                      onPressed: () {
                                        service.activateItem(item.id, item.category);
                                        CustomSnackbar.showSuccess(
                                            context, 'Aura theme activated!');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(isActive ? 'Active' : 'Equip'),
                                    )
                                  : Center(
                                      child: Text(
                                        'Owned',
                                        style: TextStyle(
                                          color: Colors.green.shade600,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ))
                              : ElevatedButton(
                                  onPressed: () async {
                                    final success = await service.purchaseItem(item.id, item.category);
                                    if (success && mounted) {
                                      CustomSnackbar.showSuccess(
                                          context, 'Thank you! Purchased ${item.name}');
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(item.price),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
