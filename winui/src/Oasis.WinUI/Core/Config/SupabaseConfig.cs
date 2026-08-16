namespace Oasis.WinUI.Core.Config;

/// <summary>
/// Storage buckets, table names and function names mirroring
/// lib/core/config/supabase_config.dart from the Flutter app.
/// </summary>
public static class SupabaseConfig
{
    // Storage buckets
    public const string ProfilePicturesBucket = "profile-pictures";
    public const string PostImagesBucket = "post-images";
    public const string PostVideosBucket = "post-videos";
    public const string CommunityImagesBucket = "community-images";
    public const string MessageAttachmentsBucket = "message-attachments";
    public const string StoriesBucket = "stories";
    public const string RipplesVideosBucket = "ripples-videos";

    // Tables - Core
    public const string ProfilesTable = "profiles";
    public const string PostsTable = "posts";
    public const string CommunitiesTable = "communities";
    public const string CommunityMembersTable = "community_members";
    public const string FollowsTable = "follows";
    public const string LikesTable = "likes";
    public const string BookmarksTable = "bookmarks";
    public const string CommentsTable = "comments";
    public const string CommentLikesTable = "comment_likes";
    public const string NotificationsTable = "notifications";
    public const string UserStatusTable = "user_status";
    public const string DataExportRequestsTable = "data_export_requests";

    // Tables - Ripples
    public const string RipplesTable = "ripples";
    public const string RippleCommentsTable = "ripple_comments";
    public const string RippleLikesTable = "ripple_likes";
    public const string RippleSavesTable = "ripple_saves";

    // Tables - Messaging
    public const string ConversationsTable = "conversations";
    public const string ConversationParticipantsTable = "conversation_participants";
    public const string MessagesTable = "messages";
    public const string MessageReadReceiptsTable = "message_read_receipts";
    public const string MessageReactionsTable = "message_reactions";
    public const string MessageMediaViewsTable = "message_media_views";
    public const string TypingIndicatorsTable = "typing_indicators";
    public const string ChatThemesTable = "chat_themes";
    public const string StoriesTable = "stories";
    public const string TimeCapsulesTable = "time_capsules";
    public const string PollsTable = "polls";
    public const string PollOptionsTable = "poll_options";
    public const string PollVotesTable = "poll_votes";

    // RPC functions
    public const string GetFeedPostsFn = "get_feed_posts";
    public const string GetFollowingFeedPostsFn = "get_following_feed_posts";
    public const string GetUnifiedFeedFn = "get_unified_feed";
    public const string GetUserConversationsFn = "get_user_conversations";
    public const string GetOrCreateDirectConversationFn = "get_or_create_direct_conversation";
    public const string ResetUnreadCountFn = "reset_unread_count";
    public const string DeleteUserAccountFn = "delete_user_account";
    public const string GetEmailByUsernameFn = "get_email_by_username";
    public const string IncrementMediaViewCountFn = "increment_media_view_count";

    // Realtime channels
    public const string PostsChannel = "public:posts";
    public const string MessagesChannel = "public:messages";
    public const string NotificationsChannel = "public:notifications";
    public const string TypingIndicatorsChannel = "public:typing_indicators";
    public const string ConversationParticipantsChannel = "public:conversation_participants";
}
