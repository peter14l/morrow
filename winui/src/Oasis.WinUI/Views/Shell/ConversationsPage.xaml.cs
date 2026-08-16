using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class ConversationsPage : Page
{
    private readonly MessagingService _messaging = new();
    private readonly ObservableCollection<Conversation> _conversations = new();
    private string _myUserId = "";

    public ConversationsPage()
    {
        InitializeComponent();
        ConversationsList.ItemsSource = _conversations;
        Loaded += async (_, _) =>
        {
            NotificationService.Instance.DmReceived += OnDmReceived;
            _myUserId = SupabaseService.Client.Auth.CurrentUser?.Id ?? "";
            await KeyRestorePrompt.EnsureRestoredAsync(XamlRoot, _messaging);
            await LoadConversationsAsync();
        };
        Unloaded += (_, _) =>
        {
            NotificationService.Instance.DmReceived -= OnDmReceived;
        };
    }

    private async void OnDmReceived(object? sender, string conversationId)
        => await LoadConversationsAsync();

    private async Task LoadConversationsAsync()
    {
        try
        {
            _conversations.Clear();
            var loaded = await _messaging.GetConversationsAsync();
            foreach (var c in loaded)
            {
                _conversations.Add(c);
                _ = DecoratePreviewAsync(c);
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ConversationsPage.Load", ex.Message);
        }
    }

    private async Task DecoratePreviewAsync(Conversation c)
    {
        c.LastMessagePreview = await _messaging.DecryptConversationPreviewAsync(c, _myUserId);

        var i = _conversations.IndexOf(c);
        if (i >= 0) _conversations[i] = c;
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
        => await LoadConversationsAsync();

    private void ConversationsList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not Conversation c) return;
        if (c.Id.Length == 0) return;
        _ = _messaging.MarkConversationReadAsync(c.Id);
        c.UnreadCount = 0;
        var i = _conversations.IndexOf(c);
        if (i >= 0) _conversations[i] = c;
        OpenChat(c.Id, c.DisplayName, c.OtherUserAvatar);
    }

    private void OpenChat(string conversationId, string title, string avatarUrl)
    {
        EmptyStateText.Visibility = Visibility.Collapsed;
        DetailFrame.Navigate(typeof(ChatPage), new ChatContext(conversationId, title, avatarUrl));
    }

    private async void NewConversationButton_Click(object sender, RoutedEventArgs e)
    {
        var input = new TextBox { PlaceholderText = "Enter a username..." };
        var dialog = new ContentDialog
        {
            Title = "New conversation",
            Content = input,
            PrimaryButtonText = "Start",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };

        dialog.PrimaryButtonClick += async (d, args) =>
        {
            var username = input.Text?.Trim();
            if (string.IsNullOrEmpty(username)) return;
            var user = await _messaging.FindUserByUsernameAsync(username);
            if (user == null || user.Value.Id.Length == 0)
            {
                args.Cancel = true;
                input.Header = "User not found";
                return;
            }
            var conversationId = await _messaging.GetOrCreateDirectConversationAsync(user.Value.Id);
            args.Cancel = true;
            dialog.Hide();
            if (!string.IsNullOrEmpty(conversationId))
                OpenChat(conversationId, user.Value.Username, user.Value.AvatarUrl);
        };

        _ = dialog.ShowAsync();
    }
}
