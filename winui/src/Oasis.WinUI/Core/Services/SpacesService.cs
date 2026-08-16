using System.Text.Json;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Core.Services;

/// <summary>
/// Community ("Spaces") operations mirroring lib/services/community_service.dart.
/// </summary>
public sealed class SpacesService
{
    private static string CurrentUserId
        => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public async Task<List<Community>> GetCommunitiesAsync(int limit = 20, int offset = 0)
    {
        try
        {
            var userId = CurrentUserId;
            var response = await SupabaseService.Client.From<CommunitiesRow>()
                .Select("*")
                .Order("members_count", Postgrest.Constants.Ordering.Descending)
                .Range(offset, offset + limit - 1)
                .Get();

            var communities = Community.FromJsonArray(response?.Content ?? "");
            await AnnotateMembershipAsync(communities, userId);
            return communities;
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.List", ex.Message);
            return new List<Community>();
        }
    }

    public async Task<Community?> GetCommunityAsync(string communityId)
    {
        try
        {
            var response = await SupabaseService.Client.From<CommunitiesRow>()
                .Select("*")
                .Filter("id", Postgrest.Constants.Operator.Equals, communityId)
                .Limit(1)
                .Get();

            var list = Community.FromJsonArray(response?.Content ?? "");
            if (list.Count == 0) return null;

            var community = list[0];
            community.IsMember = await IsMemberAsync(communityId);
            return community;
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Get", ex.Message);
            return null;
        }
    }

    public async Task<bool> IsMemberAsync(string communityId)
    {
        var userId = CurrentUserId;
        try
        {
            var response = await SupabaseService.Client.From<CommunityMembersRow>()
                .Select("role")
                .Filter("community_id", Postgrest.Constants.Operator.Equals, communityId)
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content) || response.Content == "[]") return false;

            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return false;
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.IsMember", ex.Message);
            return false;
        }
    }

    public async Task<string?> GetMemberRoleAsync(string communityId)
    {
        var userId = CurrentUserId;
        try
        {
            var response = await SupabaseService.Client.From<CommunityMembersRow>()
                .Select("role")
                .Filter("community_id", Postgrest.Constants.Operator.Equals, communityId)
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content) || response.Content == "[]") return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            return JsonUtil.S(doc.RootElement[0], "role");
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Role", ex.Message);
            return null;
        }
    }

    public async Task<bool> JoinCommunityAsync(string communityId)
    {
        var userId = CurrentUserId;
        try
        {
            await SupabaseService.Client.From<CommunityMembersRow>()
                .Insert(new CommunityMembersRow { CommunityId = communityId, UserId = userId, Role = "member" });
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Join", ex.Message);
            return false;
        }
    }

    public async Task<bool> LeaveCommunityAsync(string communityId)
    {
        var userId = CurrentUserId;
        try
        {
            await SupabaseService.Client.From<CommunityMembersRow>()
                .Filter("community_id", Postgrest.Constants.Operator.Equals, communityId)
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Delete();
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Leave", ex.Message);
            return false;
        }
    }

    public async Task<Community?> CreateCommunityAsync(string name, string? description = null, bool isPrivate = false)
    {
        var userId = CurrentUserId;
        var communityId = Guid.NewGuid().ToString();

        try
        {
            await SupabaseService.Client.From<CommunitiesRow>()
                .Insert(new CommunitiesRow
                {
                    Id = communityId,
                    Name = name,
                    Description = description,
                    IsPrivate = isPrivate,
                    CreatorId = userId,
                });

            await SupabaseService.Client.From<CommunityMembersRow>()
                .Insert(new CommunityMembersRow { CommunityId = communityId, UserId = userId, Role = "admin" });

            return await GetCommunityAsync(communityId);
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Create", ex.Message);
            return null;
        }
    }

    public async Task<List<Post>> GetCommunityPostsAsync(string communityId, int limit = 20)
    {
        try
        {
            var response = await SupabaseService.Client.From<PostsRow>()
                .Select("*")
                .Filter("community_id", Postgrest.Constants.Operator.Equals, communityId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(limit)
                .Get();

            return Post.FromJsonArray(response?.Content ?? "");
        }
        catch (Exception ex)
        {
            Logger.Warn("Spaces.Posts", ex.Message);
            return new List<Post>();
        }
    }

    // ------------------------------------------------------------------

    private static async Task AnnotateMembershipAsync(List<Community> communities, string userId)
    {
        foreach (var community in communities)
        {
            try
            {
                var response = await SupabaseService.Client.From<CommunityMembersRow>()
                    .Select("role")
                    .Filter("community_id", Postgrest.Constants.Operator.Equals, community.Id)
                    .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                    .Limit(1)
                    .Get();

                if (!string.IsNullOrWhiteSpace(response?.Content) && response.Content != "[]")
                {
                    community.IsMember = true;
                    using var doc = JsonDocument.Parse(response.Content);
                    if (doc.RootElement.ValueKind == JsonValueKind.Array && doc.RootElement.GetArrayLength() > 0)
                        community.Role = JsonUtil.S(doc.RootElement[0], "role");
                }
            }
            catch
            {
                // ignore
            }
        }
    }
}
