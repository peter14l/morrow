using System.Runtime.InteropServices.WindowsRuntime;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Crypto;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Settings;

public sealed partial class SettingsPage : Page
{
    private readonly SettingsService _settings = new();
    private bool _loadingProfile;

    public SettingsPage()
    {
        InitializeComponent();

        VersionLabel.Text = $"Version {AppConfig.Version}";

        var pqReady = PqAuraLoader.IsLoaded;
        PqAuraLabel.Text = pqReady
            ? "PQ-Aura is active — your conversations are protected by lattice-based post-quantum cryptography on top of Signal Protocol."
            : "PQ-Aura is unavailable on this installation. Messages are still protected by Signal Protocol (AES-256 + Curve25519).";
        EncryptionEngineLabel.Text = pqReady
            ? "Signal + PQ-Aura (post-quantum)"
            : "Signal Protocol (AES-256 + Curve25519)";

        PqAuraInfoBar.Severity = pqReady ? InfoBarSeverity.Success : InfoBarSeverity.Warning;
        PqAuraInfoBar.Title = pqReady ? "PQ-Aura Active" : "PQ-Aura Unavailable";
        PqAuraInfoBar.Message = pqReady
            ? "Post-quantum protection enabled for all new sessions."
            : "Standard Signal encryption is still active and secure.";

        if (!pqReady)
            EncryptionStatusIcon.Foreground = new SolidColorBrush(Colors.Orange);

        Loaded += async (_, _) => await LoadProfileAsync();
    }

    // ── Tab selection ────────────────────────────────────────────────────────

