using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Services;

namespace Oasis.WinUI.Views.Shell;

/// <summary>
/// Prompts for the 6-digit PIN and restores the RSA keypair from the
/// cloud v2 backup so encrypted messages can be decrypted on this device.
/// </summary>
public static class KeyRestorePrompt
{
    private static bool _checkedThisSession;

    public static async Task<bool> EnsureRestoredAsync(XamlRoot root, MessagingService messaging)
    {
        if (_checkedThisSession) return await messaging.HasPrivateKeyAsync();
        _checkedThisSession = true;
        if (await messaging.HasPrivateKeyAsync()) return true;
        if (!await messaging.HasV2BackupAsync()) return false;
        return await PromptAsync(root, messaging);
    }

    private static async Task<bool> PromptAsync(XamlRoot root, MessagingService messaging)
    {
        var box = new PasswordBox
        {
            MaxLength = 6,
            PlaceholderText = "6-digit PIN",
            PasswordChar = "●",
        };
        var dialog = new ContentDialog
        {
            Title = "Unlock your messages",
            Content = new StackPanel
            {
                Spacing = 8,
                MaxWidth = 320,
                Children =
                {
                    new TextBlock
                    {
                        Text = "Your messages are encrypted with an RSA key backed up to the cloud. Enter the 6-digit PIN you set when enabling encryption to unlock them on this device.",
                        TextWrapping = TextWrapping.Wrap,
                    },
                    box,
                },
            },
            PrimaryButtonText = "Unlock",
            CloseButtonText = "Later",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = root,
        };

        while (true)
        {
            var result = await dialog.ShowAsync();
            if (result != ContentDialogResult.Primary) return false;

            var pin = box.Password?.Trim() ?? "";
            if (pin.Length != 6)
            {
                box.Header = "PIN must be 6 digits";
                continue;
            }

            var ok = await messaging.RestoreSecureKeysFromPinAsync(pin);
            if (ok) return true;
            box.Header = "Wrong PIN. Try again.";
        }
    }
}
