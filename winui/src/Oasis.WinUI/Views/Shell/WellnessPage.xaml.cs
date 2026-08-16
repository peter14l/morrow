using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Oasis.WinUI.Core.Services;

namespace Oasis.WinUI.Views.Shell;

public sealed partial class WellnessPage : Page
{
    private readonly WellnessService _wellnessService = new();
    private DispatcherQueueTimer? _timer;
    private int _remainingSeconds = 25 * 60;
    private bool _isRunning = false;

    public WellnessPage()
    {
        InitializeComponent();
        Loaded += async (_, _) => await LoadWellnessDataAsync();
    }

    private async Task LoadWellnessDataAsync()
    {
        var stats = await _wellnessService.GetWellnessStatsAsync();
        EnergyProgress.Value = stats.CurrentEnergyLevel;
        EnergyLabel.Text = $"{stats.CurrentEnergyLevel}% Charged";
        TodayMinutesLabel.Text = $"{stats.FocusMinutesToday} mins";
        WeeklyMinutesLabel.Text = $"This week: {stats.FocusMinutesThisWeek} mins";
        AchievementsList.ItemsSource = stats.UnlockedAchievements;
    }

    private void StartTimerBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_isRunning)
        {
            _timer?.Stop();
            _isRunning = false;
            StartTimerBtn.Content = "Resume";
        }
        else
        {
            _timer ??= DispatcherQueue.CreateTimer();
            _timer.Interval = TimeSpan.FromSeconds(1);
            _timer.Tick += (s, ev) =>
            {
                if (_remainingSeconds > 0)
                {
                    _remainingSeconds--;
                    UpdateTimerDisplay();
                }
                else
                {
                    _timer.Stop();
                    _isRunning = false;
                    StartTimerBtn.Content = "Start Focus";
                    _ = OnFocusCompletedAsync();
                }
            };
            _timer.Start();
            _isRunning = true;
            StartTimerBtn.Content = "Pause";
        }
    }

    private void ResetTimerBtn_Click(object sender, RoutedEventArgs e)
    {
        _timer?.Stop();
        _isRunning = false;
        _remainingSeconds = 25 * 60;
        StartTimerBtn.Content = "Start Focus";
        UpdateTimerDisplay();
    }

    private void UpdateTimerDisplay()
    {
        var minutes = _remainingSeconds / 60;
        var seconds = _remainingSeconds % 60;
        TimerDisplay.Text = $"{minutes:D2}:{seconds:D2}";
    }

    private async Task OnFocusCompletedAsync()
    {
        await _wellnessService.RecordFocusSessionAsync("focus", 25, 60, 90, "Completed Pomodoro Session");
        App.MainWindowInstance?.ShowSystemNotification("Focus Completed!", "Great job! Take a mindful 5-minute break.");
        await LoadWellnessDataAsync();
    }
}
