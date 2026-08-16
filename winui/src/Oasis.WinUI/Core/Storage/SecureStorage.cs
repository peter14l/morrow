using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Oasis.WinUI.Services;
using Supabase.Gotrue;
using Supabase.Gotrue.Interfaces;

namespace Oasis.WinUI.Core.Storage;

/// <summary>
/// DPAPI-backed secure storage. Mirrors flutter_secure_storage on Windows
/// (which is backed by DPAPI/Credential Manager).
/// </summary>
public static class SecureStorage
{
    private static readonly byte[] AppEntropy = Encoding.UTF8.GetBytes("Oasis.WinUI.v1");

    private static string StorageDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Oasis");

    public static async Task SaveAsync(string key, string value)
        => await Task.Run(() => Save(key, value));

    public static async Task<string?> LoadAsync(string key)
        => await Task.Run(() => Load(key));

    public static async Task DeleteAsync(string key)
        => await Task.Run(() => Delete(key));

    public static void Save(string key, string value)
    {
        try
        {
            Directory.CreateDirectory(StorageDir);
            var encrypted = ProtectedData.Protect(
                Encoding.UTF8.GetBytes(value), AppEntropy, DataProtectionScope.CurrentUser);
            var path = Path.Combine(StorageDir, SafeKey(key));
            File.WriteAllBytes(path, encrypted);
        }
        catch (Exception ex)
        {
            Logger.Error("SecureStorage.Save", ex);
        }
    }

    public static string? Load(string key)
    {
        try
        {
            var path = Path.Combine(StorageDir, SafeKey(key));
            if (!File.Exists(path)) return null;
            var encrypted = File.ReadAllBytes(path);
            var plain = ProtectedData.Unprotect(
                encrypted, AppEntropy, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plain);
        }
        catch (Exception ex)
        {
            Logger.Error("SecureStorage.Load", ex);
            return null;
        }
    }

    public static void Delete(string key)
    {
        try
        {
            var path = Path.Combine(StorageDir, SafeKey(key));
            if (File.Exists(path)) File.Delete(path);
        }
        catch (Exception ex)
        {
            Logger.Error("SecureStorage.Delete", ex);
        }
    }

    private static string SafeKey(string key)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(key));
        return Convert.ToHexString(bytes).ToLowerInvariant() + ".bin";
    }
}

/// <summary>
/// Persists the Supabase session JSON in DPAPI-encrypted storage so the
/// access/refresh tokens never touch disk in plaintext.
/// Mirrors Supabase.DefaultSupabaseSessionHandler but backed by DPAPI.
/// </summary>
public sealed class SecureSessionPersistor : IGotrueSessionPersistence<Session>
{
    private const string SessionKey = "supabase.session";

    public void SaveSession(Session session)
        => SecureStorage.Save(SessionKey, JsonConvert.SerializeObject(session));

    public Session? LoadSession()
    {
        var json = SecureStorage.Load(SessionKey);
        return string.IsNullOrEmpty(json) ? null : JsonConvert.DeserializeObject<Session>(json);
    }

    public void DestroySession()
        => SecureStorage.Delete(SessionKey);
}
