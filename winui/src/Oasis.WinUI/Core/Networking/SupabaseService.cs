using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Storage;
using Oasis.WinUI.Services;
using Supabase;

namespace Oasis.WinUI.Core.Networking;

/// <summary>
/// Wraps the Supabase client for the app. Mirrors lib/core/network/supabase_client.dart.
/// </summary>
public static class SupabaseService
{
    private static Supabase.Client? _client;
    public static bool IsInitialized { get; private set; }

    public static Supabase.Client Client
    {
        get
        {
            if (_client == null)
                throw new InvalidOperationException("Supabase client not initialized.");
            return _client;
        }
    }

    public static async Task InitializeAsync()
    {
        if (IsInitialized) return;

        var url = AppConfig.SupabaseUrl;
        var anonKey = AppConfig.SupabaseAnonKey;

        if (string.IsNullOrEmpty(url) || string.IsNullOrEmpty(anonKey))
        {
            throw new InvalidOperationException(
                "Supabase configuration is missing. Add SUPABASE_URL and SUPABASE_ANON_KEY to your .env file.");
        }

        try
        {
            var options = new SupabaseOptions
            {
                AutoRefreshToken = true,
                AutoConnectRealtime = true,
                SessionHandler = new SecureSessionPersistor(),
            };

            _client = new Supabase.Client(url, anonKey, options);
            await _client.InitializeAsync();
            IsInitialized = true;
            Logger.Info("SupabaseService", "Supabase initialized successfully");
        }
        catch (Exception ex)
        {
            Logger.Error("SupabaseService.Initialize", ex);
            throw new InvalidOperationException("Failed to connect to Oasis servers.", ex);
        }
    }

    public static async Task SignOutAsync()
    {
        if (!IsInitialized) return;
        try
        {
            await Client.Auth.SignOut();
        }
        catch (Exception ex)
        {
            Logger.Error("SupabaseService.SignOut", ex);
            throw;
        }
    }

    /// <summary>Gets a public URL for a storage object (optionally with CDN + transform).</summary>
    public static string GetPublicUrl(string bucket, string path, bool useCdn = true)
        => $"{AppConfig.CdnUrl}/{bucket}/{path}";
}
