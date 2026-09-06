/// Supabase table names, bucket names, RPC function names, and channel names.
///
/// Centralized here so that any schema change only requires updating this file.
class SupabaseTables {
  SupabaseTables._();

  // ─── Storage Buckets ───────────────────────────────────────────────
  static const String bucketProfilePictures = 'profile-pictures';
  static const String bucketPostImages = 'post-images';
  static const String bucketPostVideos = 'post-videos';
  static const String bucketCommunityImages = 'community-images';
  static const String bucketMessageAttachments = 'message-attachments';
  static const String bucketStories = 'stories';

  // ─── Core Tables ───────────────────────────────────────────────────
  static const String tableProfiles = 'profiles';
  static const String tablePosts = 'posts';
  static const String tableCommunities = 'communities';
  static const String tableCommunityMembers = 'community_members';
  static const String tableFollows = 'follows';
  static const String tableLikes = 'likes';
  static const String tableBookmarks = 'bookmarks';
  static const String tableComments = 'comments';
  static const String tableCommentLikes = 'comment_likes';
  static const String tableNotifications = 'notifications';

  // ─── Messaging Tables ──────────────────────────────────────────────
  static const String tableConversations = 'conversations';
  static const String tableConversationParticipants =
      'conversation_participants';
  static const String tableMessages = 'messages';
  static const String tableMessageReadReceipts = 'message_read_receipts';
  static const String tableMessageReactions = 'message_reactions';
  static const String tableMessageMediaViews = 'message_media_views';
  static const String tableTypingIndicators = 'typing_indicators';
  static const String tableStories = 'stories';

  // ─── RPC Functions ─────────────────────────────────────────────────
  static const String fnGetFeedPosts = 'get_feed_posts';
  static const String fnGetFollowingFeedPosts = 'get_following_feed_posts';
  static const String fnGetUserConversations = 'get_user_conversations';
  static const String fnGetOrCreateDirectConversation =
      'get_or_create_direct_conversation';
  static const String fnResetUnreadCount = 'reset_unread_count';
  static const String fnDeleteUserAccount = 'delete_user_account';

  // ─── Realtime Channels ─────────────────────────────────────────────
  static const String channelPosts = 'public:posts';
  static const String channelMessages = 'public:messages';
  static const String channelNotifications = 'public:notifications';
  static const String channelTypingIndicators = 'public:typing_indicators';
  static const String channelConversationParticipants =
      'public:conversation_participants';
}
