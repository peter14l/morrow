using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Postgrest;

namespace Oasis.WinUI.Core.Services;

public sealed class CollectionService
{
    private static string CurrentUserId => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public async Task<List<CollectionsRow>> GetUserCollectionsAsync()
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return new List<CollectionsRow>();

        try
        {
            var response = await SupabaseService.Client.From<CollectionsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Get();

            return response?.Models ?? new List<CollectionsRow>();
        }
        catch (Exception ex)
        {
            Logger.Warn("Collections.Get", ex.Message);
            return new List<CollectionsRow>();
        }
    }

    public async Task<CollectionsRow?> CreateCollectionAsync(string name, string? description = null, bool isPrivate = true)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return null;

        try
        {
            var collection = new CollectionsRow
            {
                UserId = userId,
                Name = name,
                Description = description,
                IsPrivate = isPrivate,
                CreatedAt = DateTime.UtcNow,
                ItemsCount = 0
            };

            var response = await SupabaseService.Client.From<CollectionsRow>().Insert(collection);
            return response?.Models.FirstOrDefault();
        }
        catch (Exception ex)
        {
            Logger.Warn("Collections.Create", ex.Message);
            return null;
        }
    }

    public async Task<bool> AddPostToCollectionAsync(string collectionId, string postId)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(userId)) return false;

        try
        {
            var item = new CollectionItemsRow
            {
                CollectionId = collectionId,
                PostId = postId,
                UserId = userId,
                AddedAt = DateTime.UtcNow
            };

            await SupabaseService.Client.From<CollectionItemsRow>().Insert(item);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Collections.AddItem", ex.Message);
            return false;
        }
    }

    public async Task<List<Post>> GetCollectionPostsAsync(string collectionId)
    {
        try
        {
            var itemsResponse = await SupabaseService.Client.From<CollectionItemsRow>()
                .Select("post_id")
                .Filter("collection_id", Postgrest.Constants.Operator.Equals, collectionId)
                .Get();

            var postIds = itemsResponse?.Models
                .Select(i => i.PostId)
                .Where(id => !string.IsNullOrEmpty(id))
                .Distinct()
                .ToList();

            if (postIds == null || postIds.Count == 0) return new List<Post>();

            var postsResponse = await SupabaseService.Client.From<PostsRow>()
                .Select("*")
                .Filter("id", Postgrest.Constants.Operator.In, postIds)
                .Get();

            return Post.FromJsonArray(postsResponse?.Content ?? "");
        }
        catch (Exception ex)
        {
            Logger.Warn("Collections.GetPosts", ex.Message);
            return new List<Post>();
        }
    }
}
