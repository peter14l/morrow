using System.Text.Json;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;
using Oasis.WinUI.Views.Settings;
using System.Runtime.InteropServices.WindowsRuntime;
using Oasis.WinUI.Core.Crypto;
using UserProfile = Oasis.WinUI.Core.Models.Profile;

namespace Oasis.WinUI.Views.Profile;

/// <summary>
/// Full profile page — two-column layout: left identity sidebar + right posts/saved grid.
/// </summary>
public sealed partial class ProfilePage : Page
{
    private readonly SettingsService _settings = new();
    private readonly CollectionService _collections = new();
    private UserProfile? _profile;
    private readonly List<PostSummary> _posts = [];
    private readonly List<PostSummary> _savedPosts = [];

    public ProfilePage()
    {
        InitializeComponent();

        PqAuraStatusLabel.Text = PqAuraLoader.IsLoaded
            ? "PQ-Aura post-quantum layer — active"
            : "Standard Signal encryption — PQ-Aura unavailable";

        if (!PqAuraLoader.IsLoaded)
        {
            EncryptionIcon.Foreground =
                new Microsoft.UI.Xaml.Media.SolidColorBrush(Microsoft.UI.Colors.Orange);
        }

        ProfileTabView.SelectionChanged += ProfileTabView_SelectionChanged;
        Loaded += async (_, _) => await LoadAllAsync();
    }

    // ── Data loading ─────────────────────────────────────────────────────────

