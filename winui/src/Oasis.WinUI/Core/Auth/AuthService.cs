using System.Net;
using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Supabase.Gotrue;
using AuthState = Supabase.Gotrue.Constants.AuthState;
using Provider = Supabase.Gotrue.Constants.Provider;

namespace Oasis.WinUI.Core.Auth;

/// <summary>
/// Auth operations mirroring lib/features/auth/data/datasources/auth_remote_datasource.dart.
/// </summary>
public sealed class AuthService
{
    public static AuthService Current { get; } = new();

    public event Action<AuthState>? AuthStateChanged;

    private AuthService() { }

    public bool IsAuthenticated => SupabaseService.IsInitialized && SupabaseService.Client.Auth.CurrentSession != null;

    public User? CurrentUser => SupabaseService.IsInitialized ? SupabaseService.Client.Auth.CurrentUser : null;
    public Session? CurrentSession => SupabaseService.IsInitialized ? SupabaseService.Client.Auth.CurrentSession : null;

    public void Subscribe()
    {
        if (!SupabaseService.IsInitialized) return;
        SupabaseService.Client.Auth.AddStateChangedListener((_, state) =>
        {
            AuthStateChanged?.Invoke(state);
        });
    }

    private async Task<string?> GetEmailFromUsernameAsync(string username)
    {
        try
        {
            var response = await SupabaseService.Client.Rpc(
                SupabaseConfig.GetEmailByUsernameFn,
                new Dictionary<string, object> { ["p_username"] = username });
            var content = response?.Content;
            if (string.IsNullOrWhiteSpace(content)) return null;
            return content.Trim().Trim('"');
        }
        catch (Exception ex)
        {
            Logger.Warn("AuthService.ResolveUsername", ex.Message);
            return null;
        }
    }

    public async Task<RegisteredAccount> SignInWithEmailAsync(string identifier, string password)
    {
        var email = identifier;

        if (!email.Contains('@'))
        {
            Logger.Info("AuthService", $"Resolving username: {identifier}");
            email = await GetEmailFromUsernameAsync(identifier)
                ?? throw new InvalidOperationException("No user found with this username");
        }

        if (CurrentSession != null)
        {
            try
            {
                await SupabaseService.Client.Auth.SignOut();
            }
            catch (Exception ex)
            {
                Logger.Warn("AuthService.SignIn", $"SignOut of existing session failed (will continue): {ex.Message}");
            }
        }

        var session = await SupabaseService.Client.Auth.SignInWithPassword(email, password);
        Logger.Info("AuthService", $"SignInWithPassword succeeded, session saved automatically by SessionHandler");
        var user = session.User ?? throw new InvalidOperationException("Sign in failed: no user returned");
        if (session.AccessToken is null)
            throw new InvalidOperationException("Sign in failed: no session returned");

        var persistor = new Core.Storage.SecureSessionPersistor();
        persistor.SaveSession(session);

        return RegisteredAccount.From(user, session);
    }

    public async Task<RegisteredAccount> SignUpAsync(string email, string password, string? username = null, string? fullName = null)
    {
        if (CurrentSession != null)
        {
            try
            {
                await SupabaseService.Client.Auth.SignOut();
            }
            catch (Exception ex)
            {
                Logger.Warn("AuthService.SignUp", $"SignOut of existing session failed (will continue): {ex.Message}");
            }
        }

        var metadata = new Dictionary<string, object>
        {
            ["has_accepted_terms"] = true,
            ["accepted_terms_at"] = DateTime.UtcNow.ToString("O"),
        };
        if (username is not null) metadata["username"] = username;
        if (fullName is not null) metadata["full_name"] = fullName;

        var options = new SignUpOptions
        {
            Data = metadata,
            RedirectTo = AppConfig.GetWebUrl("/auth/callback"),
        };

        var session = await SupabaseService.Client.Auth.SignUp(email, password, options);
        var user = session?.User ?? throw new InvalidOperationException("Sign up failed: no user returned");

        if (session is null || session.AccessToken is null)
        {
            throw new InvalidOperationException("Please check your email to verify your account");
        }

        var persistor = new Core.Storage.SecureSessionPersistor();
        persistor.SaveSession(session);

        return RegisteredAccount.From(user, session);
    }

