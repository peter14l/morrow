using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;
using Oasis.WinUI.Views.Profile;
using Oasis.WinUI.Views.Settings;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class MainShellPage : Page
{
    private readonly SettingsService _settings = new();

    public MainShellPage()
    {
        InitializeComponent();

        var user = AuthService.Current.CurrentUser;
        if (user != null)
        {
            var name = user.UserMetadata?.GetValueOrDefault("username") as string
                       ?? user.UserMetadata?.GetValueOrDefault("full_name") as string
                       ?? user.Email;
            UserLabel.Text = name ?? "Signed in";
            NavAvatarPicture.DisplayName = name ?? "";
        }
        else
        {
            UserLabel.Text = "Signed in";
        }

        FeedItem.IsSelected = true;
        Loaded += async (_, _) => await LoadNavAvatarAsync();
    }

    // ── Avatar in nav footer ─────────────────────────────────────────────────

    private async Task LoadNavAvatarAsync()
    {
        try
        {
            var profile = await _settings.GetProfileAsync();
            if (profile == null) return;

            UserLabel.Text = profile.DisplayName;

            if (!string.IsNullOrEmpty(profile.AvatarUrl))
            {
                NavAvatarPicture.ProfilePicture =
                    new BitmapImage(new Uri(profile.AvatarUrl));
            }
            else
            {
                NavAvatarPicture.DisplayName = profile.DisplayName;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("MainShell.LoadAvatar", ex.Message);
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        NotificationService.Instance.Subscribe();
        ContentFrame.Navigate(typeof(FeedPage));
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);
        NotificationService.Instance.Unsubscribe();
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        Type? target = null;

        if (args.IsSettingsSelected)
        {
            target = typeof(SettingsPage);
        }
        else if (args.SelectedItemContainer is NavigationViewItem item)
        {
            target = item.Tag?.ToString() switch
            {
                "feed"          => typeof(FeedPage),
                "search"        => typeof(SearchPage),
                "messages"      => typeof(ConversationsPage),
                "spaces"        => typeof(SpacesPage),
                "wellness"      => typeof(WellnessPage),
                "notifications" => typeof(NotificationsPage),
                "profile"       => typeof(ProfilePage),
                _               => null,
            };
        }

        if (target != null && ContentFrame.CurrentSourcePageType != target)
            ContentFrame.Navigate(target);
    }

    private void NavView_BackRequested(NavigationView sender, NavigationViewBackRequestedEventArgs args)
    {
        if (ContentFrame.CanGoBack) ContentFrame.GoBack();
    }

    // ── Footer buttons ───────────────────────────────────────────────────────

    private void UserAvatarButton_Click(object sender, RoutedEventArgs e)
    {
        if (ContentFrame.CurrentSourcePageType != typeof(ProfilePage))
            ContentFrame.Navigate(typeof(ProfilePage));
    }

    private async void SignOutButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await AuthService.Current.SignOutAsync();
            App.MainWindowInstance?.NavigateToLogin();
        }
        catch (Exception ex)
        {
            Logger.Warn("MainShellPage.SignOut", ex.Message);
        }
    }
}