    private async Task LoadAllAsync()
    {
        LoadingRing.IsActive = true;
        LoadingRing.Visibility = Visibility.Visible;
        PostsList.Visibility = Visibility.Collapsed;
        EmptyState.Visibility = Visibility.Collapsed;

        try
        {
            var user = AuthService.Current.CurrentUser;
            var userId = user?.Id ?? "";
            EmailLabel.Text = user?.Email ?? "";

            _profile = await _settings.GetProfileAsync();
            if (_profile != null)
            {
                ApplyProfileToUi(_profile);
                userId = _profile.Id;
            }
            else if (user != null)
            {
                // Fallback display from user metadata
                var metaName = user.UserMetadata?.GetValueOrDefault("full_name") as string
                               ?? user.UserMetadata?.GetValueOrDefault("username") as string;
                DisplayNameLabel.Text = metaName ?? user.Email ?? "Oasis User";
                UsernameLabel.Text = user.UserMetadata?.GetValueOrDefault("username") is string un ? $"@{un}" : "";

                var avatarUrl = user.UserMetadata?.GetValueOrDefault("avatar_url") as string
                                ?? user.UserMetadata?.GetValueOrDefault("picture") as string;

                if (!string.IsNullOrEmpty(avatarUrl))
                {
                    try { AvatarPicture.ProfilePicture = new BitmapImage(new Uri(avatarUrl)); }
                    catch { AvatarPicture.DisplayName = DisplayNameLabel.Text; }
                }
                else
                {
                    AvatarPicture.DisplayName = DisplayNameLabel.Text;
                }
            }

            if (!string.IsNullOrEmpty(userId))
            {
                await LoadStatsAsync(userId);
                await LoadPostsAsync(userId);
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ProfilePage.Load", ex.Message);
        }
        finally
        {
            LoadingRing.IsActive = false;
            LoadingRing.Visibility = Visibility.Collapsed;
        }
    }

    private void ApplyProfileToUi(UserProfile profile)
    {
        DisplayNameLabel.Text = !string.IsNullOrWhiteSpace(profile.FullName)
            ? profile.FullName : (!string.IsNullOrWhiteSpace(profile.Username) ? profile.Username : "Oasis User");
        UsernameLabel.Text = string.IsNullOrWhiteSpace(profile.Username)
            ? "" : $"@{profile.Username.TrimStart('@')}";

        VerifiedBadge.Visibility = profile.IsVerified ? Visibility.Visible : Visibility.Collapsed;
        ProBadge.Visibility = profile.IsPro ? Visibility.Visible : Visibility.Collapsed;

        if (!string.IsNullOrWhiteSpace(profile.Bio))
        {
            BioLabel.Text = profile.Bio;
            BioLabel.Visibility = Visibility.Visible;
        }
        else
        {
            BioLabel.Visibility = Visibility.Collapsed;
        }

        if (profile.CreatedAt.HasValue)
            MemberSinceLabel.Text = $"Member since {profile.CreatedAt.Value:MMMM yyyy}";

        var avatar = !string.IsNullOrWhiteSpace(profile.AvatarUrl)
            ? profile.AvatarUrl
            : (AuthService.Current.CurrentUser?.UserMetadata?.GetValueOrDefault("avatar_url") as string
               ?? AuthService.Current.CurrentUser?.UserMetadata?.GetValueOrDefault("picture") as string);

        if (!string.IsNullOrEmpty(avatar))
        {
            try { AvatarPicture.ProfilePicture = new BitmapImage(new Uri(avatar)); }
            catch { AvatarPicture.DisplayName = profile.DisplayName; }
        }
        else
        {
            AvatarPicture.DisplayName = profile.DisplayName;
        }

        if (profile.FollowersCount > 0) FollowersCountLabel.Text = profile.FollowersCount.ToString();
        if (profile.FollowingCount > 0) FollowingCountLabel.Text = profile.FollowingCount.ToString();
        if (profile.PostsCount > 0) PostsCountLabel.Text = profile.PostsCount.ToString();
        if (profile.Xp > 0) XpLabel.Text = profile.Xp.ToString();
    }

    private async Task LoadStatsAsync(string userId)
    {
        if (string.IsNullOrEmpty(userId)) return;
        try
        {
            try
            {
                var followersCount = await SupabaseService.Client.From<FollowsRow>()
                    .Select("id")
                    .Filter("following_id", Postgrest.Constants.Operator.Equals, userId)
                    .Count(Postgrest.Constants.CountType.Exact);
                FollowersCountLabel.Text = followersCount.ToString();
            }
            catch
            {
                if (_profile != null && _profile.FollowersCount >= 0)
                    FollowersCountLabel.Text = _profile.FollowersCount.ToString();
            }

            try
            {
                var followingCount = await SupabaseService.Client.From<FollowsRow>()
                    .Select("id")
                    .Filter("follower_id", Postgrest.Constants.Operator.Equals, userId)
                    .Count(Postgrest.Constants.CountType.Exact);
                FollowingCountLabel.Text = followingCount.ToString();
            }
            catch
            {
                if (_profile != null && _profile.FollowingCount >= 0)
                    FollowingCountLabel.Text = _profile.FollowingCount.ToString();
            }

            var xp = _profile?.Xp ?? 0;
            if (xp == 0)
            {
                var metaXp = AuthService.Current.CurrentUser?.UserMetadata?.GetValueOrDefault("xp");
                if (metaXp != null && long.TryParse(metaXp.ToString(), out var parsedXp)) xp = parsedXp;
            }
            XpLabel.Text = xp.ToString();
        }
        catch (Exception ex)
        {
            Logger.Warn("ProfilePage.Stats", ex.Message);
        }
    }

    private async Task LoadPostsAsync(string userId)
    {
        if (string.IsNullOrEmpty(userId)) return;
        try
        {
            var resp = await SupabaseService.Client.From<PostsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(60)
                .Get();

            _posts.Clear();
            if (!string.IsNullOrWhiteSpace(resp?.Content) && resp.Content != "[]")
            {
                var parsedPosts = Post.FromJsonArray(resp.Content);
                foreach (var p in parsedPosts)
                {
                    _posts.Add(new PostSummary
                    {
                        Id = p.Id,
                        Content = p.Content,
                        ImageUrl = p.MediaUrls.FirstOrDefault() ?? p.ImageUrl ?? "",
                    });
                }
            }

            PostsCountLabel.Text = _posts.Count.ToString();

            if (_posts.Count == 0)
            {
                EmptyStateLabel.Text = "No posts yet";
                EmptyState.Visibility = Visibility.Visible;
                PostsList.Visibility = Visibility.Collapsed;
            }
            else
            {
                PostsList.ItemsSource = _posts;
                PostsList.Visibility = Visibility.Visible;
                EmptyState.Visibility = Visibility.Collapsed;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ProfilePage.Posts", ex.Message);
            EmptyStateLabel.Text = "Could not load posts";
            EmptyState.Visibility = Visibility.Visible;
        }
    }

    private async void ProfileTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ProfileTabView.SelectedItem is TabViewItem selectedItem && (string)selectedItem.Tag == "saved")
        {
            await LoadSavedPostsAsync();
        }
    }

