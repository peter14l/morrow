using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;

namespace Oasis.WinUI.Views.Shell;

public static class GifPickerDialog
{
    public static async Task<string?> ShowAsync(XamlRoot root)
    {
        var searchBox = new TextBox
        {
            PlaceholderText = "Search GIFs...",
            HorizontalAlignment = HorizontalAlignment.Stretch,
            Margin = new Thickness(0, 0, 0, 8),
        };

        var gridView = new GridView
        {
            Height = 350,
            Width = 450,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            SelectionMode = ListViewSelectionMode.Single,
        };

        var xaml = @"
            <DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
                <Image Source='{Binding}' Width='130' Height='130' Stretch='UniformToFill' Margin='4'/>
            </DataTemplate>";
        gridView.ItemTemplate = (DataTemplate)Microsoft.UI.Xaml.Markup.XamlReader.Load(xaml);

        var progressRing = new ProgressRing
        {
            IsActive = true,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(16),
            Visibility = Visibility.Collapsed,
        };

        var statusText = new TextBlock
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(8),
            Visibility = Visibility.Collapsed,
        };

        var container = new Grid();
        container.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        container.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var topPanel = new Grid();
        topPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        topPanel.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        searchBox.VerticalAlignment = VerticalAlignment.Center;
        searchBox.Margin = new Thickness(0, 0, 8, 8);
        Grid.SetColumn(searchBox, 0);
        topPanel.Children.Add(searchBox);

