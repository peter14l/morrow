using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class FeedPage : Page
{
    private readonly FeedService _feed = new();
    private readonly StoryCapsuleService _storyService = new();
    private readonly ObservableCollection<Post> _posts = new();
    private readonly ObservableCollection<StoriesRow> _stories = new();
    private ObservableCollection<Comment>? _activeComments;
    private Comment? _replyTo;
    private TextBox? _commentInput;
    private TextBlock? _replyHint;
    private DateTime? _cursor;
    private bool _hasMore = true;
    private bool _loading;

    public FeedPage()
    {
        InitializeComponent();
        FeedList.ItemsSource = _posts;
        StoriesStrip.ItemsSource = _stories;
        Loaded += async (_, _) =>
        {
            await Task.WhenAll(LoadFeedAsync(reset: true), LoadStoriesAsync());
        };
    }

    private async Task LoadStoriesAsync()
    {
        try
        {
            _stories.Clear();
            var activeStories = await _storyService.GetActiveStoriesAsync();
            foreach (var s in activeStories) _stories.Add(s);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Stories", ex.Message);
        }
    }

    private async void PostStoryBtn_Click(object sender, RoutedEventArgs e)
    {
        var input = new TextBox { PlaceholderText = "Story caption or thoughts..." };
        var dialog = new ContentDialog
        {
            Title = "Add to Stories",
            Content = input,
            PrimaryButtonText = "Post Story",
            CloseButtonText = "Cancel",
            XamlRoot = XamlRoot
        };

        if (await dialog.ShowAsync() == ContentDialogResult.Primary && !string.IsNullOrWhiteSpace(input.Text))
        {
            await _storyService.PostStoryAsync("", "text", input.Text);
            await LoadStoriesAsync();
        }
    }

    private async Task LoadFeedAsync(bool reset)
    {
        if (_loading) return;
        _loading = true;
        LoadMoreButton.IsEnabled = false;
        try
        {
            if (reset)
            {
                _cursor = null;
                _hasMore = true;
                _posts.Clear();
            }

            var posts = await _feed.GetFeedPostsAsync(30, _cursor);
            if (posts.Count > 0)
            {
                _cursor = posts[^1].Timestamp;
                foreach (var p in posts) _posts.Add(p);
            }
            else
            {
                _hasMore = false;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Load", ex.Message);
        }
        finally
        {
            _loading = false;
            LoadMoreButton.IsEnabled = _hasMore;
        }
    }

    private void ReplaceItem(Post post)
    {
        var i = _posts.IndexOf(post);
        if (i < 0) return;
        _posts[i] = post;
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
        => await LoadFeedAsync(reset: true);

    private async void LoadMoreButton_Click(object sender, RoutedEventArgs e)
        => await LoadFeedAsync(reset: false);

    private async void PostButton_Click(object sender, RoutedEventArgs e)
    {
        var content = ComposerBox.Text?.Trim();
        if (string.IsNullOrEmpty(content)) return;
        try
        {
            await _feed.CreatePostAsync(content);
            ComposerBox.Text = "";
            await LoadFeedAsync(reset: true);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Post", ex.Message);
        }
    }

    private void FeedList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Post post) _ = ShowCommentsAsync(post);
    }

    private async void CommentButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is Post post) await ShowCommentsAsync(post);
    }

    private async void LikeButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Post post) return;
        try
        {
            if (post.IsLiked)
            {
                await _feed.UnlikeAsync(post.Id);
                post.IsLiked = false;
                if (post.Likes > 0) post.Likes--;
            }
            else
            {
                await _feed.LikeAsync(post.Id);
                post.IsLiked = true;
                post.Likes++;
            }
            ReplaceItem(post);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Like", ex.Message);
        }
    }

    private async void BookmarkButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Post post) return;
        try
        {
            if (post.IsBookmarked)
            {
                await _feed.UnbookmarkAsync(post.Id);
                post.IsBookmarked = false;
            }
            else
            {
                await _feed.BookmarkAsync(post.Id);
                post.IsBookmarked = true;
            }
            ReplaceItem(post);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Bookmark", ex.Message);
        }
    }

    private async void ShareButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Post post) return;
        try
        {
            await _feed.SharePostAsync(post.Id);
            post.Shares++;
            ReplaceItem(post);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Share", ex.Message);
        }
    }

    private async void DeletePostMenuItem_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Post post) return;
        try
        {
            await _feed.DeletePostAsync(post.Id);
            _posts.Remove(post);
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Delete", ex.Message);
        }
    }

    private async Task ShowCommentsAsync(Post post)
    {
        var comments = new ObservableCollection<Comment>();
        _activeComments = comments;
        _replyTo = null;

        var list = new ListView
        {
            ItemsSource = comments,
            ItemTemplate = (DataTemplate)Resources["CommentTemplate"],
            SelectionMode = ListViewSelectionMode.None,
            MaxHeight = 320,
        };

        var input = new TextBox { PlaceholderText = "Write a comment..." };
        _commentInput = input;

        var replyHint = new TextBlock
        {
            FontSize = 11,
            Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
            TextTrimming = Microsoft.UI.Xaml.TextTrimming.CharacterEllipsis,
            Visibility = Microsoft.UI.Xaml.Visibility.Collapsed,
        };
        _replyHint = replyHint;

        var sendButton = new Button
        {
            Content = "Send",
            Style = (Style)Application.Current.Resources["AccentButtonStyle"],
        };
        sendButton.Click += async (_, _) =>
        {
            var text = input.Text?.Trim();
            if (string.IsNullOrEmpty(text)) return;
            try
            {
                await _feed.CreateCommentAsync(post.Id, text, _replyTo?.Id);
                input.Text = "";
                _replyTo = null;
                replyHint.Visibility = Microsoft.UI.Xaml.Visibility.Collapsed;
                await ReloadCommentsAsync(post.Id, comments);
            }
            catch (Exception ex)
            {
                Logger.Warn("FeedPage.Comment.Send", ex.Message);
            }
        };

        var body = new StackPanel
        {
            Spacing = 8,
            Children =
            {
                replyHint,
                list,
                new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 8,
                    Children = { input, sendButton },
                },
            },
        };

        await ReloadCommentsAsync(post.Id, comments);

        var dialog = new ContentDialog
        {
            Title = $"Comments on {post.Username}'s post",
            Content = body,
            PrimaryButtonText = "Close",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        dialog.Closed += (_, _) =>
        {
            _activeComments = null;
            _commentInput = null;
            _replyHint = null;
        };
        _ = dialog.ShowAsync();
    }

    private static async Task ReloadCommentsAsync(string postId, ObservableCollection<Comment> comments)
    {
        comments.Clear();
        var loaded = await new FeedService().GetPostCommentsAsync(postId);
        foreach (var c in loaded) comments.Add(c);
    }

    private async void CommentLikeButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Comment c) return;
        try
        {
            if (c.IsLiked)
            {
                await _feed.UnlikeCommentAsync(c.Id);
                c.IsLiked = false;
                if (c.LikesCount > 0) c.LikesCount--;
            }
            else
            {
                await _feed.LikeCommentAsync(c.Id);
                c.IsLiked = true;
                c.LikesCount++;
            }
            if (_activeComments != null)
            {
                var i = _activeComments.IndexOf(c);
                if (i >= 0) _activeComments[i] = c;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("FeedPage.Comment.Like", ex.Message);
        }
    }

    private void CommentReplyButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Comment c) return;
        if (_activeComments == null || _commentInput == null || _replyHint == null) return;
        _replyTo = c;
        _replyHint.Text = $"Replying to {c.UserName}";
        _replyHint.Visibility = Microsoft.UI.Xaml.Visibility.Visible;
        _commentInput.Focus(FocusState.Programmatic);
    }
}
