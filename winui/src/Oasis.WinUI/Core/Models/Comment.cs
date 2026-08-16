using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

public sealed class Comment
{
    public string Id { get; set; } = "";
    public string PostId { get; set; } = "";
    public string UserId { get; set; } = "";
    public string UserName { get; set; } = "";
    public string UserAvatar { get; set; } = "";
    public string Content { get; set; } = "";
    public DateTime Timestamp { get; set; } = DateTime.Now;
    public long LikesCount { get; set; }
    public long RepliesCount { get; set; }
    public bool IsLiked { get; set; }
    public string? ParentCommentId { get; set; }
    public bool IsEdited { get; set; }

    public static Comment FromJson(JsonElement el)
    {
        return new Comment
        {
            Id = JsonUtil.S(el, "id") ?? "",
            PostId = JsonUtil.S(el, "post_id") ?? "",
            UserId = JsonUtil.S(el, "user_id") ?? "",
            UserName = JsonUtil.S(el, "username", "full_name")
                       ?? JsonUtil.NestedProfile(el, "profiles", "username") ?? "",
            UserAvatar = JsonUtil.S(el, "avatar_url", "user_avatar")
                         ?? JsonUtil.NestedProfile(el, "profiles", "avatar_url") ?? "",
            Content = JsonUtil.S(el, "content") ?? "",
            Timestamp = JsonUtil.Dt(el, "created_at", "timestamp") ?? DateTime.Now,
            LikesCount = JsonUtil.L(el, "likes_count", "likes"),
            RepliesCount = JsonUtil.L(el, "replies_count", "replies"),
            IsLiked = JsonUtil.B(el, "is_liked", "isLiked"),
            ParentCommentId = JsonUtil.S(el, "parent_comment_id"),
            IsEdited = JsonUtil.B(el, "is_edited"),
        };
    }

    public static List<Comment> FromJsonArray(string json)
    {
        var result = new List<Comment>();
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
            // ignore
        }
        return result;
    }
}
