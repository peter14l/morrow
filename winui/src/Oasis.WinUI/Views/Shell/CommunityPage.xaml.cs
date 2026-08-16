using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class CommunityPage : Page
{
    private readonly SpacesService _spaces = new();
    private readonly FeedService _feed = new();
    private readonly ObservableCollection<Post> _posts = new();
    private Community? _community;

    public CommunityPage()
    {
        InitializeComponent();
        PostsList.ItemsSource = _posts;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is not Community c) return;
        _community = c;
        CommunityTitle.Text = c.Name;
        CommunityMeta.Text = $"{c.MembersCount} members · {c.Description}";
        JoinLeaveButton.Content = c.IsMember ? "Leave" : "Join";
        await LoadPostsAsync();
    }

    private async Task LoadPostsAsync()
    {
        if (_community == null) return;
        try
        {
            _posts.Clear();
            var loaded = await _spaces.GetCommunityPostsAsync(_community.Id, 50);
            foreach (var p in loaded) _posts.Add(p);
        }
        catch (Exception ex)
        {
            Logger.Warn("CommunityPage.Load", ex.Message);
        }
    }

    private async void JoinLeaveButton_Click(object sender, RoutedEventArgs e)
    {
        if (_community == null) return;
        try
        {
            if (_community.IsMember)
            {
                await _spaces.LeaveCommunityAsync(_community.Id);
                _community.IsMember = false;
                if (_community.MembersCount > 0) _community.MembersCount--;
            }
            else
            {
                await _spaces.JoinCommunityAsync(_community.Id);
                _community.IsMember = true;
                _community.MembersCount++;
            }
            JoinLeaveButton.Content = _community.IsMember ? "Leave" : "Join";
            CommunityMeta.Text = $"{_community.MembersCount} members · {_community.Description}";
        }
        catch (Exception ex)
        {
            Logger.Warn("CommunityPage.JoinLeave", ex.Message);
        }
    }

    private async void PostButton_Click(object sender, RoutedEventArgs e)
    {
        if (_community == null) return;
        var content = ComposerBox.Text?.Trim();
        if (string.IsNullOrEmpty(content)) return;
        try
        {
            await _feed.CreatePostAsync(content, communityId: _community.Id);
            ComposerBox.Text = "";
            await LoadPostsAsync();
        }
        catch (Exception ex)
        {
            Logger.Warn("CommunityPage.Post", ex.Message);
        }
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
            var i = _posts.IndexOf(post);
            if (i >= 0) _posts[i] = post;
        }
        catch (Exception ex)
        {
            Logger.Warn("CommunityPage.Like", ex.Message);
        }
    }

    private async void CommentButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Post post) return;
        var comments = new ObservableCollection<Comment>();
        var list = new ListView
        {
            ItemsSource = comments,
            SelectionMode = ListViewSelectionMode.None,
            MaxHeight = 280,
        };

        var input = new TextBox { PlaceholderText = "Write a comment..." };
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
                await _feed.CreateCommentAsync(post.Id, text);
                input.Text = "";
                comments.Clear();
                foreach (var c in await _feed.GetPostCommentsAsync(post.Id)) comments.Add(c);
            }
            catch (Exception ex)
            {
                Logger.Warn("CommunityPage.Comment.Send", ex.Message);
            }
        };

        var body = new StackPanel
        {
            Spacing = 8,
            Children =
            {
                list,
                new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 8,
                    Children = { input, sendButton },
                },
            },
        };

        try
        {
            foreach (var c in await _feed.GetPostCommentsAsync(post.Id)) comments.Add(c);
        }
        catch (Exception ex)
        {
            Logger.Warn("CommunityPage.Comment.Load", ex.Message);
        }

        var dialog = new ContentDialog
        {
            Title = "Comments",
            Content = body,
            PrimaryButtonText = "Close",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        _ = dialog.ShowAsync();
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
            Logger.Warn("CommunityPage.Delete", ex.Message);
        }
    }
}
