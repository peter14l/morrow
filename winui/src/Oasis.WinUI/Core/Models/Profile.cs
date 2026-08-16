using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

public sealed class Profile
{
    public string Id { get; set; } = "";
    public string Username { get; set; } = "";
    public string FullName { get; set; } = "";
    public string AvatarUrl { get; set; } = "";
    public string Bio { get; set; } = "";
    public bool IsVerified { get; set; }
    public bool IsPro { get; set; }
    public bool IsPrivate { get; set; }
    public string? PublicKey { get; set; }
    public DateTime? CreatedAt { get; set; }
    public long FollowersCount { get; set; }
    public long FollowingCount { get; set; }
    public long PostsCount { get; set; }
    public long Xp { get; set; }
    public int Level { get; set; }
    public string? Location { get; set; }
    public string? Website { get; set; }

    public string DisplayName => !string.IsNullOrEmpty(Username) ? Username : (!string.IsNullOrEmpty(FullName) ? FullName : "Oasis user");

    public static Profile FromJson(JsonElement el)
    {
        return new Profile
        {
            Id = JsonUtil.S(el, "id") ?? "",
            Username = JsonUtil.S(el, "username") ?? "",
            FullName = JsonUtil.S(el, "full_name") ?? "",
            AvatarUrl = JsonUtil.S(el, "avatar_url") ?? "",
            Bio = JsonUtil.S(el, "bio") ?? "",
            IsVerified = JsonUtil.B(el, "is_verified"),
            IsPro = JsonUtil.B(el, "is_pro"),
            IsPrivate = JsonUtil.B(el, "is_private"),
            PublicKey = JsonUtil.S(el, "public_key"),
            CreatedAt = JsonUtil.Dt(el, "created_at"),
            FollowersCount = JsonUtil.L(el, "followers_count"),
            FollowingCount = JsonUtil.L(el, "following_count"),
            PostsCount = JsonUtil.L(el, "posts_count"),
            Xp = JsonUtil.L(el, "xp"),
            Level = JsonUtil.I(el, "level"),
            Location = JsonUtil.S(el, "location"),
            Website = JsonUtil.S(el, "website"),
        };
    }

    public static List<Profile> FromJsonArray(string json)
    {
        var result = new List<Profile>();
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
            // malformed payload
        }
        return result;
    }
}
