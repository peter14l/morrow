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
      icon: FluentIcons.window_glass_20_regular,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...categoryItems.map((item) {
          final isOwned = service.hasItem(item.id);
          final isActive = service.isItemActive(item.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(item.icon, color: theme.colorScheme.primary),
              ),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isOwned
                      ? (item.category == 'theme'
                          ? TextButton(
                              onPressed: () {
                                service.activateItem(item.id, item.category);
                                CustomSnackbar.showSuccess(
                                    context, 'Aura theme activated!');
                              },
                              child: Text(isActive ? 'Active' : 'Equip'),
                            )
                          : const Text('Owned', style: TextStyle(color: Colors.green)))
                      : ElevatedButton(
                          onPressed: () async {
                            final success = await service.purchaseItem(item.id, item.category);
                            if (success && mounted) {
                              CustomSnackbar.showSuccess(
                                  context, 'Thank you! Purchased ${item.name}');
                            }
                          },
                          child: Text(item.price),
                        ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
