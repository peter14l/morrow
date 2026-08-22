import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/collections/presentation/providers/collections_provider.dart';
import 'package:oasis/features/collections/presentation/providers/collections_state.dart';
import 'package:go_router/go_router.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionsProvider>().loadCollections();
    });
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPrivate = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My Favorites',
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Posts I love',
                ),
                maxLength: 200,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Private'),
                subtitle: const Text('Only you can see this collection'),
                value: isPrivate,
                onChanged: (value) {
                  setDialogState(() => isPrivate = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                final success = await context
                    .read<CollectionsProvider>()
                    .createCollection(
                      name: nameController.text.trim(),
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      isPrivate: isPrivate,
                    );

                if (success && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollectionsProvider>().state;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 1100 ? 4 : (screenWidth >= 650 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showCreateDialog),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<CollectionsProvider>().loadCollections(),
        child:
            state.status == CollectionsStatus.loading ||
                state.status == CollectionsStatus.initial
            ? const Center(child: CircularProgressIndicator())
            : state.collections.isEmpty
            ? _buildEmptyState(colorScheme, theme)
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: state.collections.length,
                itemBuilder: (context, index) {
                  return _buildCollectionCard(state.collections[index]);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.collections_bookmark_outlined,
                size: 80,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No Collections Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create collections to organize your saved posts',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Collection'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionCard(CollectionEntity collection) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        context.push('/collections/${collection.id}');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview images
            Expanded(
              child: collection.hasPreview
                  ? GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: collection.previewImages!
                          .take(4)
                          .map(
                            (url) => CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                            ),
                          )
                          .toList(),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: Center(
                        child: Icon(
                          Icons.collections_bookmark_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
            ),

            // Collection info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          collection.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (collection.isPrivate)
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${collection.itemsCount} ${collection.itemsCount == 1 ? 'post' : 'posts'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
