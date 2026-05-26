import 'package:flutter/material.dart';
import 'package:oasis/features/feed/domain/models/post.dart';

/// Enum representing different feed layout types
enum FeedLayoutType { classic, spatial, focused, canvas, standard, zenCarousel, pulseMap }

/// Type of interaction with a post
enum InteractionType { like, comment, share, bookmark, expand, view }

/// Abstract strategy interface for feed layout implementations
/// Allows switching between different feed visualization paradigms
abstract class FeedLayoutStrategy {
  /// The type of layout this strategy implements
  FeedLayoutType get type;

  /// Build the feed widget for the given posts
  Widget buildFeed(
    BuildContext context,
    List<Post> posts, {
    required VoidCallback onRefresh,
    required VoidCallback onLoadMore,
  });

  /// Handle post interaction events
  /// Used for tracking engagement and updating energy meter
  void onPostInteraction(Post post, InteractionType type);

  /// Dispose of any resources (controllers, subscriptions, etc.)
  void dispose();
}

/// Extension to get human-readable names for layout types
extension FeedLayoutTypeExtension on FeedLayoutType {
  String get displayName {
    switch (this) {
      case FeedLayoutType.classic:
        return 'Classic';
      case FeedLayoutType.spatial:
        return 'Spatial Glider';
      case FeedLayoutType.focused:
        return 'Focused Flow';
      case FeedLayoutType.canvas:
        return 'Living Canvas';
      case FeedLayoutType.standard:
        return 'Standard';
      case FeedLayoutType.zenCarousel:
        return 'Zen Carousel';
      case FeedLayoutType.pulseMap:
        return 'Pulse Map';
    }
  }

  IconData get icon {
    switch (this) {
      case FeedLayoutType.classic:
        return Icons.view_headline_rounded;
      case FeedLayoutType.spatial:
        return Icons.explore_rounded;
      case FeedLayoutType.focused:
        return Icons.filter_center_focus_rounded;
      case FeedLayoutType.canvas:
        return Icons.auto_awesome_mosaic_rounded;
      case FeedLayoutType.standard:
        return Icons.view_day_rounded;
      case FeedLayoutType.zenCarousel:
        return Icons.view_carousel_rounded;
      case FeedLayoutType.pulseMap:
        return Icons.hub_rounded;
    }
  }
}
