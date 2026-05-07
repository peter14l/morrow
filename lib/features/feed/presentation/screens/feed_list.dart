import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedList extends StatelessWidget {
  final String type;

  const FeedList({super.key, required this.type});

  // Mock data - in a real app, this would come from an API
  final List<Map<String, dynamic>> _posts = const [
    {
      'id': '1',
      'userName': 'Chloe Bennett',
      'userImage': 'https://randomuser.me/api/portraits/women/44.jpg',
      'postText':
          'Just finished a great hike! The views were breathtaking. 🏞️ #nature #hiking',
      'postImage':
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800',
      'likes': 23,
      'comments': 5,
      'shares': 1,
      'timeAgo': '2h ago',
    },
    {
      'id': '2',
      'userName': 'Owen Carter',
      'userImage': 'https://randomuser.me/api/portraits/men/32.jpg',
      'postText':
          'Exploring the city\'s hidden gems today. Found this amazing coffee shop! ☕ #citylife #coffeeshop',
      'postImage':
          'https://images.unsplash.com/photo-1498804103079-d09b6850a9e8?w=800',
      'likes': 45,
      'comments': 12,
      'shares': 3,
      'timeAgo': '5h ago',
    },
    {
      'id': '3',
      'userName': 'Isabella Harper',
      'userImage': 'https://randomuser.me/api/portraits/women/63.jpg',
      'postText':
          'Weekend getaway to the beach! Soaking up the sun and enjoying the waves. 🌊☀️ #beachlife #vacation',
      'postImage':
          'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800',
      'likes': 32,
      'comments': 8,
      'shares': 2,
      'timeAgo': '1d ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Space for bottom navigation
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostCard(post: post);
      },
    );
  }
}

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(post['userImage']),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['userName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        post['timeAgo'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    // Show post options
                  },
                ),
              ],
            ),
          ),

          // Post text
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(post['postText']),
          ),

          // Post image
          if (post['postImage'] != null)
            CachedNetworkImage(
              imageUrl: post['postImage'],
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

          // Post actions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                /*
                _buildActionButton(
                  icon: Icons.favorite_border,
                  label: '',
                  onPressed: () {
                    // Handle like
                  },
                ),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '',
                  onPressed: () {
                    // Handle comment
                  },
                ),
                */
                _buildActionButton(
                  icon: Icons.share,
                  label: '',
                  onPressed: () {
                    // Handle share
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.grey[600]),
      label: Text(label, style: TextStyle(color: Colors.grey[600])),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