        var searchButton = new Button
        {
            Content = "Search",
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 8),
        };
        Grid.SetColumn(searchButton, 1);
        topPanel.Children.Add(searchButton);

        container.Children.Add(topPanel);
        Grid.SetRow(topPanel, 0);

        var resultsGrid = new Grid();
        resultsGrid.Children.Add(gridView);
        resultsGrid.Children.Add(progressRing);
        resultsGrid.Children.Add(statusText);

        container.Children.Add(resultsGrid);
        Grid.SetRow(resultsGrid, 1);

        var dialog = new ContentDialog
        {
            Title = "Find a GIF",
            Content = container,
            PrimaryButtonText = "Send",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = root,
            IsPrimaryButtonEnabled = false,
        };

        string? selectedUrl = null;

        gridView.SelectionChanged += (s, e) =>
        {
            if (gridView.SelectedItem is string url)
            {
                selectedUrl = url;
                dialog.IsPrimaryButtonEnabled = true;
            }
            else
            {
                dialog.IsPrimaryButtonEnabled = false;
            }
        };

        async Task LoadGifs(string query)
        {
            progressRing.Visibility = Visibility.Visible;
            gridView.Visibility = Visibility.Collapsed;
            statusText.Visibility = Visibility.Collapsed;
            dialog.IsPrimaryButtonEnabled = false;

            var gifs = await FetchGifsAsync(query);

            progressRing.Visibility = Visibility.Collapsed;
            if (gifs.Count > 0)
            {
                gridView.ItemsSource = gifs;
                gridView.Visibility = Visibility.Visible;
            }
            else
            {
                statusText.Text = "No GIFs found.";
                statusText.Visibility = Visibility.Visible;
            }
        }

        searchBox.KeyDown += async (s, e) =>
        {
            if (e.Key == Windows.System.VirtualKey.Enter)
            {
                e.Handled = true;
                await LoadGifs(searchBox.Text);
            }
        };

        searchButton.Click += async (s, e) =>
        {
            await LoadGifs(searchBox.Text);
        };

        // Initial load
        _ = LoadGifs("");

        var result = await dialog.ShowAsync();
        return result == ContentDialogResult.Primary ? selectedUrl : null;
    }

    private static async Task<List<string>> FetchGifsAsync(string query)
    {
        try
        {
            var klipyResults = await FetchKlipyGifsAsync(query);
            if (klipyResults.Count > 0) return klipyResults;
        }
        catch (Exception ex)
        {
            Oasis.WinUI.Services.Logger.Warn("Klipy.Fetch", ex.Message);
        }

        try
        {
            return await FetchGiphyGifsAsync(query);
        }
        catch (Exception ex)
        {
            Oasis.WinUI.Services.Logger.Warn("Giphy.Fetch", ex.Message);
        }

        return new List<string>();
    }

    private static async Task<List<string>> FetchKlipyGifsAsync(string query)
    {
        var list = new List<string>();
        var body = new Dictionary<string, object>
        {
            { "endpoint", string.IsNullOrEmpty(query) ? "trending" : "search" },
            { "limit", 12 },
            { "offset", 0 },
            { "platform", "windows" }
        };
        if (!string.IsNullOrEmpty(query))
        {
            body.Add("query", query);
        }

        var bodyJson = JsonSerializer.Serialize(body);
        using var client = new System.Net.Http.HttpClient();
        var token = Oasis.WinUI.Core.Networking.SupabaseService.Client.Auth.CurrentSession?.AccessToken 
                    ?? Oasis.WinUI.Core.Config.AppConfig.SupabaseAnonKey;
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        
        var response = await client.PostAsync(
            $"{Oasis.WinUI.Core.Config.AppConfig.SupabaseUrl}/functions/v1/klipy-proxy",
            new System.Net.Http.StringContent(bodyJson, System.Text.Encoding.UTF8, "application/json"));
        
        if (!response.IsSuccessStatusCode)
        {
            var errBody = await response.Content.ReadAsStringAsync();
            Oasis.WinUI.Services.Logger.Warn("Klipy.Fetch", $"Edge function returned status: {response.StatusCode}, body: {errBody}");
            return list;
        }
        
        var json = await response.Content.ReadAsStringAsync();
        if (string.IsNullOrEmpty(json)) return list;

        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.TryGetProperty("data", out var klipyOuter) && klipyOuter.ValueKind == JsonValueKind.Object &&
            klipyOuter.TryGetProperty("data", out var klipyData) && klipyData.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in klipyData.EnumerateArray())
            {
                if (item.TryGetProperty("file", out var file) &&
                    file.TryGetProperty("hd", out var hd) &&
                    hd.TryGetProperty("gif", out var gif) &&
                    gif.TryGetProperty("url", out var urlProp))
                {
                    var gifUrl = urlProp.GetString();
                    if (!string.IsNullOrEmpty(gifUrl))
                    {
                        list.Add(gifUrl);
                    }
                }
                else if (item.TryGetProperty("file", out var file2) &&
                         file2.TryGetProperty("sm", out var sm) &&
                         sm.TryGetProperty("gif", out var gif2) &&
                         gif2.TryGetProperty("url", out var urlProp2))
                {
                    var gifUrl = urlProp2.GetString();
                    if (!string.IsNullOrEmpty(gifUrl))
                    {
                        list.Add(gifUrl);
                    }
                }
            }
        }
        return list;
    }

    private static async Task<List<string>> FetchGiphyGifsAsync(string query)
    {
        var list = new List<string>();
        var body = new Dictionary<string, object>
        {
            { "endpoint", string.IsNullOrEmpty(query) ? "trending" : "search" },
            { "isSticker", false },
            { "limit", 12 },
            { "offset", 0 },
            { "platform", "android" }
        };
        if (!string.IsNullOrEmpty(query))
        {
            body.Add("query", query);
        }

        var bodyJson = JsonSerializer.Serialize(body);
        using var client = new System.Net.Http.HttpClient();
        var token = Oasis.WinUI.Core.Networking.SupabaseService.Client.Auth.CurrentSession?.AccessToken 
                    ?? Oasis.WinUI.Core.Config.AppConfig.SupabaseAnonKey;
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        
        var response = await client.PostAsync(
            $"{Oasis.WinUI.Core.Config.AppConfig.SupabaseUrl}/functions/v1/giphy-proxy",
            new System.Net.Http.StringContent(bodyJson, System.Text.Encoding.UTF8, "application/json"));
        
        if (!response.IsSuccessStatusCode)
        {
            var errBody = await response.Content.ReadAsStringAsync();
            Oasis.WinUI.Services.Logger.Warn("Giphy.Fetch", $"Edge function returned status: {response.StatusCode}, body: {errBody}");
            return list;
        }
        
        var json = await response.Content.ReadAsStringAsync();
        if (string.IsNullOrEmpty(json)) return list;

        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.TryGetProperty("data", out var dataEl) && dataEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in dataEl.EnumerateArray())
            {
                if (item.TryGetProperty("images", out var images) &&
                    images.TryGetProperty("fixed_height", out var fixedHeight) &&
                    fixedHeight.TryGetProperty("url", out var urlProp))
                {
                    var gifUrl = urlProp.GetString();
                    if (!string.IsNullOrEmpty(gifUrl))
                    {
                        list.Add(gifUrl);
                    }
                }
            }
        }
        return list;
    }
}
