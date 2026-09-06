import 'package:flutter/foundation.dart' show kDebugMode;

class SupabaseConfig {
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return 'http://localhost:54321';
    return '';
  }

  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  static String get cdnUrl {
    const fromEnv = String.fromEnvironment('CDN_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Fallback to supabase storage URL if CDN is not configured
    return '$supabaseUrl/storage/v1/object/public';
  }

  /// Whether to use a Selective Forwarding Unit (SFU) for large-scale calls.
  /// If false, use Peer-to-Peer (Mesh) architecture.
  static bool get isSFUEnabled {
    const fromEnv = String.fromEnvironment('SFU_ENABLED');
    return fromEnv == 'true';
  }

  static String get sfuServerUrl {
    const fromEnv = String.fromEnvironment('SFU_SERVER_URL');
    return fromEnv;
  }

  // Enable debug logging only in development builds
  static bool get debug => kDebugMode;

  // Storage buckets
  static const String profilePicturesBucket = 'profile-pictures';
  static const String postImagesBucket = 'post-images';
  static const String postVideosBucket = 'post-videos';
  static const String communityImagesBucket = 'community-images';
  static const String messageAttachmentsBucket = 'message-attachments';
  static const String storiesBucket = 'stories';
  static const String ripplesVideosBucket = 'ripples-videos';

  // Table names - Core
  static const String profilesTable = 'profiles';
  static const String postsTable = 'posts';
  static const String communitiesTable = 'communities';
  static const String communityMembersTable = 'community_members';
  static const String followsTable = 'follows';
  static const String likesTable = 'likes';
  static const String bookmarksTable = 'bookmarks';
  static const String commentsTable = 'comments';
  static const String commentLikesTable = 'comment_likes';
  static const String notificationsTable = 'notifications';
  static const String userStatusTable = 'user_status';
  static const String dataExportRequestsTable = 'data_export_requests';

  // Table names - Ripples
  static const String ripplesTable = 'ripples';
  static const String rippleCommentsTable = 'ripple_comments';
  static const String rippleLikesTable = 'ripple_likes';
  static const String rippleSavesTable = 'ripple_saves';

  // Table names - Messaging
  static const String conversationsTable = 'conversations';
  static const String conversationParticipantsTable =
      'conversation_participants';
  static const String messagesTable = 'messages';
  static const String messageReadReceiptsTable = 'message_read_receipts';
  static const String messageReactionsTable = 'message_reactions';
  static const String messageMediaViewsTable = 'message_media_views';
  static const String typingIndicatorsTable = 'typing_indicators';
  static const String chatThemesTable = 'chat_themes';
  static const String storiesTable = 'stories';
  static const String pollsTable = 'polls';
  static const String pollOptionsTable = 'poll_options';
  static const String pollVotesTable = 'poll_votes';

  // Function names
  static const String getFeedPostsFn = 'get_feed_posts';
  static const String getFollowingFeedPostsFn = 'get_following_feed_posts';
  static const String getUnifiedFeedFn = 'get_unified_feed';
  static const String getUserConversationsFn = 'get_user_conversations';
  static const String getOrCreateDirectConversationFn =
      'get_or_create_direct_conversation';
  static const String resetUnreadCountFn = 'reset_unread_count';
  static const String deleteUserAccountFn = 'delete_user_account';
  static const String getEmailByUsernameFn = 'get_email_by_username';
  static const String incrementMediaViewCountFn = 'increment_media_view_count';

  // Channel names for realtime
  static const String postsChannel = 'public:posts';
  static const String messagesChannel = 'public:messages';
  static const String notificationsChannel = 'public:notifications';
  static const String typingIndicatorsChannel = 'public:typing_indicators';
  static const String conversationParticipantsChannel =
      'public:conversation_participants';
}
