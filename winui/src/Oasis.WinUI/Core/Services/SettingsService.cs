using System.Text.Json;
using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Supabase.Gotrue;

namespace Oasis.WinUI.Core.Services;

public sealed class SettingsException(string message) : Exception(message);

/// <summary>
/// Settings operations mirroring lib/services/auth/profile_manager.dart and
/// lib/services/auth_service.dart (updateProfile / updatePassword /
/// deleteAccount / uploadProfilePicture).
/// </summary>
public sealed class SettingsService
{
    private static string CurrentUserId
        => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public async Task<Profile?> GetProfileAsync()
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) return null;

        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("*")
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content) || response.Content == "[]") return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            return Profile.FromJson(doc.RootElement[0]);
        }
        catch (Exception ex)
        {
            Logger.Warn("Settings.GetProfile", ex.Message);
            return null;
        }
    }

    public async Task UpdateProfileAsync(string? username = null, string? displayName = null, string? avatarUrl = null)
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) throw new SettingsException("Not authenticated");

        var updates = new Dictionary<string, object?>();

        if (username != null)
        {
            if (await UsernameTakenAsync(username, userId))
                throw new SettingsException("Username is already taken");
            updates["username"] = username;
        }

        if (displayName != null) updates["full_name"] = displayName;
        if (avatarUrl != null) updates["avatar_url"] = avatarUrl;

        if (updates.Count == 0) return;

        await SupabaseService.Client.From<ProfilesRow>()
            .Filter("id", Postgrest.Constants.Operator.Equals, userId)
            .Update(new ProfilesRow
            {
                Username = username,
                FullName = displayName,
                AvatarUrl = avatarUrl,
            });

        var metadata = new Dictionary<string, object?>
        {
            ["username"] = username ?? SupabaseService.Client.Auth.CurrentUser?.UserMetadata?["username"],
            ["full_name"] = displayName ?? SupabaseService.Client.Auth.CurrentUser?.UserMetadata?["full_name"],
            ["avatar_url"] = avatarUrl ?? SupabaseService.Client.Auth.CurrentUser?.UserMetadata?["avatar_url"],
        };

        try
        {
            await SupabaseService.Client.Auth.Update(new UserAttributes { Data = metadata });
        }
        catch (Exception ex)
        {
            Logger.Warn("Settings.UpdateAuthMetadata", ex.Message);
        }
    }

    public async Task UpdatePasswordAsync(string newPassword)
    {
        try
        {
            await SupabaseService.Client.Auth.Update(new UserAttributes { Password = newPassword });
        }
        catch (Exception ex)
        {
            throw new SettingsException($"Failed to update password: {ex.Message}");
        }
    }

    public async Task SendPasswordResetAsync(string email)
    {
        try
        {
            await SupabaseService.Client.Auth.ResetPasswordForEmail(email);
        }
        catch (Exception ex)
        {
            throw new SettingsException($"Failed to send reset email: {ex.Message}");
        }
    }

    /// <summary>
    /// Uploads a profile picture to the profile-pictures bucket and updates
    /// the profile avatar. Returns the public URL.
    /// </summary>
    public async Task<string> UploadProfilePictureAsync(string filePath)
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) throw new SettingsException("Not authenticated");

        var extension = System.IO.Path.GetExtension(filePath).TrimStart('.');
        if (extension.Length == 0) extension = "png";
        var fileName = $"{DateTime.Now:yyyy-MM-ddTHH:mm:ss.fffZ}.{extension}";
        var path = $"profiles/{userId}/{fileName}";
        var data = await File.ReadAllBytesAsync(filePath);

        var bucket = SupabaseService.Client.Storage.From(SupabaseConfig.ProfilePicturesBucket);
        await bucket.Upload(data, path, new Supabase.Storage.FileOptions { ContentType = $"image/{extension}", Upsert = true });

        var publicUrl = $"{AppConfig.SupabaseUrl}/storage/v1/object/public/{SupabaseConfig.ProfilePicturesBucket}/{path}";

        await UpdateProfileAsync(avatarUrl: publicUrl);
        return publicUrl;
    }

    /// <summary>Deletes the account via the delete_user_account RPC, falling back to direct deletion.</summary>
    public async Task DeleteAccountAsync()
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) throw new SettingsException("Not authenticated");

        try
        {
            await SupabaseService.Client.Rpc("delete_user_account", new Dictionary<string, object?>());
        }
        catch (Exception ex)
        {
            Logger.Warn("Settings.DeleteRpc", ex.Message);
            try
            {
                await SupabaseService.Client.From<ProfilesRow>()
                    .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                    .Delete();
            }
            catch (Exception delEx)
            {
                throw new SettingsException($"Account deletion failed: {delEx.Message}");
            }
        }

        try
        {
            await SupabaseService.Client.Auth.SignOut();
        }
        catch (Exception ex)
        {
            Logger.Warn("Settings.SignOutAfterDelete", ex.Message);
        }
    }

    // ------------------------------------------------------------------

    private static async Task<bool> UsernameTakenAsync(string username, string excludeUserId)
    {
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("id")
                .Filter("username", Postgrest.Constants.Operator.Equals, username)
                .Not("id", Postgrest.Constants.Operator.Equals, excludeUserId)
                .Limit(1)
                .Get();

            return !string.IsNullOrWhiteSpace(response?.Content) && response.Content != "[]";
        }
        catch (Exception ex)
        {
            Logger.Warn("Settings.UsernameCheck", ex.Message);
            return false;
        }
    }
}
