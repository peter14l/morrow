using System.Text.Json;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Postgrest;

namespace Oasis.WinUI.Core.Services;

/// <summary>
/// Feed operations mirroring lib/services/feed_service.dart and
/// lib/services/comment_service.dart.
/// </summary>
public sealed class FeedService
{
    private static string CurrentUserId
        => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    // ------------------------------------------------------------------
    // Feed
    // ------------------------------------------------------------------

    /// <summary>
    /// Fetch the feed using the get_feed_posts RPC (cursor pagination).
    /// Falls back to a direct query when the RPC is missing.
    /// </summary>
    public async Task<List<Post>> GetFeedPostsAsync(int limit = 20, DateTime? cursor = null)
    {
        var userId = CurrentUserId;
        var json = await RpcAsync("get_feed_posts", new Dictionary<string, object?>
        {
            ["p_user_id"] = userId,
            ["p_limit"] = limit,
            ["p_cursor_timestamp"] = cursor,
        });

        if (json != null)
        {
            var posts = Post.FromJsonArray(json);
            if (posts.Count > 0 || cursor == null) return posts;
        }

        return await FetchFeedDirectAsync(userId, limit, cursor);
    }

    private static async Task<List<Post>> FetchFeedDirectAsync(string userId, int limit, DateTime? cursor)
    {
        try
        {
            var builder = SupabaseService.Client.From<PostsRow>()
                .Select("*")
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(limit);

            if (cursor != null)
            {
                builder = builder.Filter("created_at", Postgrest.Constants.Operator.LessThan, cursor.Value);
            }

            var response = await builder.Get();
            return Post.FromJsonArray(response?.Content ?? "");
        }
        catch (Exception ex)
        {
            Logger.Warn("Feed.Fallback", ex.Message);
            return new List<Post>();
        }
    }

    // ------------------------------------------------------------------
    // Likes / bookmarks / share / delete
    // ------------------------------------------------------------------

    public async Task LikeAsync(string postId)
    {
        var userId = CurrentUserId;
        if (await RowExistsAsync<LikesRow>("user_id", userId, "post_id", postId)) return;
        await SupabaseService.Client.From<LikesRow>().Insert(new LikesRow { UserId = userId, PostId = postId });
    }

    public async Task UnlikeAsync(string postId)
    {
        var userId = CurrentUserId;
        await DeleteAsync<LikesRow>(("user_id", userId), ("post_id", postId));
    }

    public async Task BookmarkAsync(string postId)
    {
        var userId = CurrentUserId;
        await SupabaseService.Client.From<BookmarksRow>().Insert(new BookmarksRow { UserId = userId, PostId = postId });
    }

    public async Task UnbookmarkAsync(string postId)
    {
        var userId = CurrentUserId;
        await DeleteAsync<BookmarksRow>(("user_id", userId), ("post_id", postId));
    }

