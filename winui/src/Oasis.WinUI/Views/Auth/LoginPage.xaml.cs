using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Views.Auth;

public sealed partial class LoginPage : Page
{
    private bool _busy;

    public LoginPage()
    {
        InitializeComponent();
        RegisterLink.Click += (_, _) => Frame.Navigate(typeof(RegisterPage));
        ForgotPasswordLink.Click += async (_, _) => await ResetPasswordAsync();
        Loaded += async (_, _) =>
        {
            try
            {
                var source = new CommunityToolkit.WinUI.Lottie.LottieVisualSource
                {
                    UriSource = new Uri("ms-appx:///Assets/Login.json")
                };
                LoginLottiePlayer.Source = source;
                await LoginLottiePlayer.PlayAsync(0, 1, true);
            }
            catch (Exception ex)
            {
                Logger.Warn("LoginPage.Lottie", ex.Message);
            }
        };
    }

    private void SetBusy(bool busy)
    {
        _busy = busy;
        SignInButton.IsEnabled = !busy;
        GoogleButton.IsEnabled = !busy;
        BusyRing.IsActive = busy;
        BusyRing.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ShowError(string message)
    {
        ErrorBar.Message = message;
        ErrorBar.IsOpen = true;
    }

    private async void SignInButton_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;

        var identifier = IdentifierBox.Text.Trim();
        var password = PasswordBox.Password;

        if (string.IsNullOrEmpty(identifier) || string.IsNullOrEmpty(password))
        {
            ShowError("Please enter your email or username and password.");
            return;
        }

        SetBusy(true);
        try
        {
            await AuthService.Current.SignInWithEmailAsync(identifier, password);
            App.MainWindowInstance?.NavigateToShell();
        }
        catch (Exception ex)
        {
            Logger.Warn("LoginPage", ex.Message);
            ShowError(ToUserMessage(ex));
        }
        finally
        {
            SetBusy(false);
        }
    }

    private async void GoogleButton_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;

        SetBusy(true);
        try
        {
            await AuthService.Current.SignInWithGoogleAsync();
            App.MainWindowInstance?.NavigateToShell();
        }
        catch (Exception ex)
        {
            Logger.Warn("LoginPage.Google", ex.Message);
            ShowError("Google sign-in failed: " + ToUserMessage(ex));
        }
        finally
        {
            SetBusy(false);
        }
    }

    private async Task ResetPasswordAsync()
    {
        var identifier = IdentifierBox.Text.Trim();
        if (string.IsNullOrEmpty(identifier))
        {
            ShowError("Enter your email or username first, then use Forgot password.");
            return;
        }

        SetBusy(true);
        try
        {
            await AuthService.Current.ResetPasswordAsync(identifier);
            ErrorBar.Severity = InfoBarSeverity.Success;
            ShowError("If that account exists, a reset link has been sent.");
        }
        catch (Exception ex)
        {
            Logger.Warn("LoginPage.Reset", ex.Message);
            ErrorBar.Severity = InfoBarSeverity.Error;
            ShowError(ToUserMessage(ex));
        }
        finally
        {
            SetBusy(false);
        }
    }

    private static string ToUserMessage(Exception ex)
    {
        return ex.Message.Replace("Invalid login credentials.", "Invalid email or password.");
    }
}
