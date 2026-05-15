import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/collections/domain/models/collection_entity.dart';
import 'package:oasis/features/collections/presentation/providers/collections_provider.dart';

class AddToCollectionSheet extends StatefulWidget {
  final String postId;

  const AddToCollectionSheet({super.key, required this.postId});

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  List<CollectionEntity> _collections = [];
  Set<String> _selectedCollections = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<CollectionsProvider>();

      // We can just await the use case or method
      final collectionsResult = await provider.getCollectionsForPostUseCase
          .call(widget.postId);

      final containingCollections = collectionsResult.fold(
        onSuccess: (data) => data,
        onFailure: (_) => <CollectionEntity>[],
      );

      final containingIds = containingCollections.map((c) => c.id).toSet();

      if (mounted) {
        setState(() {
          _collections = provider.state.collections;
          _selectedCollections = containingIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      final provider = context.read<CollectionsProvider>();
      // Get collections that were originally selected
      final originalResult = await provider.getCollectionsForPostUseCase.call(
        widget.postId,
      );
      final originalCollections = originalResult.fold(
        onSuccess: (data) => data,
        onFailure: (_) => <CollectionEntity>[],
      );
      final originalIds = originalCollections.map((c) => c.id).toSet();

      // Add to new collections
      for (final collectionId in _selectedCollections) {
        if (!originalIds.contains(collectionId)) {
          await provider.addToCollection(collectionId, widget.postId);
        }
      }

      // Remove from deselected collections
      for (final collectionId in originalIds) {
        if (!_selectedCollections.contains(collectionId)) {
          await provider.removeFromCollection(collectionId, widget.postId);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Collections updated')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _createNewCollection() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'My Favorites',
          ),
          maxLength: 50,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(nameController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await context
          .read<CollectionsProvider>()
          .createCollection(name: result, isPrivate: true);

      if (success) {
        await _loadCollections();
        // Assume the last element is the newest
        final newCollectionId = context
            .read<CollectionsProvider>()
            .state
            .collections
            .last
            .id;
        setState(() {
          _selectedCollections.add(newCollectionId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Save to Collection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_collections.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('No collections yet'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _createNewCollection,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Collection'),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collections.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Create new collection'),
                      onTap: _createNewCollection,
                    );
                  }

                  final collection = _collections[index - 1];
                  final isSelected = _selectedCollections.contains(
                    collection.id,
                  );

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedCollections.add(collection.id);
                        } else {
                          _selectedCollections.remove(collection.id);
                        }
                      });
                    },
                    title: Text(collection.name),
                    subtitle: Text('${collection.itemsCount} posts'),
                    secondary: collection.isPrivate
                        ? const Icon(Icons.lock_outline, size: 20)
                        : null,
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
