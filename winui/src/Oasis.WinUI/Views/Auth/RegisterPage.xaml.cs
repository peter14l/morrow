using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Auth;

public sealed partial class RegisterPage : Page
{
    private bool _busy;

    public RegisterPage()
    {
        InitializeComponent();
        SignInLink.Click += (_, _) => Frame.Navigate(typeof(LoginPage));
    }

    private void SetBusy(bool busy)
    {
        _busy = busy;
        CreateAccountButton.IsEnabled = !busy;
        BusyRing.IsActive = busy;
        BusyRing.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ShowError(string message)
    {
        ErrorBar.Message = message;
        ErrorBar.IsOpen = true;
    }

    private async void CreateAccountButton_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;

        var fullName = FullNameBox.Text.Trim();
        var username = UsernameBox.Text.Trim();
        var email = EmailBox.Text.Trim();
        var password = PasswordBox.Password;

        if (string.IsNullOrEmpty(fullName) || string.IsNullOrEmpty(username) || string.IsNullOrEmpty(email) || string.IsNullOrEmpty(password))
        {
            ShowError("Please fill in all fields.");
            return;
        }
        if (password.Length < 6)
        {
            ShowError("Password must be at least 6 characters.");
            return;
        }

        SetBusy(true);
        try
        {
            await AuthService.Current.SignUpAsync(email, password, username, fullName);
            App.MainWindowInstance?.NavigateToShell();
        }
        catch (Exception ex)
        {
            Logger.Warn("RegisterPage", ex.Message);
            ShowError(ex.Message);
        }
        finally
        {
            SetBusy(false);
        }
    }
}
