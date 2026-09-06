using Newtonsoft.Json;
using Postgrest.Attributes;
using Postgrest.Models;

namespace Oasis.WinUI.Core.Models;

/// <summary>
/// Thin [Table]-annotated row models used only as vehicles to reach a
/// Supabase table (Client.From&lt;T&gt;() derives the table name from the
/// attribute). All reads are parsed from the raw response.Content JSON;
/// nulls are omitted from writes via NullValueHandling.Ignore so PATCH/POST
/// bodies only carry the columns explicitly set.
/// </summary>
[Table("profiles")]
public sealed class ProfilesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("username", NullValueHandling.Ignore)] public string? Username { get; set; }
    [Column("full_name", NullValueHandling.Ignore)] public string? FullName { get; set; }
    [Column("avatar_url", NullValueHandling.Ignore)] public string? AvatarUrl { get; set; }
    [Column("bio", NullValueHandling.Ignore)] public string? Bio { get; set; }
    [Column("is_verified", NullValueHandling.Ignore)] public bool? IsVerified { get; set; }
    [Column("is_pro", NullValueHandling.Ignore)] public bool? IsPro { get; set; }
    [Column("is_private", NullValueHandling.Ignore)] public bool? IsPrivate { get; set; }
    [Column("public_key", NullValueHandling.Ignore)] public string? PublicKey { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("followers_count", NullValueHandling.Ignore)] public long? FollowersCount { get; set; }
    [Column("following_count", NullValueHandling.Ignore)] public long? FollowingCount { get; set; }
    [Column("posts_count", NullValueHandling.Ignore)] public long? PostsCount { get; set; }
    [Column("xp", NullValueHandling.Ignore)] public long? Xp { get; set; }
    [Column("level", NullValueHandling.Ignore)] public int? Level { get; set; }
    [Column("location", NullValueHandling.Ignore)] public string? Location { get; set; }
    [Column("website", NullValueHandling.Ignore)] public string? Website { get; set; }
}

[Table("posts")]
public sealed class PostsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("content", NullValueHandling.Ignore)] public string? Content { get; set; }
    [Column("image_url", NullValueHandling.Ignore)] public string? ImageUrl { get; set; }
    [Column("thumbnail_url", NullValueHandling.Ignore)] public string? ThumbnailUrl { get; set; }
    [Column("dominant_color", NullValueHandling.Ignore)] public string? DominantColor { get; set; }
    [Column("community_id", NullValueHandling.Ignore)] public string? CommunityId { get; set; }
    [Column("is_ad", NullValueHandling.Ignore)] public bool? IsAd { get; set; }
    [Column("is_spoiler", NullValueHandling.Ignore)] public bool? IsSpoiler { get; set; }
    [Column("hashtags", NullValueHandling.Ignore)] public string[]? Hashtags { get; set; }
    [Column("media_urls", NullValueHandling.Ignore)] public string[]? MediaUrls { get; set; }
    [Column("media_types", NullValueHandling.Ignore)] public string[]? MediaTypes { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("likes_count", NullValueHandling.Ignore)] public long? LikesCount { get; set; }
    [Column("comments_count", NullValueHandling.Ignore)] public long? CommentsCount { get; set; }
    [Column("shares_count", NullValueHandling.Ignore)] public long? SharesCount { get; set; }
    [Column("is_verified", NullValueHandling.Ignore)] public bool? IsVerified { get; set; }
    [Column("username", NullValueHandling.Ignore)] public string? Username { get; set; }
    [Column("user_avatar", NullValueHandling.Ignore)] public string? UserAvatar { get; set; }
    [Column("is_liked", NullValueHandling.Ignore)] public bool? IsLiked { get; set; }
    [Column("is_bookmarked", NullValueHandling.Ignore)] public bool? IsBookmarked { get; set; }
}

[Table("comments")]
public sealed class CommentsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("post_id", NullValueHandling.Ignore)] public string? PostId { get; set; }
    [Column("parent_comment_id", NullValueHandling.Ignore)] public string? ParentCommentId { get; set; }
    [Column("content", NullValueHandling.Ignore)] public string? Content { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("likes_count", NullValueHandling.Ignore)] public long? LikesCount { get; set; }
    [Column("replies_count", NullValueHandling.Ignore)] public long? RepliesCount { get; set; }
    [Column("is_liked", NullValueHandling.Ignore)] public bool? IsLiked { get; set; }
    [Column("is_edited", NullValueHandling.Ignore)] public bool? IsEdited { get; set; }
}

