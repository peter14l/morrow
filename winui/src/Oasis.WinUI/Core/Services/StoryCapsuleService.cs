using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Postgrest;

namespace Oasis.WinUI.Core.Services;

public sealed class StoryCapsuleService
{
    private static string CurrentUserId => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    // ---------------------------------------------------------
    // Stories
    // ---------------------------------------------------------

    public async Task<List<StoriesRow>> GetActiveStoriesAsync()
    {
        try
        {
            var now = DateTime.UtcNow;
            var response = await SupabaseService.Client.From<StoriesRow>()
                .Select("*")
                .Filter("expires_at", Postgrest.Constants.Operator.GreaterThan, now)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(50)
                .Get();

            return response?.Models ?? new List<StoriesRow>();
        }
        catch (Exception ex)
        {
            Logger.Warn("Stories.Active", ex.Message);
            return new List<StoriesRow>();
        }
    }

    public async Task<bool> PostStoryAsync(string mediaUrl, string mediaType, string caption, int durationSeconds = 15)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return false;

        try
        {
            var story = new StoriesRow
            {
                UserId = userId,
                MediaUrl = mediaUrl,
                MediaType = mediaType,
                Caption = caption,
                DurationSeconds = durationSeconds,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddHours(24),
                ViewsCount = 0
            };

            await SupabaseService.Client.From<StoriesRow>().Insert(story);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Stories.Post", ex.Message);
            return false;
        }
    }

    // ---------------------------------------------------------
    // Capsules (Time-locked stories/messages)
    // ---------------------------------------------------------

    public async Task<List<CapsulesRow>> GetUserCapsulesAsync()
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return new List<CapsulesRow>();

        try
        {
            var response = await SupabaseService.Client.From<CapsulesRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Get();

            return response?.Models ?? new List<CapsulesRow>();
        }
        catch (Exception ex)
        {
            Logger.Warn("Capsules.Get", ex.Message);
            return new List<CapsulesRow>();
        }
    }

    public async Task<bool> CreateCapsuleAsync(string title, string content, DateTime unlockAt, string[]? mediaUrls = null)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return false;

        try
        {
            var capsule = new CapsulesRow
            {
                UserId = userId,
                Title = title,
                Content = content,
                MediaUrls = mediaUrls,
                UnlockAt = unlockAt,
                IsUnlocked = unlockAt <= DateTime.UtcNow,
                CreatedAt = DateTime.UtcNow
            };

            await SupabaseService.Client.From<CapsulesRow>().Insert(capsule);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Capsules.Create", ex.Message);
            return false;
        }
    }
}
