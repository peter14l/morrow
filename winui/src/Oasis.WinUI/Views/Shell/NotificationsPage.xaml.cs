using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class NotificationsPage : Page
{
    public NotificationsPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await LoadNotificationsAsync();
    }

    private async Task LoadNotificationsAsync()
    {
        LoadingBar.Visibility = Visibility.Visible;
        EmptyPanel.Visibility = Visibility.Collapsed;

        try
        {
            var notifications = await NotificationService.Instance.GetNotificationsAsync();
            if (notifications.Count == 0)
            {
                EmptyPanel.Visibility = Visibility.Visible;
            }
            else
            {
                NotificationsList.ItemsSource = notifications;
            }
        }
        catch
        {
            EmptyPanel.Visibility = Visibility.Visible;
        }
        finally
        {
            LoadingBar.Visibility = Visibility.Collapsed;
        }
    }

    private async void NotificationsList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is NotificationsRow item && item.Id != null)
        {
            await NotificationService.Instance.MarkAsReadAsync(item.Id);
        }
    }
}
