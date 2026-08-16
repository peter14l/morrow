using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class SpacesPage : Page
{
    private readonly SpacesService _spaces = new();
    private readonly ObservableCollection<Community> _communities = new();

    public SpacesPage()
    {
        InitializeComponent();
        CommunitiesList.ItemsSource = _communities;
        Loaded += async (_, _) => await LoadCommunitiesAsync();
    }

    private async Task LoadCommunitiesAsync()
    {
        try
        {
            _communities.Clear();
            var loaded = await _spaces.GetCommunitiesAsync(50, 0);
            foreach (var c in loaded) _communities.Add(c);
        }
        catch (Exception ex)
        {
            Logger.Warn("SpacesPage.Load", ex.Message);
        }
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
        => await LoadCommunitiesAsync();

    private void CommunitiesList_ItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is Community c) Frame.Navigate(typeof(CommunityPage), c);
    }

    private async void JoinLeaveButton_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is not Community c) return;
        try
        {
            if (c.IsMember)
            {
                await _spaces.LeaveCommunityAsync(c.Id);
                c.IsMember = false;
                if (c.MembersCount > 0) c.MembersCount--;
            }
            else
            {
                await _spaces.JoinCommunityAsync(c.Id);
                c.IsMember = true;
                c.MembersCount++;
            }
            var i = _communities.IndexOf(c);
            if (i >= 0) _communities[i] = c;
        }
        catch (Exception ex)
        {
            Logger.Warn("SpacesPage.JoinLeave", ex.Message);
        }
    }

    private async void CreateCommunityButton_Click(object sender, RoutedEventArgs e)
    {
        var nameBox = new TextBox { PlaceholderText = "Community name" };
        var descBox = new TextBox { PlaceholderText = "Description (optional)" };
        var isPrivate = new CheckBox { Content = "Private community" };

        var body = new StackPanel
        {
            Spacing = 8,
            Children = { nameBox, descBox, isPrivate },
        };

        var dialog = new ContentDialog
        {
            Title = "Create community",
            Content = body,
            PrimaryButtonText = "Create",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };

        dialog.PrimaryButtonClick += async (d, args) =>
        {
            var name = nameBox.Text?.Trim();
            if (string.IsNullOrEmpty(name))
            {
                args.Cancel = true;
                nameBox.Header = "Name is required";
                return;
            }
            try
            {
                await _spaces.CreateCommunityAsync(name, descBox.Text?.Trim(), isPrivate.IsChecked == true);
                dialog.Hide();
                await LoadCommunitiesAsync();
            }
            catch (Exception ex)
            {
                args.Cancel = true;
                Logger.Warn("SpacesPage.Create", ex.Message);
                nameBox.Header = ex.Message;
            }
        };

        _ = dialog.ShowAsync();
    }
}
