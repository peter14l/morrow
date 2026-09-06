using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;
using System.Runtime.InteropServices.WindowsRuntime;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class ChatDetailsPage : Page
{
    private readonly MessagingService _messaging = new();
    private ChatContext? _context;
    private string _otherUserId = "";
    private bool _isBlocked;
    private bool _isUpdating;

    public ChatDetailsPage()
    {
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is not ChatContext ctx) return;

        _context = ctx;
        DisplayNameText.Text = ctx.Title;
        UsernameText.Text = $"@{ctx.Title.ToLowerInvariant().Replace(" ", "_")}";

        if (!string.IsNullOrEmpty(ctx.AvatarUrl))
        {
            UserAvatar.ProfilePicture = new BitmapImage(new Uri(ctx.AvatarUrl));
        }
        else
        {
            UserAvatar.DisplayName = ctx.Title;
        }

        _otherUserId = await _messaging.GetOtherParticipantAsync(ctx.ConversationId) ?? "";

        await LoadSettingsAsync();
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (Frame.CanGoBack)
        {
            Frame.GoBack();
        }
    }

    private async Task LoadSettingsAsync()
    {
        if (_context == null) return;
        _isUpdating = true;
        try
        {
            // Background Wallpaper
            var bgUrl = await _messaging.GetChatBackgroundAsync(_context.ConversationId);
            if (!string.IsNullOrEmpty(bgUrl))
            {
                WallpaperPreviewImage.Source = new BitmapImage(new Uri(bgUrl));
                WallpaperPreviewPanel.Visibility = Visibility.Visible;
            }
            else
            {
                WallpaperPreviewImage.Source = null;
                WallpaperPreviewPanel.Visibility = Visibility.Collapsed;
            }

            // Mute Status
            var isMuted = await _messaging.GetMuteStatusAsync(_context.ConversationId);
            MuteToggle.IsOn = isMuted;

            // Block Status
            if (!string.IsNullOrEmpty(_otherUserId))
            {
                _isBlocked = await _messaging.IsUserBlockedAsync(_otherUserId);
                UpdateBlockUi();
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatDetails.LoadSettings", ex.Message);
        }
        finally
        {
            _isUpdating = false;
        }
    }

    private void UpdateBlockUi()
    {
        if (_isBlocked)
        {
            BlockText.Text = $"Unblock {_context?.Title ?? "User"}";
            BlockSubtext.Text = "Allow this user to message and call you";
            BlockIcon.Glyph = "\uE8D8";
        }
        else
        {
            BlockText.Text = $"Block {_context?.Title ?? "User"}";
            BlockSubtext.Text = "Prevent this user from messaging or calling you";
            BlockIcon.Glyph = "\uE8D8";
        }
    }

    private async void ChangeWallpaperButton_Click(object sender, RoutedEventArgs e)
    {
        if (_context == null) return;

        var picker = new Windows.Storage.Pickers.FileOpenPicker
        {
            ViewMode = Windows.Storage.Pickers.PickerViewMode.Thumbnail,
            SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.PicturesLibrary,
        };
        picker.FileTypeFilter.Add(".jpg");
        picker.FileTypeFilter.Add(".jpeg");
        picker.FileTypeFilter.Add(".png");
        picker.FileTypeFilter.Add(".webp");

        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindowInstance);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

        var file = await picker.PickSingleFileAsync();
        if (file == null) return;

        try
        {
            var buffer = await Windows.Storage.FileIO.ReadBufferAsync(file);
            var bytes = buffer.ToArray();
            var fileName = $"bg_{Guid.NewGuid():N}{file.FileType}";
            var storage = SupabaseService.Client.Storage.From("chat-backgrounds");
            var path = $"backgrounds/{_context.ConversationId}/{fileName}";
            await storage.Upload(bytes, path);
            var publicUrl = storage.GetPublicUrl(path);

            if (!string.IsNullOrEmpty(publicUrl))
            {
                await _messaging.UpdateChatBackgroundAsync(_context.ConversationId, publicUrl);
                WallpaperPreviewImage.Source = new BitmapImage(new Uri(publicUrl));
                WallpaperPreviewPanel.Visibility = Visibility.Visible;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatDetails.ChangeWallpaper", ex.Message);
        }
    }

    private async void RemoveWallpaperButton_Click(object sender, RoutedEventArgs e)
    {
        if (_context == null) return;
        try
        {
            await _messaging.RemoveChatBackgroundAsync(_context.ConversationId);
            WallpaperPreviewImage.Source = null;
            WallpaperPreviewPanel.Visibility = Visibility.Collapsed;
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatDetails.RemoveWallpaper", ex.Message);
        }
    }

    private async void MuteToggle_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isUpdating || _context == null) return;
        var muted = MuteToggle.IsOn;
        await _messaging.ToggleMuteAsync(_context.ConversationId, muted);
    }

    private async void ClearChatButton_Click(object sender, RoutedEventArgs e)
    {
        if (_context == null) return;

        var dialog = new ContentDialog
        {
            Title = "Clear chat history?",
            Content = "All messages in this conversation will be permanently removed.",
            PrimaryButtonText = "Clear for everyone",
            SecondaryButtonText = "Clear for me",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };

        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.Primary)
        {
            await _messaging.ClearConversationMessagesAsync(_context.ConversationId);
            if (Frame.CanGoBack) Frame.GoBack();
        }
        else if (result == ContentDialogResult.Secondary)
        {
            await _messaging.ClearChatForMeAsync(_context.ConversationId);
            if (Frame.CanGoBack) Frame.GoBack();
        }
    }

    private async void BlockUserButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrEmpty(_otherUserId) || _context == null) return;

        if (_isBlocked)
        {
            var success = await _messaging.UnblockUserAsync(_otherUserId);
            if (success)
            {
                _isBlocked = false;
                UpdateBlockUi();
            }
        }
        else
        {
            var dialog = new ContentDialog
            {
                Title = $"Block {_context.Title}?",
                Content = "They will no longer be able to message you or call you on Oasis.",
                PrimaryButtonText = "Block",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Close,
                XamlRoot = XamlRoot,
            };

            var result = await dialog.ShowAsync();
            if (result == ContentDialogResult.Primary)
            {
                var success = await _messaging.BlockUserAsync(_otherUserId);
                if (success)
                {
                    _isBlocked = true;
                    UpdateBlockUi();
                }
            }
        }
    }
}