    /// <summary>
    /// Google sign-in using Supabase OAuth (PKCE) with a loopback listener on Windows.
    /// The loopback callback URL must be registered in the Supabase Auth Redirect URLs.
    /// </summary>
    public async Task SignInWithGoogleAsync()
    {
        var redirectUrl = "http://127.0.0.1:37821/auth/callback";

        if (CurrentSession != null)
        {
            try
            {
                await SupabaseService.Client.Auth.SignOut();
            }
            catch (Exception ex)
            {
                Logger.Warn("AuthService.GoogleSignIn", $"SignOut of existing session failed (will continue): {ex.Message}");
            }
        }

        var oauthState = await SupabaseService.Client.Auth.SignIn(
            Provider.Google,
            new SignInOptions
            {
                RedirectTo = redirectUrl,
                FlowType = Supabase.Gotrue.Constants.OAuthFlowType.PKCE,
            });

        var authorizeUri = oauthState?.Uri
            ?? throw new InvalidOperationException("Failed to start Google sign-in");
        var codeVerifier = oauthState?.PKCEVerifier
            ?? throw new InvalidOperationException("Failed to start Google sign-in");

        using var listener = new HttpListener();
        listener.Prefixes.Add("http://127.0.0.1:37821/");
        listener.Start();

        try
        {
            var browser = new System.Diagnostics.Process
            {
                StartInfo = new System.Diagnostics.ProcessStartInfo(authorizeUri.ToString())
                {
                    UseShellExecute = true,
                },
            };
            browser.Start();

            var context = await listener.GetContextAsync();
            var code = context.Request.QueryString["code"];

            var response = context.Response;
            response.ContentType = "text/html";
            var bytes = System.Text.Encoding.UTF8.GetBytes(
                "<html><body><h2>Sign-in complete</h2><p>You can close this window.</p></body></html>");
            await response.OutputStream.WriteAsync(bytes);
            response.Close();

            if (string.IsNullOrEmpty(code))
                throw new InvalidOperationException("Google sign-in was cancelled");

            var session = await SupabaseService.Client.Auth.ExchangeCodeForSession(codeVerifier, code)
                ?? throw new InvalidOperationException("Failed to complete Google sign-in");

            var persistor = new Core.Storage.SecureSessionPersistor();
            persistor.SaveSession(session);
        }
        finally
        {
            listener.Stop();
        }
    }

    public async Task SignOutAsync()
    {
        await SupabaseService.SignOutAsync();
        await Core.Storage.SecureStorage.DeleteAsync("supabase.session");
    }

    public async Task<RegisteredAccount?> RestoreSessionAsync()
    {
        if (!SupabaseService.IsInitialized) return null;

        try
        {
            var session = await SupabaseService.Client.Auth.RetrieveSessionAsync();
            var user = SupabaseService.Client.Auth.CurrentUser;
            Logger.Info("AuthService.Restore", $"RetrieveSessionAsync returned session={session?.AccessToken != null}, user={user?.Id != null}");
            if (session is not null && user is not null)
                return RegisteredAccount.From(user, session);
        }
        catch (Exception ex)
        {
            Logger.Warn("AuthService.RestoreSession", $"RetrieveSessionAsync failed: {ex.Message}");
        }

        var currentSession = SupabaseService.Client.Auth.CurrentSession;
        var currentUser = SupabaseService.Client.Auth.CurrentUser;
        Logger.Info("AuthService.Restore", $"Fallback: CurrentSession={currentSession?.AccessToken != null}, CurrentUser={currentUser?.Id != null}");
        if (currentSession is not null && currentUser is not null)
            return RegisteredAccount.From(currentUser, currentSession);

        var persistor = new Core.Storage.SecureSessionPersistor();
        var loadedSession = persistor.LoadSession();
        Logger.Info("AuthService.Restore", $"SessionHandler direct load: session={loadedSession?.AccessToken != null}");
        if (loadedSession is not null && !string.IsNullOrEmpty(loadedSession.AccessToken) && !string.IsNullOrEmpty(loadedSession.RefreshToken))
        {
            try
            {
                var session = await SupabaseService.Client.Auth.SetSession(loadedSession.AccessToken, loadedSession.RefreshToken);
                var user = SupabaseService.Client.Auth.CurrentUser;
                if (session is not null && user is not null)
                {
                    Logger.Info("AuthService.Restore", "Successfully restored session manually from SecureSessionPersistor.");
                    return RegisteredAccount.From(user, session);
                }
            }
            catch (Exception ex)
            {
                Logger.Warn("AuthService.RestoreSession", $"SetSession failed: {ex.Message}");
            }
        }

        return null;
    }

    public async Task ResetPasswordAsync(string identifier)
    {
        var email = identifier;
        if (!email.Contains('@'))
        {
            email = await GetEmailFromUsernameAsync(identifier)
                ?? throw new InvalidOperationException("No user found with this username");
        }

        try
        {
            await SupabaseService.Client.Auth.ResetPasswordForEmail(email);
        }
        catch
        {
            // Fallback: custom Edge Function (bypasses Supabase rate limits)
            await SendPasswordResetViaEdgeFunctionAsync(email);
        }
    }

    private static async Task SendPasswordResetViaEdgeFunctionAsync(string email)
    {
        using var http = new HttpClient();
        var response = await http.PostAsync(
            $"{AppConfig.SupabaseUrl}/functions/v1/send-password-reset",
            new StringContent(
                System.Text.Json.JsonSerializer.Serialize(new { email }),
                System.Text.Encoding.UTF8,
                "application/json"));
        response.EnsureSuccessStatusCode();
    }
}
