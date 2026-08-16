namespace Oasis.WinUI.Core.Config;

/// <summary>
/// Loads key=value pairs from a .env file (mirrors flutter_dotenv in the Flutter app).
/// Looks in the executable directory and the current working directory.
/// </summary>
public static class OasisEnv
{
    private static readonly Dictionary<string, string> _values = new(StringComparer.OrdinalIgnoreCase);
    private static bool _loaded;

    public static void Load()
    {
        if (_loaded) return;

        foreach (var path in CandidatePaths())
        {
            if (File.Exists(path))
            {
                foreach (var rawLine in File.ReadAllLines(path))
                {
                    var line = rawLine.Trim();
                    if (line.Length == 0 || line.StartsWith('#')) continue;
                    var eq = line.IndexOf('=');
                    if (eq <= 0) continue;
                    var key = line[..eq].Trim();
                    var value = line[(eq + 1)..].Trim();
                    if (value.Length >= 2 &&
                        ((value[0] == '"' && value[^1] == '"') ||
                         (value[0] == '\'' && value[^1] == '\'')))
                    {
                        value = value[1..^1];
                    }
                    _values[key] = value;
                }
            }
        }

        _loaded = true;
    }

    public static string? Get(string key)
    {
        // Prefer real environment variables, then .env file values.
        var env = Environment.GetEnvironmentVariable(key);
        if (!string.IsNullOrWhiteSpace(env)) return env;
        return _values.TryGetValue(key, out var value) ? value : null;
    }

    public static string Get(string key, string fallback)
        => Get(key) is { Length: > 0 } value ? value : fallback;

    private static IEnumerable<string> CandidatePaths()
    {
        var exeDir = AppContext.BaseDirectory;
        yield return Path.Combine(exeDir, ".env");
        var cwd = Directory.GetCurrentDirectory();
        if (!string.Equals(cwd, exeDir, StringComparison.OrdinalIgnoreCase))
        {
            yield return Path.Combine(cwd, ".env");
        }

        // Walk up parent directories to locate .env in dev environment
        var dir = new DirectoryInfo(exeDir);
        while (dir != null)
        {
            yield return Path.Combine(dir.FullName, ".env");
            dir = dir.Parent;
        }
    }

}
