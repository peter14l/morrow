import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oasis/features/stories/domain/models/story_entity.dart';
import 'package:oasis/features/stories/presentation/providers/stories_provider.dart';
import 'package:provider/provider.dart';

class StoryViewersSheet extends StatelessWidget {
  final String storyId;

  const StoryViewersSheet({super.key, required this.storyId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoryViewerEntity>>(
      future: context.read<StoriesProvider>().getStoryViewers(storyId),
      builder: (context, snapshot) {
        final viewers = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Story Activity',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                )
              else if (viewers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('No views yet'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final viewer = viewers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            viewer.avatarUrl ?? '',
                          ),
                        ),
                        title: Text(viewer.username),
                        subtitle: Text(_getTimeAgo(viewer.viewedAt)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
