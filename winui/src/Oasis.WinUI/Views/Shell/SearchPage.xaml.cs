using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class SearchPage : Page
{
    private readonly SearchService _searchService = new();
    private CancellationTokenSource? _cts;

    public SearchPage()
    {
        InitializeComponent();
    }

    private void SearchBox_TextChanged(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason == AutoSuggestionBoxTextChangeReason.UserInput)
        {
            _cts?.Cancel();
            _cts = new CancellationTokenSource();
            var token = _cts.Token;

            _ = Task.Run(async () =>
            {
                try
                {
                    await Task.Delay(350, token);
                    if (token.IsCancellationRequested) return;

                    DispatcherQueue.TryEnqueue(() =>
                    {
                        if (!token.IsCancellationRequested)
                        {
                            _ = ExecuteSearchAsync(sender.Text);
                        }
                    });
                }
                catch (TaskCanceledException) { }
            }, token);
        }
    }

    private void SearchBox_QuerySubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        _ = ExecuteSearchAsync(args.QueryText);
    }

    private void SearchPivot_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateTabVisibility();
    }

    private void UpdateTabVisibility()
    {
        var index = SearchPivot.SelectedIndex;
        UsersList.Visibility = index == 0 ? Visibility.Visible : Visibility.Collapsed;
        PostsList.Visibility = index == 1 ? Visibility.Visible : Visibility.Collapsed;
        CirclesList.Visibility = index == 2 ? Visibility.Visible : Visibility.Collapsed;
    }

    private async Task ExecuteSearchAsync(string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            UsersList.ItemsSource = null;
            PostsList.ItemsSource = null;
            CirclesList.ItemsSource = null;
            EmptyPanel.Visibility = Visibility.Visible;
            EmptyLabel.Text = "Search for people, posts or circles";
            return;
        }

        LoadingBar.Visibility = Visibility.Visible;
        EmptyPanel.Visibility = Visibility.Collapsed;

        try
        {
            var usersTask = _searchService.SearchUsersAsync(query);
            var postsTask = _searchService.SearchPostsAsync(query);
            var circlesTask = _searchService.SearchCirclesAsync(query);

            await Task.WhenAll(usersTask, postsTask, circlesTask);

            var users = await usersTask;
            var posts = await postsTask;
            var circles = await circlesTask;

            UsersList.ItemsSource = users;
            PostsList.ItemsSource = posts;
            CirclesList.ItemsSource = circles;

            var totalResults = users.Count + posts.Count + circles.Count;
            if (totalResults == 0)
            {
                EmptyPanel.Visibility = Visibility.Visible;
                EmptyLabel.Text = $"No results found for \"{query}\"";
            }
        }
        catch (Exception ex)
        {
            EmptyPanel.Visibility = Visibility.Visible;
            EmptyLabel.Text = $"Error: {ex.Message}";
        }
        finally
        {
            LoadingBar.Visibility = Visibility.Collapsed;
        }
    }
}
