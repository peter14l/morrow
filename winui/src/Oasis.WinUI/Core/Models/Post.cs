using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

/// <summary>
/// A feed post. Field names mirror the Flutter Post model
/// (lib/features/feed/domain/models/post.dart).
/// </summary>
public sealed class Post
{
    public string Id { get; set; } = "";
    public string UserId { get; set; } = "";
    public string Username { get; set; } = "";
    public string UserAvatar { get; set; } = "";
    public string Content { get; set; } = "";
    public string? ImageUrl { get; set; }
    public string? ThumbnailUrl { get; set; }
    public string? DominantColor { get; set; }
    public List<string> MediaUrls { get; set; } = new();
    public List<string> MediaTypes { get; set; } = new();
    public List<string> Hashtags { get; set; } = new();
    public bool IsSpoiler { get; set; }
    public string? CommunityId { get; set; }
    public string? CommunityName { get; set; }
    public string? CircleId { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.Now;
    public long Likes { get; set; }
    public long Comments { get; set; }
    public long Shares { get; set; }
    public bool IsLiked { get; set; }
    public bool IsBookmarked { get; set; }
    public bool IsAd { get; set; }
    public bool IsVerified { get; set; }
    public string? StorageProvider { get; set; }
    public string? Mood { get; set; }
    public string? Poll { get; set; }
    public List<string> Collaborators { get; set; } = new();

    public static Post FromJson(JsonElement el)
    {
        var post = new Post
        {
            Id = JsonUtil.S(el, "id") ?? "",
            UserId = JsonUtil.S(el, "user_id") ?? JsonUtil.S(el, "userId") ?? "",
            Username = JsonUtil.S(el, "username", "full_name")
                       ?? JsonUtil.NestedProfile(el, "profiles", "username")
                       ?? JsonUtil.NestedProfile(el, "user", "username") ?? "",
            UserAvatar = JsonUtil.S(el, "avatar_url", "user_avatar", "userAvatar")
                         ?? JsonUtil.NestedProfile(el, "profiles", "avatar_url") ?? "",
            Content = JsonUtil.S(el, "content") ?? "",
            ImageUrl = JsonUtil.S(el, "image_url", "imageUrl"),
            ThumbnailUrl = JsonUtil.S(el, "thumbnail_url"),
            DominantColor = JsonUtil.S(el, "dominant_color"),
            MediaUrls = JsonUtil.StrList(el, "media_urls", "mediaUrls"),
            MediaTypes = JsonUtil.StrList(el, "media_types", "mediaTypes"),
            Hashtags = JsonUtil.StrList(el, "hashtags"),
            IsSpoiler = JsonUtil.B(el, "is_spoiler"),
            CommunityId = JsonUtil.S(el, "community_id"),
            CommunityName = JsonUtil.NestedProfile(el, "communities", "name")
                            ?? JsonUtil.S(el, "community_name"),
            CircleId = JsonUtil.S(el, "circle_id", "circleId"),
            Timestamp = JsonUtil.Dt(el, "created_at", "timestamp") ?? DateTime.Now,
            Likes = JsonUtil.L(el, "likes_count", "likes"),
            Comments = JsonUtil.L(el, "comments_count", "comments"),
            Shares = JsonUtil.L(el, "shares_count", "shares"),
            IsLiked = JsonUtil.B(el, "is_liked", "isLiked"),
            IsBookmarked = JsonUtil.B(el, "is_bookmarked", "isBookmarked"),
            IsAd = JsonUtil.B(el, "is_ad", "isAd"),
            IsVerified = JsonUtil.B(el, "is_verified", "isVerified"),
            StorageProvider = JsonUtil.S(el, "storage_provider"),
            Mood = JsonUtil.S(el, "mood"),
            Poll = JsonUtil.S(el, "poll"),
            Collaborators = JsonUtil.StrList(el, "collaborators"),
        };

        if (string.IsNullOrEmpty(post.Id) && el.TryGetProperty("id", out var idEl) && idEl.ValueKind != JsonValueKind.String)
            post.Id = idEl.ToString();
        if (post.MediaUrls.Count == 0 && !string.IsNullOrEmpty(post.ImageUrl))
            post.MediaUrls.Add(post.ImageUrl);

        return post;
    }

    public static List<Post> FromJsonArray(string json)
    {
        var result = new List<Post>();
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return result;
            foreach (var el in doc.RootElement.EnumerateArray())
            {
                if (el.ValueKind == JsonValueKind.Object) result.Add(FromJson(el));
            }
        }
        catch
        {
            // malformed payload -> empty feed
        }
        return result;
    }
}