[Table("likes")]
public sealed class LikesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("post_id", NullValueHandling.Ignore)] public string? PostId { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("bookmarks")]
public sealed class BookmarksRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("post_id", NullValueHandling.Ignore)] public string? PostId { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("comment_likes")]
public sealed class CommentLikesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("comment_id", NullValueHandling.Ignore)] public string? CommentId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("communities")]
public sealed class CommunitiesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("name", NullValueHandling.Ignore)] public string? Name { get; set; }
    [Column("slug", NullValueHandling.Ignore)] public string? Slug { get; set; }
    [Column("description", NullValueHandling.Ignore)] public string? Description { get; set; }
    [Column("image_url", NullValueHandling.Ignore)] public string? ImageUrl { get; set; }
    [Column("banner_url", NullValueHandling.Ignore)] public string? BannerUrl { get; set; }
    [Column("rules", NullValueHandling.Ignore)] public string? Rules { get; set; }
    [Column("members_count", NullValueHandling.Ignore)] public long? MembersCount { get; set; }
    [Column("posts_count", NullValueHandling.Ignore)] public long? PostsCount { get; set; }
    [Column("creator_id", NullValueHandling.Ignore)] public string? CreatorId { get; set; }
    [Column("is_private", NullValueHandling.Ignore)] public bool? IsPrivate { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("community_members")]
public sealed class CommunityMembersRow : BaseModel
{
    [Column("community_id", NullValueHandling.Ignore)] public string? CommunityId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("role", NullValueHandling.Ignore)] public string? Role { get; set; }
    [Column("joined_at", NullValueHandling.Ignore)] public DateTime? JoinedAt { get; set; }
}

[Table("conversation_participants")]
public sealed class ConversationParticipantsRow : BaseModel
{
    [Column("conversation_id", NullValueHandling.Ignore)] public string? ConversationId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("last_read_at", NullValueHandling.Ignore)] public DateTime? LastReadAt { get; set; }
    [Column("unread_count", NullValueHandling.Ignore)] public long? UnreadCount { get; set; }
}

[Table("message_read_receipts")]
public sealed class MessageReadReceiptsRow : BaseModel
{
    [Column("message_id", NullValueHandling.Ignore)] public string? MessageId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("read_at", NullValueHandling.Ignore)] public DateTime? ReadAt { get; set; }
}

[Table("typing_indicators")]
public sealed class TypingIndicatorRow : BaseModel
{
    [Column("conversation_id", NullValueHandling.Ignore)] public string? ConversationId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("is_typing", NullValueHandling.Ignore)] public bool? IsTyping { get; set; }
    [Column("updated_at", NullValueHandling.Ignore)] public DateTime? UpdatedAt { get; set; }
}

[Table("messages")]
public sealed class MessagesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("conversation_id", NullValueHandling.Ignore)] public string? ConversationId { get; set; }
    [Column("sender_id", NullValueHandling.Ignore)] public string? SenderId { get; set; }
    [Column("content", NullValueHandling.Ignore)] public string? Content { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("message_type", NullValueHandling.Ignore)] public string? MessageType { get; set; }
    [Column("image_url", NullValueHandling.Ignore)] public string? ImageUrl { get; set; }
    [Column("voice_url", NullValueHandling.Ignore)] public string? VoiceUrl { get; set; }
    [Column("file_url", NullValueHandling.Ignore)] public string? FileUrl { get; set; }
    [Column("file_name", NullValueHandling.Ignore)] public string? FileName { get; set; }
    [Column("file_size", NullValueHandling.Ignore)] public long? FileSize { get; set; }
    [Column("voice_duration", NullValueHandling.Ignore)] public int? VoiceDuration { get; set; }
    [Column("iv", NullValueHandling.Ignore)] public string? Iv { get; set; }
    [Column("pq_aura_header", NullValueHandling.Ignore)] public string? PqAuraHeader { get; set; }
    [Column("pq_aura_payload", NullValueHandling.Ignore)] public string? PqAuraPayload { get; set; }
}

[Table("pq_keys")]
public sealed class PqKeysRow : BaseModel
{
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("identity_pk", NullValueHandling.Ignore)] public string? IdentityPk { get; set; }
    [Column("bundle", NullValueHandling.Include)] public Dictionary<string, object?>? Bundle { get; set; }
}

