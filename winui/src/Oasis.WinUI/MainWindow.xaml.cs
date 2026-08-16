using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using System.Windows.Input;
using System.Runtime.InteropServices;
using Oasis.WinUI.Core.Auth;
using Oasis.WinUI.Services;
using Oasis.WinUI.Views.Auth;
using Oasis.WinUI.Views.Shell;

namespace Oasis.WinUI;

public sealed partial class MainWindow : Window
{
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    public ICommand RestoreCommand { get; }
    public ICommand ExitCommand { get; }

    private bool _exitRequested;

    public MainWindow()
    {
        InitializeComponent();

        RestoreCommand = new RelayCommand(ShowWindow);
        ExitCommand = new RelayCommand(() =>
        {
            _exitRequested = true;
            MyNotifyIcon.Dispose();
            Application.Current.Exit();
        });

        Activated += (s, e) =>
        {
            try
            {
                AppWindow.SetIcon("Assets/AppIcon.ico");
            }
            catch (Exception ex)
            {
                Logger.Warn("MainWindow.Icon", ex.Message);
            }
        };

        // Minimize to tray on close (unless explicitly exiting)
        AppWindow.Closing += AppWindow_Closing;
        MyNotifyIcon.DoubleClickCommand = RestoreCommand;

        ApplyDarkTitleBar();
    }

    private void ApplyDarkTitleBar()
    {
        var windowHandle = WinRT.Interop.WindowNative.GetWindowHandle(this);
        var attr = 19;
        var attrValue = 1;
        DwmSetWindowAttribute(windowHandle, attr, ref attrValue, Marshal.SizeOf<int>());
        ExtendsContentIntoTitleBar = true;
    }

    private void AppWindow_Closing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_exitRequested) return;
        args.Cancel = true;
        HideWindow();
    }

    public void ShowWindow()
    {
        AppWindow.Show();
    }

    public void HideWindow()
    {
        AppWindow.Hide();
    }

    public void NavigateToShell()
    {
        RootFrame.Navigate(typeof(MainShellPage));
    }

    public void NavigateToLogin()
    {
        RootFrame.Navigate(typeof(LoginPage));
    }

    public void NavigateToShellOrLogin()
    {
        RootFrame.Navigate(AuthService.Current.IsAuthenticated
            ? typeof(MainShellPage)
            : typeof(LoginPage));
    }

    public void ShowSystemNotification(string title, string body)
    {
        DispatcherQueue.TryEnqueue(() =>
        {
            try
            {
                MyNotifyIcon.ShowNotification(title, body, H.NotifyIcon.Core.NotificationIcon.Info);
            }
            catch (Exception ex)
            {
                Logger.Warn("Notify.Show", ex.Message);
            }
        });
    }
}

public sealed class RelayCommand : ICommand
{
    private readonly Action _execute;
    public RelayCommand(Action execute) => _execute = execute;
    public bool CanExecute(object? parameter) => true;
    public void Execute(object? parameter) => _execute();
    public event EventHandler? CanExecuteChanged;
}
