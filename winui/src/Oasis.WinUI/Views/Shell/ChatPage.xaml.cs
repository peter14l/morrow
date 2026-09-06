using Microsoft.UI.Dispatching;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Services;
using Oasis.WinUI.Services;
using System.Runtime.InteropServices.WindowsRuntime;

namespace Oasis.WinUI.Views.Shell;

public sealed record ChatContext(string ConversationId, string Title, string AvatarUrl);

public sealed partial class ChatPage : Page
{
    private readonly MessagingService _messaging = new();
    private readonly List<Message> _messages = new();
    private readonly HashSet<string> _messageIds = new();
    private MessagingService.Subscription? _subscription;
    private Action? _typingUnsubscribe;
    private bool _isOtherTyping;
    private ChatContext? _currentContext;
    private string _conversationId = "";
    private string _myUserId = "";
    private string _otherUserId = "";
    private bool _loadingOlder;
    private Windows.Media.Playback.MediaPlayer? _activeVoicePlayer;
    private string? _activeVoiceMessageId;

    public ChatPage()
    {
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is not ChatContext ctx) return;

        _currentContext = ctx;
        _conversationId = ctx.ConversationId;

        _myUserId = SupabaseService.Client.Auth.CurrentUser?.Id ?? "";
        _otherUserId = await _messaging.GetOtherParticipantAsync(_conversationId) ?? "";
        ChatTitle.Text = ctx.Title;
        NotificationService.ActiveConversationId = _conversationId;

        await KeyRestorePrompt.EnsureRestoredAsync(XamlRoot, _messaging);
        await LoadBackgroundAsync();

        _messages.Clear();
        _messageIds.Clear();

        await LoadMessagesAsync(before: null);

        _subscription = _messaging.SubscribeToMessages(_conversationId, async (msg) =>
        {
            if (!_messageIds.Add(msg.Id)) return;
            _messages.Add(msg);
            var el = await BuildMessageElementAsync(msg);
            if (MessagesPanel.DispatcherQueue.HasThreadAccess)
                AppendElement(el);
            else
                MessagesPanel.DispatcherQueue.TryEnqueue(() => AppendElement(el));
            _ = _messaging.MarkConversationReadAsync(_conversationId);
            NotificationService.Instance.NotifyMessageArrived(_conversationId);
        }, async (msg) =>
        {
            _messageIds.Remove(msg.Id);
            _messages.RemoveAll(m => m.Id == msg.Id);
            if (MessagesPanel.DispatcherQueue.HasThreadAccess)
                RemoveElementById(msg.Id);
            else
                MessagesPanel.DispatcherQueue.TryEnqueue(() => RemoveElementById(msg.Id));
        }, async (msg) =>
        {
            var index = _messages.FindIndex(m => m.Id == msg.Id);
            if (index >= 0)
            {
                _messages[index] = msg;
            }
            var el = await BuildMessageElementAsync(msg);
            if (MessagesPanel.DispatcherQueue.HasThreadAccess)
                UpdateElementInUi(msg.Id, el);
            else
                MessagesPanel.DispatcherQueue.TryEnqueue(() => UpdateElementInUi(msg.Id, el));
        });

        _ = _messaging.MarkConversationReadAsync(_conversationId);