[Table("stories")]
public sealed class StoriesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("media_url", NullValueHandling.Ignore)] public string? MediaUrl { get; set; }
    [Column("media_type", NullValueHandling.Ignore)] public string? MediaType { get; set; }
    [Column("caption", NullValueHandling.Ignore)] public string? Caption { get; set; }
    [Column("duration_seconds", NullValueHandling.Ignore)] public int? DurationSeconds { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("expires_at", NullValueHandling.Ignore)] public DateTime? ExpiresAt { get; set; }
    [Column("views_count", NullValueHandling.Ignore)] public long? ViewsCount { get; set; }
}

[Table("capsules")]
public sealed class CapsulesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("title", NullValueHandling.Ignore)] public string? Title { get; set; }
    [Column("content", NullValueHandling.Ignore)] public string? Content { get; set; }
    [Column("media_urls", NullValueHandling.Ignore)] public string[]? MediaUrls { get; set; }
    [Column("unlock_at", NullValueHandling.Ignore)] public DateTime? UnlockAt { get; set; }
    [Column("is_unlocked", NullValueHandling.Ignore)] public bool? IsUnlocked { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("notifications")]
public sealed class NotificationsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("actor_id", NullValueHandling.Ignore)] public string? ActorId { get; set; }
    [Column("type", NullValueHandling.Ignore)] public string? Type { get; set; }
    [Column("title", NullValueHandling.Ignore)] public string? Title { get; set; }
    [Column("body", NullValueHandling.Ignore)] public string? Body { get; set; }
    [Column("entity_id", NullValueHandling.Ignore)] public string? EntityId { get; set; }
    [Column("entity_type", NullValueHandling.Ignore)] public string? EntityType { get; set; }
    [Column("is_read", NullValueHandling.Ignore)] public bool? IsRead { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("collections")]
public sealed class CollectionsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("name", NullValueHandling.Ignore)] public string? Name { get; set; }
    [Column("description", NullValueHandling.Ignore)] public string? Description { get; set; }
    [Column("is_private", NullValueHandling.Ignore)] public bool? IsPrivate { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("items_count", NullValueHandling.Ignore)] public long? ItemsCount { get; set; }
}

[Table("collection_items")]
public sealed class CollectionItemsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("collection_id", NullValueHandling.Ignore)] public string? CollectionId { get; set; }
    [Column("post_id", NullValueHandling.Ignore)] public string? PostId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("added_at", NullValueHandling.Ignore)] public DateTime? AddedAt { get; set; }
}

[Table("wellness_sessions")]
public sealed class WellnessSessionsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("session_type", NullValueHandling.Ignore)] public string? SessionType { get; set; }
    [Column("duration_minutes", NullValueHandling.Ignore)] public int? DurationMinutes { get; set; }
    [Column("energy_before", NullValueHandling.Ignore)] public int? EnergyBefore { get; set; }
    [Column("energy_after", NullValueHandling.Ignore)] public int? EnergyAfter { get; set; }
    [Column("notes", NullValueHandling.Ignore)] public string? Notes { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
}

[Table("achievements")]
public sealed class AchievementsRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("badge_key", NullValueHandling.Ignore)] public string? BadgeKey { get; set; }
    [Column("title", NullValueHandling.Ignore)] public string? Title { get; set; }
    [Column("description", NullValueHandling.Ignore)] public string? Description { get; set; }
    [Column("unlocked_at", NullValueHandling.Ignore)] public DateTime? UnlockedAt { get; set; }
}

[Table("chat_themes")]
public sealed class ChatThemesRow : BaseModel
{
    [PrimaryKey("id", true)]
    [Column("id", NullValueHandling.Ignore)] public string? Id { get; set; }
    [Column("conversation_id", NullValueHandling.Ignore)] public string? ConversationId { get; set; }
    [Column("user_id", NullValueHandling.Ignore)] public string? UserId { get; set; }
    [Column("background_image_url", NullValueHandling.Ignore)] public string? BackgroundImageUrl { get; set; }
    [Column("theme_name", NullValueHandling.Ignore)] public string? ThemeName { get; set; }
    [Column("created_at", NullValueHandling.Ignore)] public DateTime? CreatedAt { get; set; }
    [Column("updated_at", NullValueHandling.Ignore)] public DateTime? UpdatedAt { get; set; }
}