    private async Task LoadSavedPostsAsync()
    {
        SavedLoadingRing.IsActive = true;
        SavedLoadingRing.Visibility = Visibility.Visible;
        SavedPostsList.Visibility = Visibility.Collapsed;
        SavedEmptyState.Visibility = Visibility.Collapsed;

        try
        {
            var collections = await _collections.GetUserCollectionsAsync();
            _savedPosts.Clear();

            foreach (var col in collections)
            {
                if (string.IsNullOrEmpty(col.Id)) continue;
                var posts = await _collections.GetCollectionPostsAsync(col.Id);
                foreach (var p in posts)
                {
                    if (!_savedPosts.Any(sp => sp.Id == p.Id))
                    {
                        _savedPosts.Add(new PostSummary
                        {
                            Id = p.Id,
                            Content = p.Content,
                            ImageUrl = p.MediaUrls.FirstOrDefault() ?? p.ImageUrl ?? "",
                        });
                    }
                }
            }

            if (_savedPosts.Count == 0)
            {
                SavedEmptyState.Visibility = Visibility.Visible;
                SavedPostsList.Visibility = Visibility.Collapsed;
            }
            else
            {
                SavedPostsList.ItemsSource = _savedPosts;
                SavedPostsList.Visibility = Visibility.Visible;
                SavedEmptyState.Visibility = Visibility.Collapsed;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ProfilePage.SavedPosts", ex.Message);
            SavedEmptyState.Visibility = Visibility.Visible;
        }
        finally
        {
            SavedLoadingRing.IsActive = false;
            SavedLoadingRing.Visibility = Visibility.Collapsed;
        }
    }


    // ── Avatar picker ─────────────────────────────────────────────────────────

    private async void ChangeAvatarBtn_Click(object sender, RoutedEventArgs e)
    {
        var picker = new Windows.Storage.Pickers.FileOpenPicker
        {
            ViewMode = Windows.Storage.Pickers.PickerViewMode.Thumbnail,
            SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.PicturesLibrary,
        };
        picker.FileTypeFilter.Add(".png");
        picker.FileTypeFilter.Add(".jpg");
        picker.FileTypeFilter.Add(".jpeg");
        picker.FileTypeFilter.Add(".webp");

        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindowInstance);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

        var file = await picker.PickSingleFileAsync();
        if (file == null) return;

        try
        {
            var buffer = await Windows.Storage.FileIO.ReadBufferAsync(file);
            var bytes = buffer.ToArray();
            var temp = System.IO.Path.Combine(System.IO.Path.GetTempPath(),
                $"oasis_avatar_{Guid.NewGuid():N}{file.FileType}");
            await System.IO.File.WriteAllBytesAsync(temp, bytes);
            var url = await _settings.UploadProfilePictureAsync(temp);
            if (!string.IsNullOrEmpty(url))
                AvatarPicture.ProfilePicture = new BitmapImage(new Uri(url));
            System.IO.File.Delete(temp);
        }
        catch (Exception ex)
        {
            Logger.Warn("ProfilePage.Avatar", ex.Message);
        }
    }

    // ── Edit profile dialog (built programmatically) ──────────────────────────

    private async void EditProfileBtn_Click(object sender, RoutedEventArgs e)
    {
        // Build fields
        var usernameBox = new TextBox
        {
            Header = "Username",
            PlaceholderText = "@username",
            Text = _profile?.Username ?? "",
        };
        var displayNameBox = new TextBox
        {
            Header = "Display name",
            PlaceholderText = "Your name",
            Text = _profile?.FullName ?? "",
        };
        var bioBox = new TextBox
        {
            Header = "Bio",
            PlaceholderText = "Tell people about yourself…",
            Text = _profile?.Bio ?? "",
            AcceptsReturn = true,
            MaxLength = 160,
            TextWrapping = TextWrapping.Wrap,
            Height = 80,
        };
        var privateToggle = new ToggleSwitch
        {
            Header = "Private account",
            IsOn = _profile?.IsPrivate ?? false,
            OnContent = "On",
            OffContent = "Off",
        };
        var statusLabel = new TextBlock { FontSize = 12 };

        var panel = new StackPanel { Spacing = 12, MinWidth = 340 };
        panel.Children.Add(usernameBox);
        panel.Children.Add(displayNameBox);
        panel.Children.Add(bioBox);
        panel.Children.Add(privateToggle);
        panel.Children.Add(statusLabel);

        var dialog = new ContentDialog
        {
            Title = "Edit Profile",
            Content = panel,
            PrimaryButtonText = "Save",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };

        dialog.PrimaryButtonClick += async (d, args) =>
        {
            args.Cancel = true;
            statusLabel.Text = "Saving…";
            try
            {
                await _settings.UpdateProfileAsync(
                    username: usernameBox.Text.Trim(),
                    displayName: displayNameBox.Text.Trim());

                var userId = AuthService.Current.CurrentUser?.Id ?? "";
                if (!string.IsNullOrEmpty(userId))
                {
                    await SupabaseService.Client.From<ProfilesRow>()
                        .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                        .Update(new ProfilesRow
                        {
                            Bio = bioBox.Text.Trim(),
                            IsPrivate = privateToggle.IsOn,
                        });
                }

                statusLabel.Text = "Saved ✓";
                await Task.Delay(500);
                d.Hide();
                await LoadAllAsync();
            }
            catch (Exception ex)
            {
                statusLabel.Text = ex.Message;
            }
        };

        await dialog.ShowAsync();
    }

    // ── Settings shortcut ────────────────────────────────────────────────────

    private void OpenSettingsBtn_Click(object sender, RoutedEventArgs e)
    {
        if (Frame != null) Frame.Navigate(typeof(SettingsPage));
    }
}

// ── Supporting models ────────────────────────────────────────────────────────

internal sealed class PostSummary
{
    public string Id { get; set; } = "";
    public string Content { get; set; } = "";
    public string ImageUrl { get; set; } = "";
}

[Postgrest.Attributes.Table("follows")]
internal sealed class FollowsRow : Postgrest.Models.BaseModel
{
    [Postgrest.Attributes.Column("id")] public string? Id { get; set; }
    [Postgrest.Attributes.Column("follower_id")] public string? FollowerId { get; set; }
    [Postgrest.Attributes.Column("following_id")] public string? FollowingId { get; set; }
}
