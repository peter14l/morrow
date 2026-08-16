using System.Diagnostics;

namespace Oasis.WinUI.Services;

public static class Logger
{
    public static void Info(string tag, string message)
    {
        Debug.WriteLine($"[Oasis][{tag}] {message}");
        Console.WriteLine($"[Oasis][{tag}] {message}");
    }

    public static void Warn(string tag, string message)
    {
        var line = $"[{DateTime.Now:O}] [{tag}] WARN: {message}";
        Debug.WriteLine($"[Oasis][WARN][{tag}] {message}");
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Oasis", "logs", "warn.log");
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            File.AppendAllText(logPath, line + Environment.NewLine);
        }
        catch { }
    }

    public static void Error(string tag, Exception ex)
    {
        Debug.WriteLine($"[Oasis][ERROR][{tag}] {ex}");
        var logPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Oasis", "logs", "error.log");
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            File.AppendAllText(logPath, $"[{DateTime.Now:O}] [{tag}] {ex}{Environment.NewLine}");
        }
        catch
        {
            // Logging must never crash the app
        }
    }

    public static void LogCritical(string tag, Exception ex) => Error(tag, ex);
}
