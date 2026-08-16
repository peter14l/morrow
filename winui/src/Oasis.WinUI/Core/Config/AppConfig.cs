namespace Oasis.WinUI.Core.Config;

public static class AppConfig
{
    public const string AppName = "Oasis";
    public const string Version = "1.1.16";

    public static string SupabaseUrl => OasisEnv.Get("SUPABASE_URL", string.Empty);
    public static string SupabaseAnonKey => OasisEnv.Get("SUPABASE_ANON_KEY", string.Empty);
    public static string? SentryDsn => OasisEnv.Get("SENTRY_DSN");
    public static string? GoogleWebClientId => OasisEnv.Get("GOOGLE_WEB_CLIENT_ID");
    public static string? GoogleWebClientSecret => OasisEnv.Get("GOOGLE_WEB_CLIENT_SECRET");
    public static string? GiphyWindowsKey => OasisEnv.Get("GIPHY_WINDOWS_KEY");

    /// <summary>Base URL for the web portal / auth callbacks.</summary>
    public static string WebBaseUrl => OasisEnv.Get("WEB_BASE_URL", "https://oasis-web-red.vercel.app");

    public static string CdnUrl => OasisEnv.Get("CDN_URL", $"{SupabaseUrl}/storage/v1/object/public");

    public static string GetWebUrl(string path)
    {
        var baseUrl = WebBaseUrl.TrimEnd('/');
        return $"{baseUrl}/{path.TrimStart('/')}";
    }
}
