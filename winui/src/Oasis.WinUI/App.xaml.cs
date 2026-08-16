using Microsoft.UI.Xaml;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;

namespace Oasis.WinUI;

public partial class App : Application
{
    public static MainWindow? MainWindowInstance { get; private set; }

    public App()
    {
        InitializeComponent();
    }

    protected override async void OnLaunched(Microsoft.UI.Xaml.LaunchActivatedEventArgs args)
    {
        MainWindowInstance = new MainWindow();
        MainWindowInstance.Activate();

        try
        {
            OasisEnv.Load();

            try
            {
                await SupabaseService.InitializeAsync();
                await AuthService.Current.RestoreSessionAsync();
                MainWindowInstance.NavigateToShellOrLogin();
            }
            catch (Exception ex)
            {
                Logger.Warn("Initialization", $"Failed to initialize services: {ex.Message}");
                // Navigate to login even if services fail
                MainWindowInstance.NavigateToLogin();
            }
        }
        catch (Exception ex)
        {
            Logger.LogCritical("Startup", ex);
            // Show login page as last resort
            MainWindowInstance.NavigateToLogin();
        }
    }

}