    public async Task SharePostAsync(string postId)
    {
        try
        {
            var response = await SupabaseService.Client.From<PostsRow>()
                .Select("shares_count")
                .Filter("id", Postgrest.Constants.Operator.Equals, postId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content)) return;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return;

            var count = JsonUtil.L(doc.RootElement[0], "shares_count");
            await SupabaseService.Client.From<PostsRow>()
                .Filter("id", Postgrest.Constants.Operator.Equals, postId)
                .Update(new PostsRow { SharesCount = count + 1 });
        }
        catch (Exception ex)
        {
            Logger.Warn("Feed.Share", ex.Message);
        }
    }

    public async Task DeletePostAsync(string postId)
        => await SupabaseService.Client.From<PostsRow>()
            .Filter("id", Postgrest.Constants.Operator.Equals, postId)
            .Delete();

    // ------------------------------------------------------------------
    // Comments
    // ------------------------------------------------------------------

    public async Task<List<Comment>> GetPostCommentsAsync(string postId, int limit = 50)
    {
        var userId = CurrentUserId;
        var response = await SupabaseService.Client.From<CommentsRow>()
            .Select("*")
            .Filter("post_id", Postgrest.Constants.Operator.Equals, postId)
            .Order("created_at", Postgrest.Constants.Ordering.Descending)
            .Limit(limit)
            .Get();

        var comments = Comment.FromJsonArray(response?.Content ?? "");
        await AnnotateLikesAsync(comments, userId);
        return comments;
    }

    public async Task<List<Comment>> GetCommentRepliesAsync(string commentId, int limit = 20)
    {
        var userId = CurrentUserId;
        var response = await SupabaseService.Client.From<CommentsRow>()
            .Select("*")
            .Filter("parent_comment_id", Postgrest.Constants.Operator.Equals, commentId)
            .Order("created_at", Postgrest.Constants.Ordering.Ascending)
            .Limit(limit)
            .Get();

        var replies = Comment.FromJsonArray(response?.Content ?? "");
        await AnnotateLikesAsync(replies, userId);
        return replies;
    }

    public async Task<Comment?> CreateCommentAsync(string postId, string content, string? parentCommentId = null)
    {
        var userId = CurrentUserId;
        var commentId = Guid.NewGuid().ToString();

        await SupabaseService.Client.From<CommentsRow>().Insert(new CommentsRow
        {
            Id = commentId,
            UserId = userId,
            PostId = postId,
            ParentCommentId = parentCommentId,
            Content = content,
        });

        var response = await SupabaseService.Client.From<CommentsRow>()
            .Select("*")
            .Filter("id", Postgrest.Constants.Operator.Equals, commentId)
            .Limit(1)
            .Get();

        var list = Comment.FromJsonArray(response?.Content ?? "");
        return list.Count > 0 ? list[0] : null;
    }

    public async Task LikeCommentAsync(string commentId)
    {
        var userId = CurrentUserId;
        if (await RowExistsAsync<CommentLikesRow>("comment_id", commentId, "user_id", userId)) return;
        await SupabaseService.Client.From<CommentLikesRow>().Insert(new CommentLikesRow { CommentId = commentId, UserId = userId });
    }

    public async Task UnlikeCommentAsync(string commentId)
    {
        var userId = CurrentUserId;
        await DeleteAsync<CommentLikesRow>(("comment_id", commentId), ("user_id", userId));
    }

    // ------------------------------------------------------------------
    // Post creation
    // ------------------------------------------------------------------

    public async Task<Post?> CreatePostAsync(string content, string? imageUrl = null, string? communityId = null, bool isAd = false)
    {
        var userId = CurrentUserId;
        var postId = Guid.NewGuid().ToString();

        await SupabaseService.Client.From<PostsRow>().Insert(new PostsRow
        {
            Id = postId,
            UserId = userId,
            Content = content,
            ImageUrl = imageUrl,
            CommunityId = communityId,
            IsAd = isAd,
        });

        var response = await SupabaseService.Client.From<PostsRow>()
            .Select("*")
            .Filter("id", Postgrest.Constants.Operator.Equals, postId)
            .Limit(1)
            .Get();

        var list = Post.FromJsonArray(response?.Content ?? "");
        return list.Count > 0 ? list[0] : null;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private static async Task<string?> RpcAsync(string fn, Dictionary<string, object?> parameters)
    {
        try
        {
            var response = await SupabaseService.Client.Rpc(fn, parameters);
            return string.IsNullOrWhiteSpace(response?.Content) ? null : response.Content;
        }
        catch (Exception ex)
        {
            Logger.Warn($"Feed.Rpc({fn})", ex.Message);
            return null;
        }
    }

    private static async Task DeleteAsync<TRow>(params (string, object)[] filters) where TRow : Postgrest.Models.BaseModel, new()
    {
        Postgrest.Interfaces.IPostgrestTable<TRow> builder = SupabaseService.Client.From<TRow>();
        foreach (var (col, val) in filters)
            builder = builder.Filter(col, Postgrest.Constants.Operator.Equals, val);
        await builder.Delete();
    }

    private static async Task<bool> RowExistsAsync<TRow>(string colA, object valA, string colB, object valB) where TRow : Postgrest.Models.BaseModel, new()
    {
        try
        {
            var response = await SupabaseService.Client.From<TRow>()
                .Select("id")
                .Filter(colA, Postgrest.Constants.Operator.Equals, valA)
                .Filter(colB, Postgrest.Constants.Operator.Equals, valB)
                .Limit(1)
                .Get();
            return !string.IsNullOrWhiteSpace(response?.Content) && response.Content != "[]";
        }
        catch
        {
            // RLS may block SELECT; let the insert decide
            return false;
        }
    }

    private static async Task AnnotateLikesAsync(List<Comment> comments, string userId)
    {
        foreach (var comment in comments)
        {
            if (comment.Id.Length == 0) continue;
            try
            {
                var response = await SupabaseService.Client.From<CommentLikesRow>()
                    .Select("id")
                    .Filter("comment_id", Postgrest.Constants.Operator.Equals, comment.Id)
                    .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                    .Limit(1)
                    .Get();
                comment.IsLiked = !string.IsNullOrWhiteSpace(response?.Content) && response.Content != "[]";
            }
            catch
            {
                // ignore
            }
        }
    }
}
