import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oasis/features/feed/presentation/widgets/post_card.dart';
import 'package:oasis/features/collections/presentation/providers/collections_provider.dart';
import 'package:oasis/features/collections/presentation/providers/collections_state.dart';
import 'package:go_router/go_router.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionsProvider>().loadCollectionDetail(widget.collectionId);
    });
  }

  Future<void> _deleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Collection'),
            content: const Text(
              'Are you sure you want to delete this collection? The posts will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final success = await context.read<CollectionsProvider>().deleteCollection(widget.collectionId);
      if (success && mounted) {
        context.pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting collection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CollectionsProvider>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'), // We could pass the name if we had it
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCollection,
          ),
        ],
      ),
      body:
          state.detailStatus == CollectionsStatus.loading || state.detailStatus == CollectionsStatus.initial
              ? const Center(child: CircularProgressIndicator())
              : state.collectionItems.isEmpty
              ? const Center(child: Text('No posts in this collection'))
              : ListView.builder(
                itemCount: state.collectionItems.length,
                itemBuilder: (context, index) {
                  return PostCard(
                    post: state.collectionItems[index],
                    showInteractionButtons: false,
                    onLike: () {},
                    onComment: () {},
                    onShare: () {},
                  );
                },
              ),
    );
  }
}