    private void SettingsTabView_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var tab = (SettingsTabView.SelectedItem as TabViewItem)?.Tag?.ToString();
        if (tab == "wellness") LoadWellnessStats();
        else if (tab == "encryption") LoadEncryptionKey();
    }

    // ── Profile ───────────────────────────────────────────────────────────────

    private async Task LoadProfileAsync()
    {
        if (_loadingProfile) return;
        _loadingProfile = true;
        try
        {
            var user = AuthService.Current.CurrentUser;
            EmailLabel.Text = user?.Email ?? "";

            var profile = await _settings.GetProfileAsync();
            if (profile != null)
            {
                UsernameLabel.Text = profile.DisplayName;
                UsernameBox.Text = profile.Username;
                DisplayNameBox.Text = profile.FullName;
                BioBox.Text = profile.Bio;
                PrivateAccountToggle.IsOn = profile.IsPrivate;

                var avatar = !string.IsNullOrWhiteSpace(profile.AvatarUrl)
                    ? profile.AvatarUrl
                    : (user?.UserMetadata?.GetValueOrDefault("avatar_url") as string
                       ?? user?.UserMetadata?.GetValueOrDefault("picture") as string);

                if (!string.IsNullOrEmpty(avatar))
                {
                    try { AvatarView.ProfilePicture = new BitmapImage(new Uri(avatar)); }
                    catch { AvatarView.DisplayName = profile.DisplayName; }
                }
                else
                {
                    AvatarView.DisplayName = profile.DisplayName;
                }

                if (!string.IsNullOrEmpty(profile.PublicKey))
                    PublicKeyBox.Text = profile.PublicKey;
            }
            else if (user != null)
            {
                var metaName = user.UserMetadata?.GetValueOrDefault("full_name") as string
                               ?? user.UserMetadata?.GetValueOrDefault("username") as string;
                var metaUser = user.UserMetadata?.GetValueOrDefault("username") as string ?? "";
                UsernameLabel.Text = metaName ?? user.Email ?? "Oasis User";
                DisplayNameBox.Text = metaName ?? "";
                UsernameBox.Text = metaUser;

                var avatar = user.UserMetadata?.GetValueOrDefault("avatar_url") as string
                             ?? user.UserMetadata?.GetValueOrDefault("picture") as string;

                if (!string.IsNullOrEmpty(avatar))
                {
                    try { AvatarView.ProfilePicture = new BitmapImage(new Uri(avatar)); }
                    catch { AvatarView.DisplayName = UsernameLabel.Text; }
                }
                else
                {
                    AvatarView.DisplayName = UsernameLabel.Text;
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Load", ex.Message);
        }
        finally
        {
            _loadingProfile = false;
        }
    }

    // ── Wellness ──────────────────────────────────────────────────────────────

    private async void LoadWellnessStats()
    {
        try
        {
            var wellness = new WellnessService();
            var stats = await wellness.GetWellnessStatsAsync();

            var xp = stats.UnlockedAchievements.Count * 250 + stats.FocusMinutesThisWeek * 10;
            XpSummaryLabel.Text = $"{xp:N0} XP";

            var xpInLevel = xp % 1000;
            XpProgressBar.Value = xpInLevel;
            var level = xp / 1000 + 1;
            XpNextLevelLabel.Text = $"Level {level} — {1000 - xpInLevel} XP to next level";

            SessionsTodayLabel.Text = stats.RecentSessions.Count(s => s.CreatedAt?.Date == DateTime.UtcNow.Date).ToString();
            SessionsWeekLabel.Text = stats.RecentSessions.Count.ToString();
            SessionsTotalLabel.Text = stats.RecentSessions.Count.ToString();
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Wellness", ex.Message);
        }
    }

    private void ScreenTimeSlider_ValueChanged(object sender,
        Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
    {
        if (ScreenTimeLimitLabel == null) return;
        var minutes = (int)e.NewValue;
        ScreenTimeLimitLabel.Text = minutes >= 60
            ? $"{minutes / 60}h {minutes % 60}m"
            : $"{minutes}m";
    }

    // ── Encryption ───────────────────────────────────────────────────────────

    private void LoadEncryptionKey()
    {
        try
        {
            if (!string.IsNullOrEmpty(PublicKeyBox.Text) && PublicKeyBox.Text != "Loading…") return;
            PublicKeyBox.PlaceholderText = PqAuraLoader.IsLoaded
                ? "PQ-Aura key: available (stored securely)"
                : "Signal key: provisioned on first message send";
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.EncKey", ex.Message);
        }
    }

    // ── Avatar ────────────────────────────────────────────────────────────────

    private async void ChangeAvatarButton_Click(object sender, RoutedEventArgs e)
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
                AvatarView.ProfilePicture = new BitmapImage(new Uri(url));
            System.IO.File.Delete(temp);
            ShowStatus(ProfileStatus, "Avatar updated ✓", success: true);
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Avatar", ex.Message);
            ShowStatus(ProfileStatus, $"Failed: {ex.Message}", success: false);
        }
    }

    // ── Profile save ──────────────────────────────────────────────────────────

    private async void SaveProfileButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await _settings.UpdateProfileAsync(
                username: UsernameBox.Text.Trim(),
                displayName: DisplayNameBox.Text.Trim());

            var userId = AuthService.Current.CurrentUser?.Id ?? "";
            if (!string.IsNullOrEmpty(userId))
            {
                await SupabaseService.Client.From<Core.Models.ProfilesRow>()
                    .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                    .Update(new Core.Models.ProfilesRow
                    {
                        Bio = BioBox.Text.Trim(),
                        IsPrivate = PrivateAccountToggle.IsOn,
                    });
            }

            UsernameLabel.Text = UsernameBox.Text.Trim().Length > 0
                ? UsernameBox.Text.Trim() : UsernameLabel.Text;
            ShowStatus(ProfileStatus, "Changes saved ✓", success: true);
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.SaveProfile", ex.Message);
            ShowStatus(ProfileStatus, ex.Message, success: false);
        }
    }

    // ── Security ──────────────────────────────────────────────────────────────

    private async void UpdatePasswordButton_Click(object sender, RoutedEventArgs e)
    {
        var password = NewPasswordBox.Password;
        var confirm = ConfirmPasswordBox.Password;
        if (string.IsNullOrEmpty(password) || password.Length < 6)
        {
            ShowStatus(SecurityStatus, "Password must be at least 6 characters", success: false);
            return;
        }
        if (password != confirm)
        {
            ShowStatus(SecurityStatus, "Passwords do not match", success: false);
            return;
        }
        try
        {
            await _settings.UpdatePasswordAsync(password);
            NewPasswordBox.Password = "";
            ConfirmPasswordBox.Password = "";
            ShowStatus(SecurityStatus, "Password updated ✓", success: true);
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Password", ex.Message);
            ShowStatus(SecurityStatus, ex.Message, success: false);
        }
    }

    private async void SendResetButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            await _settings.SendPasswordResetAsync(AuthService.Current.CurrentUser?.Email ?? "");
            ShowStatus(SecurityStatus, "Reset link sent to your email ✓", success: true);
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Reset", ex.Message);
            ShowStatus(SecurityStatus, ex.Message, success: false);
        }
    }

    // ── Privacy ───────────────────────────────────────────────────────────────

    private async void PrivateAccountToggle_Toggled(object sender, RoutedEventArgs e)
    {
        var userId = AuthService.Current.CurrentUser?.Id ?? "";
        if (string.IsNullOrEmpty(userId)) return;
        try
        {
            await SupabaseService.Client.From<Core.Models.ProfilesRow>()
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Update(new Core.Models.ProfilesRow { IsPrivate = PrivateAccountToggle.IsOn });
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.Privacy", ex.Message);
        }
    }

    private async void RequestDataExport_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var userId = AuthService.Current.CurrentUser?.Id ?? "";
            if (string.IsNullOrEmpty(userId)) return;
            await SupabaseService.Client.Rpc("request_data_export",
                new Dictionary<string, object?> { ["p_user_id"] = userId });
            ShowStatus(DataExportStatus, "Export request submitted. You will receive an email when ready.", success: true);
        }
        catch (Exception ex)
        {
            ShowStatus(DataExportStatus, "Data export is handled via the mobile app.", success: false);
            Logger.Warn("SettingsPage.DataExport", ex.Message);
        }
    }

    // ── Delete account ────────────────────────────────────────────────────────

    private async void DeleteAccountButton_Click(object sender, RoutedEventArgs e)
    {
        var confirm = new ContentDialog
        {
            Title = "Delete account?",
            Content = "This permanently deletes your profile, posts, and all data. This cannot be undone.",
            PrimaryButtonText = "Delete permanently",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        if (await confirm.ShowAsync() != ContentDialogResult.Primary) return;
        try
        {
            await _settings.DeleteAccountAsync();
            App.MainWindowInstance?.NavigateToLogin();
        }
        catch (Exception ex)
        {
            Logger.Warn("SettingsPage.DeleteAccount", ex.Message);
            ShowStatus(ProfileStatus, ex.Message, success: false);
        }
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static void ShowStatus(TextBlock label, string message, bool success)
    {
        label.Text = message;
        label.Foreground = new SolidColorBrush(success
            ? Windows.UI.Color.FromArgb(255, 34, 197, 94)
            : Windows.UI.Color.FromArgb(255, 239, 68, 68));
    }
}
