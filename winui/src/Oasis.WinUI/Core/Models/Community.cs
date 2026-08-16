using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

/// <summary>
/// A community ("Spaces"). Mirrors lib/features/community or the community
/// service Community model in the Flutter app.
/// </summary>
public sealed class Community
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Slug { get; set; } = "";
    public string Description { get; set; } = "";
    public string? ImageUrl { get; set; }
    public string? BannerUrl { get; set; }
    public string? Rules { get; set; }
    public long MembersCount { get; set; }
    public long PostsCount { get; set; }
    public string CreatorId { get; set; } = "";
    public bool IsPrivate { get; set; }
    public bool IsMember { get; set; }
    public string? Role { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    public static Community FromJson(JsonElement el)
    {
        return new Community
        {
            Id = JsonUtil.S(el, "id") ?? "",
            Name = JsonUtil.S(el, "name") ?? "",
            Slug = JsonUtil.S(el, "slug") ?? "",
            Description = JsonUtil.S(el, "description") ?? "",
            ImageUrl = JsonUtil.S(el, "image_url"),
            BannerUrl = JsonUtil.S(el, "banner_url"),
            Rules = JsonUtil.S(el, "rules"),
            MembersCount = JsonUtil.L(el, "members_count", "members"),
            PostsCount = JsonUtil.L(el, "posts_count", "posts"),
            CreatorId = JsonUtil.S(el, "creator_id") ?? "",
            IsPrivate = JsonUtil.B(el, "is_private"),
            IsMember = JsonUtil.B(el, "is_member"),
            Role = JsonUtil.S(el, "role"),
            CreatedAt = JsonUtil.Dt(el, "created_at") ?? DateTime.Now,
        };
    }

    public static List<Community> FromJsonArray(string json)
    {
        var result = new List<Community>();
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
