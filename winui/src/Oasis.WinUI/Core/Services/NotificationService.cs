using Oasis.WinUI.Core.Config;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Services;
using Supabase.Realtime.Interfaces;
using Supabase.Realtime.PostgresChanges;
using Supabase.Realtime.Socket;

namespace Oasis.WinUI.Core.Services;

/// <summary>
/// Subscribes to the user's notification stream (mirroring
/// lib/services/notification_service.dart) and surfaces incoming DM
/// notifications through the Windows system tray balloon.
/// </summary>
public sealed class NotificationService
{
    public static NotificationService Instance { get; } = new();

    /// <summary>Set to the currently open chat so its messages do not toast.</summary>
    public static string? ActiveConversationId { get; set; }

    /// <summary>Raised when a new DM arrives for a conversation (any conversation).</summary>
    public event EventHandler<string>? DmReceived;

    private IRealtimeChannel? _channel;
    private string _userId = "";

    private NotificationService() { }

    public void Subscribe()
    {
        var userId = SupabaseService.Client.Auth.CurrentUser?.Id ?? "";
        if (userId.Length == 0) return;
        if (userId == _userId && _channel != null) return;
        Unsubscribe();
        _userId = userId;

        try
        {
            var channel = SupabaseService.Client.Realtime.Channel($"notifications:{userId}");
            channel.Register(new PostgresChangesOptions("public", SupabaseConfig.NotificationsTable,
                PostgresChangesOptions.ListenType.All, $"user_id=eq.{userId}", null));
            channel.AddPostgresChangeHandler(PostgresChangesOptions.ListenType.Inserts, (s, change) =>
            {
                if (change.Payload?.Data?.Record is SocketResponsePayload sr &&
                    sr.Record is Dictionary<string, object> record)
                {
                    _ = Task.Run(() => HandleNotificationAsync(record));
                }
            });
            _ = channel.Subscribe();
            _channel = channel;
            Logger.Info("Notifications.Subscribe", $"Listening for user {userId}");
        }
        catch (Exception ex)
        {
            Logger.Warn("Notifications.Subscribe", ex.Message);
        }
    }

    public void Unsubscribe()
    {
        try
        {
            _channel?.Unsubscribe();
        }
        catch (Exception ex)
        {
            Logger.Warn("Notifications.Unsubscribe", ex.Message);
        }
        _channel = null;
        _userId = "";
    }

    /// <summary>Lets consumers refresh when a message lands in an already-open chat.</summary>
    public void NotifyMessageArrived(string conversationId)
        => DmReceived?.Invoke(this, conversationId);

    private static Task HandleNotificationAsync(Dictionary<string, object> record)
    {
        try
        {
            if (Get(record, "type") != "dm") return Task.CompletedTask;
            var conversationId = Get(record, "conversation_id");
            if (string.IsNullOrEmpty(conversationId)) return Task.CompletedTask;
            if (conversationId == ActiveConversationId) return Task.CompletedTask;

            var title = Get(record, "title");
            if (string.IsNullOrEmpty(title)) title = "New message";

            App.MainWindowInstance?.ShowSystemNotification(title, BuildBody(Get(record, "content")));
            Instance.DmReceived?.Invoke(Instance, conversationId);
        }
        catch (Exception ex)
        {
            Logger.Warn("Notifications.Handle", ex.Message);
        }
        return Task.CompletedTask;
    }

    private static string BuildBody(string? content)
    {
        if (string.IsNullOrEmpty(content)) return "New message";
        if (content.Length > 40 && !content.Contains(' ')) return "New message";
        return content;
    }

    public async Task<List<NotificationsRow>> GetNotificationsAsync(int limit = 50)
    {
        var userId = SupabaseService.Client.Auth.CurrentUser?.Id ?? "";
        if (string.IsNullOrEmpty(userId)) return new List<NotificationsRow>();

        try
        {
            var response = await SupabaseService.Client.From<NotificationsRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(limit)
                .Get();

            return response?.Models ?? new List<NotificationsRow>();
        }
        catch (Exception ex)
        {
            Logger.Warn("Notifications.Get", ex.Message);
            return new List<NotificationsRow>();
        }
    }

    public async Task MarkAsReadAsync(string notificationId)
    {
        try
        {
            await SupabaseService.Client.From<NotificationsRow>()
                .Where(n => n.Id == notificationId)
                .Set(n => n.IsRead, true)
                .Update();
        }
        catch (Exception ex)
        {
            Logger.Warn("Notifications.MarkRead", ex.Message);
        }
    }

    private static string? Get(Dictionary<string, object> record, string key)
        => record.TryGetValue(key, out var value) ? value?.ToString() : null;
}
