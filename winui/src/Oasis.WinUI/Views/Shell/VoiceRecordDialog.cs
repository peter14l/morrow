using System;
using System.IO;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Media.Capture;
using Windows.Media.MediaProperties;
using Windows.Storage;

namespace Oasis.WinUI.Views.Shell;

public static class VoiceRecordDialog
{
    public sealed class VoiceRecordResult
    {
        public byte[] Data { get; }
        public string FileName { get; }
        public string MimeType { get; }
        public int DurationSeconds { get; }

        public VoiceRecordResult(byte[] data, string fileName, string mimeType, int durationSeconds)
        {
            Data = data;
            FileName = fileName;
            MimeType = mimeType;
            DurationSeconds = durationSeconds;
        }
    }

    public static async Task<VoiceRecordResult?> ShowAsync(XamlRoot root)
    {
        MediaCapture? mediaCapture = null;
        LowLagMediaRecording? mediaRecording = null;
        StorageFile? recordFile = null;
        var timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        int durationSeconds = 0;

        var statusText = new TextBlock
        {
            Text = "Press 'Record' to start recording.",
            HorizontalAlignment = HorizontalAlignment.Center,
            FontSize = 16,
            Margin = new Thickness(0, 16, 0, 16),
        };

        var recordButton = new Button
        {
            Content = "Record",
            HorizontalAlignment = HorizontalAlignment.Center,
            Width = 100,
        };

        var stopButton = new Button
        {
            Content = "Stop",
            HorizontalAlignment = HorizontalAlignment.Center,
            Width = 100,
            IsEnabled = false,
            Margin = new Thickness(8, 0, 0, 0),
        };

        var buttonPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 16),
            Children = { recordButton, stopButton }
        };

        var container = new StackPanel
        {
            Spacing = 8,
            Width = 300,
            Children = { statusText, buttonPanel }
        };

        var dialog = new ContentDialog
        {
            Title = "Record Voice Message",
            Content = container,
            PrimaryButtonText = "Send",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = root,
            IsPrimaryButtonEnabled = false,
        };

        timer.Tick += (s, e) =>
        {
            durationSeconds++;
            statusText.Text = $"Recording... {durationSeconds / 60:D2}:{durationSeconds % 60:D2}";
        };

        recordButton.Click += async (s, e) =>
        {
            try
            {
                recordButton.IsEnabled = false;
                statusText.Text = "Initializing microphone...";

                var settings = new MediaCaptureInitializationSettings
                {
                    StreamingCaptureMode = StreamingCaptureMode.Audio
                };
                mediaCapture = new MediaCapture();
                await mediaCapture.InitializeAsync(settings);

                var localFolder = ApplicationData.Current.TemporaryFolder;
                recordFile = await localFolder.CreateFileAsync($"voice_{Guid.NewGuid():N}.m4a", CreationCollisionOption.GenerateUniqueName);

                var profile = MediaEncodingProfile.CreateM4a(AudioEncodingQuality.Auto);
                mediaRecording = await mediaCapture.PrepareLowLagRecordToStorageFileAsync(profile, recordFile);

                await mediaRecording.StartAsync();
                durationSeconds = 0;
                timer.Start();

                statusText.Text = "Recording... 00:00";
                stopButton.IsEnabled = true;
                dialog.IsPrimaryButtonEnabled = false;
            }
            catch (Exception ex)
            {
                statusText.Text = $"Error: {ex.Message}";
                recordButton.IsEnabled = true;
                if (mediaCapture != null)
                {
                    mediaCapture.Dispose();
                    mediaCapture = null;
                }
            }
        };

        stopButton.Click += async (s, e) =>
        {
            try
            {
                stopButton.IsEnabled = false;
                timer.Stop();

                if (mediaRecording != null)
                {
                    await mediaRecording.StopAsync();
                    await mediaRecording.FinishAsync();
                    mediaRecording = null;
                }

                statusText.Text = $"Recorded: {durationSeconds / 60:D2}:{durationSeconds % 60:D2}";
                recordButton.Content = "Record Again";
                recordButton.IsEnabled = true;
                dialog.IsPrimaryButtonEnabled = true;
            }
            catch (Exception ex)
            {
                statusText.Text = $"Error stopping: {ex.Message}";
            }
            finally
            {
                if (mediaCapture != null)
                {
                    mediaCapture.Dispose();
                    mediaCapture = null;
                }
            }
        };

        var dialogResult = await dialog.ShowAsync();

        timer.Stop();
        if (mediaRecording != null)
        {
            try { await mediaRecording.StopAsync(); } catch { }
        }
        if (mediaCapture != null)
        {
            mediaCapture.Dispose();
        }

        if (dialogResult == ContentDialogResult.Primary && recordFile != null && durationSeconds > 0)
        {
            try
            {
                var buffer = await FileIO.ReadBufferAsync(recordFile);
                var data = buffer.ToArray();
                return new VoiceRecordResult(data, recordFile.Name, "audio/m4a", durationSeconds);
            }
            catch (Exception ex)
            {
                Oasis.WinUI.Services.Logger.Warn("VoiceRecord.Read", ex.Message);
            }
        }

        return null;
    }
}
