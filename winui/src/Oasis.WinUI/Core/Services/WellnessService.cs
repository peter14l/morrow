using System.Text.Json;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Postgrest;

namespace Oasis.WinUI.Core.Services;

public sealed class WellnessStats
{
    public int FocusMinutesToday { get; set; }
    public int FocusMinutesThisWeek { get; set; }
    public int CurrentEnergyLevel { get; set; } = 80;
    public List<AchievementsRow> UnlockedAchievements { get; set; } = new();
    public List<WellnessSessionsRow> RecentSessions { get; set; } = new();
}

/// <summary>
/// Digital wellbeing, focus tracking & energy meter service mirroring lib/features/wellness
/// </summary>
public sealed class WellnessService
{
    private static string CurrentUserId => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public async Task<WellnessStats> GetWellnessStatsAsync()
    {
        var stats = new WellnessStats();
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return stats;

        try
        {
            var sessionsResponse = await SupabaseService.Client.From<WellnessSessionsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(50)
                .Get();

            if (sessionsResponse?.Models != null)
            {
                stats.RecentSessions = sessionsResponse.Models;
                var today = DateTime.UtcNow.Date;
                var startOfWeek = today.AddDays(-(int)today.DayOfWeek);

                stats.FocusMinutesToday = stats.RecentSessions
                    .Where(s => s.CreatedAt?.Date == today)
                    .Sum(s => s.DurationMinutes ?? 0);

                stats.FocusMinutesThisWeek = stats.RecentSessions
                    .Where(s => s.CreatedAt?.Date >= startOfWeek)
                    .Sum(s => s.DurationMinutes ?? 0);

                var latestSession = stats.RecentSessions.FirstOrDefault();
                if (latestSession?.EnergyAfter != null)
                {
                    stats.CurrentEnergyLevel = latestSession.EnergyAfter.Value;
                }
            }

            var achResponse = await SupabaseService.Client.From<AchievementsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Get();

            if (achResponse?.Models != null)
            {
                stats.UnlockedAchievements = achResponse.Models;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("Wellness.Stats", ex.Message);
        }

        return stats;
    }

    public async Task<bool> RecordFocusSessionAsync(string sessionType, int durationMinutes, int energyBefore, int energyAfter, string? notes = null)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return false;

        try
        {
            var session = new WellnessSessionsRow
            {
                UserId = userId,
                SessionType = sessionType,
                DurationMinutes = durationMinutes,
                EnergyBefore = energyBefore,
                EnergyAfter = energyAfter,
                Notes = notes,
                CreatedAt = DateTime.UtcNow
            };

            await SupabaseService.Client.From<WellnessSessionsRow>().Insert(session);

            // Award achievement if completed first session or long focus
            if (durationMinutes >= 25)
            {
                await TryAwardAchievementAsync("focus_master", "Deep Focus", "Completed a 25+ minute focus session.");
            }

            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Wellness.Record", ex.Message);
            return false;
        }
    }

    public async Task TryAwardAchievementAsync(string badgeKey, string title, string description)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return;

        try
        {
            var existing = await SupabaseService.Client.From<AchievementsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Filter("badge_key", Postgrest.Constants.Operator.Equals, badgeKey)
                .Get();

            if (existing?.Models != null && existing.Models.Count > 0) return;

            await SupabaseService.Client.From<AchievementsRow>().Insert(new AchievementsRow
            {
                UserId = userId,
                BadgeKey = badgeKey,
                Title = title,
                Description = description,
                UnlockedAt = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            Logger.Warn("Wellness.Achievement", ex.Message);
        }
    }
}
