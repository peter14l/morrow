using System.Text.Json;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Postgrest;

namespace Oasis.WinUI.Core.Services;

/// <summary>
/// Universal search service mirroring lib/features/search
/// </summary>
public sealed class SearchService
{
    private static string CurrentUserId => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public async Task<List<Profile>> SearchUsersAsync(string query, int limit = 20)
    {
        if (string.IsNullOrWhiteSpace(query)) return new List<Profile>();
        try
        {
            var cleanQuery = query.Trim().TrimStart('@');
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("*")
                .Filter("username", Postgrest.Constants.Operator.ILike, $"%{cleanQuery}%")
                .Limit(limit)
                .Get();

            if (string.IsNullOrEmpty(response?.Content)) return new List<Profile>();
            return Profile.FromJsonArray(response.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Search.Users", ex.Message);
            return new List<Profile>();
        }
    }

    public async Task<List<Post>> SearchPostsAsync(string query, int limit = 20)
    {
        if (string.IsNullOrWhiteSpace(query)) return new List<Post>();
        try
        {
            var cleanQuery = query.Trim();
            var response = await SupabaseService.Client.From<PostsRow>()
                .Select("*")
                .Filter("content", Postgrest.Constants.Operator.ILike, $"%{cleanQuery}%")
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(limit)
                .Get();

            if (string.IsNullOrEmpty(response?.Content)) return new List<Post>();
            return Post.FromJsonArray(response.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Search.Posts", ex.Message);
            return new List<Post>();
        }
    }

    public async Task<List<Community>> SearchCirclesAsync(string query, int limit = 20)
    {
        if (string.IsNullOrWhiteSpace(query)) return new List<Community>();
        try
        {
            var cleanQuery = query.Trim();
            var response = await SupabaseService.Client.From<CommunitiesRow>()
                .Select("*")
                .Filter("name", Postgrest.Constants.Operator.ILike, $"%{cleanQuery}%")
                .Limit(limit)
                .Get();

            if (string.IsNullOrEmpty(response?.Content)) return new List<Community>();
            return Community.FromJsonArray(response.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Search.Circles", ex.Message);
            return new List<Community>();
        }
    }
}
