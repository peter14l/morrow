using Supabase.Gotrue;

namespace Oasis.WinUI.Core.Auth;

public sealed class RegisteredAccount
{
    public required string UserId { get; init; }
    public required string Email { get; init; }
    public required string Username { get; init; }
    public string? FullName { get; init; }
    public string? AvatarUrl { get; init; }
    public required Session Session { get; init; }
    public DateTime LastUsed { get; init; } = DateTime.Now;

    public static RegisteredAccount From(User user, Session session)
    {
        var metadata = user.UserMetadata ?? new Dictionary<string, object>();
        string? Get(string key) => metadata.TryGetValue(key, out var v) ? v?.ToString() : null;

        return new RegisteredAccount
        {
            UserId = user.Id,
            Email = user.Email ?? string.Empty,
            Username = Get("username") ?? user.Email?.Split('@')[0] ?? "user",
            FullName = Get("full_name"),
            AvatarUrl = Get("avatar_url"),
            Session = session,
        };
    }
}