        // Typing indicator subscription
        _typingUnsubscribe = _messaging.SubscribeToTyping(_conversationId, _myUserId, isTyping =>
        {
            _isOtherTyping = isTyping;
            if (MessagesPanel.DispatcherQueue.HasThreadAccess)
                UpdateTypingIndicator();
            else
                MessagesPanel.DispatcherQueue.TryEnqueue(UpdateTypingIndicator);
        });
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);
        if (NotificationService.ActiveConversationId == _conversationId)
            NotificationService.ActiveConversationId = null;
        if (_subscription != null)
        {
            _messaging.CloseSubscription(_conversationId);
            _subscription = null;
        }
        _typingUnsubscribe?.Invoke();
        _typingUnsubscribe = null;
        if (_activeVoicePlayer != null)
        {
            _activeVoicePlayer.Dispose();
            _activeVoicePlayer = null;
        }
    }

    private async Task LoadMessagesAsync(DateTime? before)
    {
        if (_loadingOlder) return;
        _loadingOlder = true;
        try
        {
            var loaded = await _messaging.GetMessagesAsync(_conversationId, 50, before);
            if (loaded.Count == 0)
            {
                if (before != null) LoadOlderButton.Visibility = Visibility.Collapsed;
                return;
            }

            if (before == null)
            {
                foreach (var m in loaded)
                {
                    if (_messageIds.Add(m.Id)) _messages.Add(m);
                }
                await RenderMessagesAsync();
                await ScrollToBottomAsync(animate: false);
            }
            else
            {
                loaded.Reverse();
                var offset = 0;
                foreach (var m in loaded)
                {
                    if (_messageIds.Add(m.Id)) { _messages.Insert(0, m); offset++; }
                }
                if (offset > 0)
                {
                    await RenderMessagesAsync();
                    var scrollTarget = LoadOlderButton.DesiredSize.Height + offset * 48;
                    if (MessageScroller.ScrollableHeight > 0)
                        MessageScroller.ChangeView(null, scrollTarget, null, disableAnimation: true);
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.Load", ex.Message);
        }
        finally
        {
            _loadingOlder = false;
        }
    }

    private void AppendElement(FrameworkElement el)
    {
        var idx = MessagesPanel.Children.IndexOf(TypingIndicator);
        if (idx >= 0)
            MessagesPanel.Children.Insert(idx, el);
        else
            MessagesPanel.Children.Add(el);
        _ = ScrollToBottomAsync(animate: false);
    }

    private void RemoveElementById(string id)
    {
        var existing = MessagesPanel.Children
            .OfType<FrameworkElement>()
            .FirstOrDefault(c => (c.Tag as string) == id);
        if (existing != null) MessagesPanel.Children.Remove(existing);
    }

    private void UpdateElementInUi(string id, FrameworkElement newEl)
    {
        var existing = MessagesPanel.Children
            .OfType<FrameworkElement>()
            .FirstOrDefault(c => (c.Tag as string) == id);
        if (existing != null)
        {
            var idx = MessagesPanel.Children.IndexOf(existing);
            if (idx >= 0)
            {
                MessagesPanel.Children[idx] = newEl;
            }
        }
    }

    private async Task RenderMessagesAsync()
    {
        MessagesPanel.Children.Clear();
        MessagesPanel.Children.Add(LoadOlderButton);

        var elements = new List<FrameworkElement>();
        foreach (var m in _messages)
            elements.Add(await BuildMessageElementAsync(m));
        foreach (var el in elements) MessagesPanel.Children.Insert(MessagesPanel.Children.Count, el);
        MessagesPanel.Children.Add(TypingIndicator);
    }

    private async Task<FrameworkElement> BuildMessageElementAsync(Message msg)
    {
        try
        {
            Logger.Warn("ChatPage.BuildElement", $"Building message: ID={msg.Id}, Type={msg.MessageType}, IsMedia={msg.IsMedia}, MediaUrl={msg.MediaUrl}, VoiceDuration={msg.VoiceDuration}, Sender={msg.SenderId}");
            var mine = msg.SenderId == _myUserId;
            var isGroup = _otherUserId.Length > 0;
            FontIcon? voiceFontIcon = null;
            ProgressBar? voiceProgressBar = null;
            var text = await _messaging.DecryptDisplayContentAsync(msg, _myUserId);

            var inner = new StackPanel { Spacing = 2, MaxWidth = 420 };

            if (!mine && isGroup && !string.IsNullOrEmpty(msg.SenderName))
            {
                inner.Children.Add(new TextBlock
                {
                    Text = msg.SenderName,
                    FontSize = 11,
                    Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
                });
            }

            if (msg.IsMedia)
            {
                var mediaLabel = msg.MessageType switch
                {
                    "image" => "Image",
                    "video" => "Video",
                    "voice" => "Voice message",
                    "document" => msg.MediaFileName ?? "File",
                    _ => "Attachment",
                };

                if (msg.MessageType == "image" && !string.IsNullOrEmpty(msg.MediaUrl))
                {
                    try
                    {
                        inner.Children.Add(new Image
                        {
                            Source = new BitmapImage(new Uri(msg.MediaUrl)),
                            MaxHeight = 220,
                            Stretch = Stretch.Uniform,
                            Tag = msg.Id,
                        });
                    }
                    catch
                    {
                        inner.Children.Add(MakeTextBlock(mediaLabel, mine));
                    }
                }
                else if (msg.MessageType == "voice")
                {
                    var voicePanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                    Brush? iconBrush = null;
                    if (mine)
                    {
                        iconBrush = new SolidColorBrush(Microsoft.UI.Colors.Black);
                    }
                    else
                    {
                        try
                        {
                            var key = "TextFillColorPrimaryBrush";
                            if (Application.Current.Resources.TryGetValue(key, out var res) && res is Brush b)
                            {
                                iconBrush = b;
                            }
                        }
                        catch { }
                    }
                    if (iconBrush == null)
                    {
                        iconBrush = mine
                            ? new SolidColorBrush(Microsoft.UI.Colors.Black)
                            : new SolidColorBrush(Microsoft.UI.Colors.White);
                    }

                    var fontIcon = new FontIcon 
                    { 
                        Glyph = "\uE768", // Play glyph
                        FontSize = 16,
                        Foreground = iconBrush
                    };
                    voiceFontIcon = fontIcon;
                    voicePanel.Children.Add(fontIcon);
                    var durationText = msg.VoiceDuration > 0 ? $"{msg.VoiceDuration}s" : "Voice";
                    voicePanel.Children.Add(MakeTextBlock($"Voice message ({durationText})", mine));
                    inner.Children.Add(voicePanel);

                    var progressBar = new ProgressBar
                    {
                        Minimum = 0,
                        Maximum = msg.VoiceDuration > 0 ? (double)msg.VoiceDuration.Value : 10.0,
                        Value = 0,
                        Height = 4,
                        Width = 180,
                        HorizontalAlignment = HorizontalAlignment.Left,
                        Margin = new Thickness(24, 6, 0, 2),
                        Foreground = iconBrush,
                    };
                    voiceProgressBar = progressBar;
                    inner.Children.Add(progressBar);
                }
                else
                {
                    inner.Children.Add(MakeTextBlock(mediaLabel, mine));
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(text))
                {
                    inner.Children.Add(MakeTextBlock(text, mine));
                }
            }

            var metaRow = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 5,
                HorizontalAlignment = mine ? HorizontalAlignment.Right : HorizontalAlignment.Left,
                Margin = new Thickness(0, 2, 0, 0),
            };

            if (msg.IsPqAuraEncrypted)
            {
                metaRow.Children.Add(new FontIcon
                {
                    Glyph = "\uE72E", // Lock icon
                    FontSize = 10,
                    Foreground = (Brush)Application.Current.Resources["TextFillColorTertiaryBrush"],
                    VerticalAlignment = VerticalAlignment.Center,
                });
            }

            metaRow.Children.Add(new TextBlock
            {
                Text = msg.Timestamp.ToString("HH:mm"),
                FontSize = 10,
                Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
                VerticalAlignment = VerticalAlignment.Center,
            });

            if (mine)
            {
                var isRead = msg.IsRead || msg.ReadAt.HasValue || msg.AnyReadAt.HasValue;
                var tickColor = isRead ? new SolidColorBrush(Microsoft.UI.Colors.DeepSkyBlue) : (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"];

                metaRow.Children.Add(new FontIcon
                {
                    Glyph = isRead ? "\uE8FB" : "\uE73E", // Double check / check mark glyph
                    FontSize = 11,
                    FontWeight = isRead ? FontWeights.Bold : FontWeights.Normal,
                    Foreground = tickColor,
                    VerticalAlignment = VerticalAlignment.Center,
                });
            }

            inner.Children.Add(metaRow);

            var bubble = new Border
            {
                Background = mine
                    ? (Brush)Application.Current.Resources["AccentFillColorDefaultBrush"]
                    : (Brush)Application.Current.Resources["ControlFillColorSecondaryBrush"],
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(14, 10, 14, 10),
                Child = inner,
                Tag = msg.Id,
                HorizontalAlignment = mine ? HorizontalAlignment.Right : HorizontalAlignment.Left,
            };

            bubble.RightTapped += MessageBubble_RightTapped;

            if (msg.MessageType == "voice" && !string.IsNullOrEmpty(msg.MediaUrl))
            {
                var iconRef = voiceFontIcon;
                var pbRef = voiceProgressBar;
                bubble.Tapped += (s, e) =>
                {
                    try
                    {
                        if (_activeVoicePlayer != null && _activeVoiceMessageId == msg.Id)
                        {
                            if (_activeVoicePlayer.PlaybackSession.PlaybackState == Windows.Media.Playback.MediaPlaybackState.Playing)
                            {
                                _activeVoicePlayer.Pause();
                                if (iconRef != null) iconRef.Glyph = "\uE768"; // Play
                            }
                            else
                            {
                                _activeVoicePlayer.Play();
                                if (iconRef != null) iconRef.Glyph = "\uE769"; // Pause
                            }
                            return;
                        }

                        if (_activeVoicePlayer != null)
                        {
                            _activeVoicePlayer.Dispose();
                        }

                        _activeVoicePlayer = new Windows.Media.Playback.MediaPlayer();
                        _activeVoiceMessageId = msg.Id;
                        _activeVoicePlayer.Source = Windows.Media.Core.MediaSource.CreateFromUri(new Uri(msg.MediaUrl));

                        _activeVoicePlayer.PlaybackSession.PlaybackStateChanged += (sender, args) =>
                        {
                            MessagesPanel.DispatcherQueue.TryEnqueue(() =>
                            {
                                if (iconRef != null)
                                {
                                    if (sender.PlaybackState == Windows.Media.Playback.MediaPlaybackState.Playing)
                                        iconRef.Glyph = "\uE769"; // Pause
                                    else
                                        iconRef.Glyph = "\uE768"; // Play
                                }
                            });
                        };

                        _activeVoicePlayer.PlaybackSession.PositionChanged += (sender, args) =>
                        {
                            MessagesPanel.DispatcherQueue.TryEnqueue(() =>
                            {
                                if (pbRef != null)
                                {
                                    pbRef.Value = sender.Position.TotalSeconds;
                                }
                            });
                        };

                        _activeVoicePlayer.MediaEnded += (sender, args) =>
                        {
                            MessagesPanel.DispatcherQueue.TryEnqueue(() =>
                            {
                                if (iconRef != null) iconRef.Glyph = "\uE768";
                                if (pbRef != null) pbRef.Value = 0;
                            });
                        };

                        _activeVoicePlayer.Play();
                    }
                    catch (Exception ex)
                    {
                        Logger.Warn("ChatPage.VoicePlay", ex.Message);
                    }
                };
            }

            var margin = mine ? new Thickness(48, 0, 0, 0) : new Thickness(0, 0, 48, 0);
            bubble.Margin = margin;
            return bubble;
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.BuildElement.Error", $"Error rendering message {msg.Id}: {ex}");
            return new TextBlock { Text = $"Rendering error: {ex.Message}" };
        }
    }

    private static TextBlock MakeTextBlock(string text, bool mine)
    {
        Brush? brush = null;
        if (mine)
        {
            brush = new SolidColorBrush(Microsoft.UI.Colors.Black);
        }
        else
        {
            try
            {
                var key = "TextFillColorPrimaryBrush";
                if (Application.Current.Resources.TryGetValue(key, out var res) && res is Brush b)
                {
                    brush = b;
                }
            }
            catch { }
        }

        if (brush == null)
        {
            brush = mine
                ? new SolidColorBrush(Microsoft.UI.Colors.Black)
                : new SolidColorBrush(Microsoft.UI.Colors.White);
        }

        return new TextBlock
        {
            Text = text,
            TextWrapping = TextWrapping.Wrap,
            Foreground = brush,
            FontSize = 15,
        };
    }

    private async void MessageBubble_RightTapped(object sender, RightTappedRoutedEventArgs e)
    {
        var border = sender as Border;
        if (border?.Tag is not string msgId) return;
        var msg = _messages.FirstOrDefault(m => m.Id == msgId);
        if (msg == null) return;

        var isOwn = msg.SenderId == _myUserId;
        var decryptedText = await _messaging.DecryptDisplayContentAsync(msg, _myUserId);

        var previewText = !string.IsNullOrWhiteSpace(decryptedText)
            ? decryptedText
            : (msg.IsMedia ? (msg.MediaFileName ?? msg.MessageType) : msg.Content);

        if (previewText.Length > 120)
            previewText = previewText.Substring(0, 120) + "...";

        var stack = new StackPanel
        {
            Spacing = 12,
            MaxWidth = 360,
        };

        // Quick Emoji Reaction Picker Row
        var reactionBar = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 6,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 8),
        };

        var emojis = new[] { "❤️", "👍", "😂", "😮", "😢", "🔥" };
        ContentDialog? currentDialog = null;

        foreach (var emoji in emojis)
        {
            var btn = new Button
            {
                Content = emoji,
                FontSize = 20,
                Padding = new Thickness(6, 4, 6, 4),
                Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent),
                BorderThickness = new Thickness(0),
                CornerRadius = new CornerRadius(16),
            };

            btn.Click += async (s, args) =>
            {
                currentDialog?.Hide();
                await _messaging.AddReactionAsync(msg.Id, emoji);
            };

            reactionBar.Children.Add(btn);
        }

        stack.Children.Add(reactionBar);

        // Preview Box
        var previewBorder = new Border
        {
            Background = (Brush)Application.Current.Resources["CardBackgroundFillColorDefaultBrush"],
            BorderBrush = (Brush)Application.Current.Resources["CardStrokeColorDefaultBrush"],
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12, 8, 12, 8),
            Child = new StackPanel
            {
                Spacing = 4,
                Children =
                {
                    new TextBlock
                    {
                        Text = isOwn ? "You" : (msg.SenderName.Length > 0 ? msg.SenderName : "Received"),
                        FontSize = 11,
                        FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                        Foreground = (Brush)Application.Current.Resources["AccentTextFillColorPrimaryBrush"],
                    },
                    new TextBlock
                    {
                        Text = previewText,
                        FontSize = 13,
                        TextWrapping = TextWrapping.Wrap,
                        MaxLines = 3,
                    },
                }
            }
        };

        stack.Children.Add(previewBorder);

        var dialog = new ContentDialog
        {
            Title = "Message options",
            Content = stack,
            PrimaryButtonText = "Copy text",
            SecondaryButtonText = isOwn ? "Unsend" : null!,
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        currentDialog = dialog;

        dialog.PrimaryButtonClick += (d, args) =>
        {
            try
            {
                var data = new Windows.ApplicationModel.DataTransfer.DataPackage();
                data.SetText(decryptedText);
                Windows.ApplicationModel.DataTransfer.Clipboard.SetContent(data);
            }
            catch { }
        };

        if (isOwn)
        {
            dialog.SecondaryButtonClick += (d, args) =>
            {
                _ = _messaging.DeleteMessageAsync(msg.Id);
                _messageIds.Remove(msg.Id);
                _messages.RemoveAll(m => m.Id == msg.Id);
                RemoveElementById(msg.Id);
                _ = _messaging.MarkConversationReadAsync(_conversationId);
            };
        }

        await dialog.ShowAsync();
    }


    private async Task ScrollToBottomAsync(bool animate)
    {
        await Task.Delay(30);
        if (MessageScroller.ScrollableHeight > 0)
            MessageScroller.ChangeView(null, MessageScroller.ScrollableHeight, null, !animate);
    }

    private void UpdateTypingIndicator()
    {
        if (_isOtherTyping && _otherUserId.Length > 0)
        {
            TypingIndicator.Text = "Someone is typing...";
            TypingIndicator.Visibility = Visibility.Visible;
        }
        else
        {
            TypingIndicator.Visibility = Visibility.Collapsed;
        }
        _ = ScrollToBottomAsync(animate: false);
    }

    private async void SendButton_Click(object sender, RoutedEventArgs e)
        => await SendAsync();

    private async void ComposerBox_KeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == Windows.System.VirtualKey.Enter && !e.KeyStatus.WasKeyDown)
        {
            e.Handled = true;
            await SendAsync();
        }
    }

    private void AttachmentButton_Click(object sender, RoutedEventArgs e)
        => ShowAttachmentDialog();

    private async void GifButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var gifUrl = await GifPickerDialog.ShowAsync(XamlRoot);
            if (!string.IsNullOrEmpty(gifUrl))
            {
                var id = await _messaging.SendGifAsync(_conversationId, gifUrl);
                if (!string.IsNullOrEmpty(id))
                {
                    var msg = await _messaging.GetMessageByIdAsync(id);
                    if (msg != null)
                    {
                        if (_messageIds.Add(id)) _messages.Add(msg);
                        var el = await BuildMessageElementAsync(msg);
                        AppendElement(el);
                        NotificationService.Instance.NotifyMessageArrived(_conversationId);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.GifClick", ex.Message);
        }
    }

    private async void MicButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var result = await VoiceRecordDialog.ShowAsync(XamlRoot);
            if (result != null)
            {
                var id = await _messaging.SendMediaAsync(_conversationId, result.Data, result.FileName, result.MimeType, result.DurationSeconds);
                if (!string.IsNullOrEmpty(id))
                {
                    var msg = await _messaging.GetMessageByIdAsync(id);
                    if (msg != null)
                    {
                        if (_messageIds.Add(id)) _messages.Add(msg);
                        var el = await BuildMessageElementAsync(msg);
                        AppendElement(el);
                        NotificationService.Instance.NotifyMessageArrived(_conversationId);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.MicClick", ex.Message);
        }
    }

    private async void ShowAttachmentDialog()
    {
        try
        {
            var folderPicker = new Windows.Storage.Pickers.FileOpenPicker();
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindowInstance);
            WinRT.Interop.InitializeWithWindow.Initialize(folderPicker, hwnd);
            folderPicker.SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.DocumentsLibrary;
            folderPicker.FileTypeFilter.Add("*");
            var file = await folderPicker.PickSingleFileAsync();
            if (file != null)
            {
                var buffer = await Windows.Storage.FileIO.ReadBufferAsync(file);
                var data = buffer.ToArray();
                var mimeType = file.ContentType;
                var fileName = file.Name;
                var id = await _messaging.SendMediaAsync(_conversationId, data, fileName, mimeType);
                if (!string.IsNullOrEmpty(id))
                {
                    var msg = await _messaging.GetMessageByIdAsync(id);
                    if (msg != null)
                    {
                        if (_messageIds.Add(id)) _messages.Add(msg);
                        var el = await BuildMessageElementAsync(msg);
                        AppendElement(el);
                        NotificationService.Instance.NotifyMessageArrived(_conversationId);
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("Attachment.Pick", ex.Message);
        }
    }


    private async void ComposerBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(ComposerBox.Text))
        {
            _ = _messaging.SetTypingAsync(_conversationId, _myUserId, false);
        }
        else
        {
            _ = _messaging.SetTypingAsync(_conversationId, _myUserId, true);
        }
    }

    private async Task SendAsync()
    {
        _ = _messaging.SetTypingAsync(_conversationId, _myUserId, false);
        var text = ComposerBox.Text?.Trim();
        if (string.IsNullOrEmpty(text)) return;

        try
        {
            var id = await _messaging.SendTextAsync(_conversationId, text);
            ComposerBox.Text = "";
            if (string.IsNullOrEmpty(id)) return;

            var msg = new Message
            {
                Id = id,
                ConversationId = _conversationId,
                SenderId = _myUserId,
                Content = text,
                MessageType = "text",
                Timestamp = DateTime.Now,
            };
            if (_messageIds.Add(id)) _messages.Add(msg);
            var el = await BuildMessageElementAsync(msg);
            AppendElement(el);
            NotificationService.Instance.NotifyMessageArrived(_conversationId);
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.Send", ex.Message);
        }
    }

    private async void LoadOlderButton_Click(object sender, RoutedEventArgs e)
    {
        var oldest = _messages.Count > 0 ? _messages[0].Timestamp : (DateTime?)null;
        await LoadMessagesAsync(oldest);
    }

    private async Task LoadBackgroundAsync()
    {
        try
        {
            var bgUrl = await _messaging.GetChatBackgroundAsync(_conversationId);
            if (!string.IsNullOrEmpty(bgUrl))
            {
                ChatBackgroundImage.Source = new BitmapImage(new Uri(bgUrl));
            }
            else
            {
                ChatBackgroundImage.Source = null;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.LoadBackground", ex.Message);
        }
    }

    private async void SetBackgroundBtn_Click(object sender, RoutedEventArgs e)
    {
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
            var path = $"backgrounds/{_conversationId}/{fileName}";
            await storage.Upload(bytes, path);
            var publicUrl = storage.GetPublicUrl(path);

            if (!string.IsNullOrEmpty(publicUrl))
            {
                await _messaging.UpdateChatBackgroundAsync(_conversationId, publicUrl);
                ChatBackgroundImage.Source = new BitmapImage(new Uri(publicUrl));
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("ChatPage.SetBackground", ex.Message);
        }
    }

    private void ChatDetailsBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_currentContext != null)
        {
            Frame.Navigate(typeof(ChatDetailsPage), _currentContext);
        }
    }
}

