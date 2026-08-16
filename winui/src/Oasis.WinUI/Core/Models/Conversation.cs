using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

/// <summary>
/// A chat conversation. Field names mirror the Flutter Conversation model
/// (lib/features/messages/domain/models/conversation.dart).
/// </summary>
public sealed class Conversation
{
    public string Id { get; set; } = "";
    public string Type { get; set; } = "direct";
    public string Name { get; set; } = "";
    public string OtherUserId { get; set; } = "";
    public string OtherUserName { get; set; } = "";
    public string OtherUserAvatar { get; set; } = "";
    public string ImageUrl { get; set; } = "";
    public long UnreadCount { get; set; }
    public bool IsMuted { get; set; }
    public string LastMessage { get; set; } = "";
    public string LastMessageType { get; set; } = "text";
    public string? LastMessageSenderId { get; set; }
    public DateTime? LastMessageTime { get; set; }
    public DateTime? SortTime { get; set; }
    public string LastPqAuraHeader { get; set; } = "";
    public string LastPqAuraPayload { get; set; } = "";
    public Dictionary<string, object>? LastEncryptedKeys { get; set; }
    public string? LastIv { get; set; }
    public string? LastSignalSenderContent { get; set; }

    public string LastMessagePreview { get; set; } = "";

    public string DisplayName =>
        string.IsNullOrEmpty(OtherUserName) ? "Unknown" : OtherUserName;

    public static Conversation FromJson(JsonElement el)
    {
        return new Conversation
        {
            Id = JsonUtil.S(el, "id") ?? "",
            Type = JsonUtil.S(el, "type") ?? "direct",
            Name = JsonUtil.S(el, "name") ?? "",
            OtherUserId = JsonUtil.S(el, "other_user_id") ?? "",
            OtherUserName = JsonUtil.S(el, "other_user_name") ?? "",
            OtherUserAvatar = JsonUtil.S(el, "other_user_avatar") ?? "",
            ImageUrl = JsonUtil.S(el, "image_url") ?? "",
            UnreadCount = JsonUtil.L(el, "unread_count"),
            IsMuted = JsonUtil.B(el, "is_muted"),
            LastMessage = JsonUtil.S(el, "last_message") ?? "",
            LastMessageType = JsonUtil.S(el, "last_message_type") ?? "text",
            LastMessageSenderId = JsonUtil.S(el, "last_message_sender_id"),
            LastMessageTime = JsonUtil.Dt(el, "last_message_time"),
            SortTime = JsonUtil.Dt(el, "sort_time"),
            LastPqAuraHeader = JsonUtil.S(el, "last_pq_aura_header"),
            LastPqAuraPayload = JsonUtil.S(el, "last_pq_aura_payload"),
            LastEncryptedKeys = JsonUtil.Dict(el, "last_encrypted_keys", "encrypted_keys"),
            LastIv = JsonUtil.S(el, "last_iv", "iv"),
            LastSignalSenderContent = JsonUtil.S(el, "last_signal_sender_content", "signal_sender_content"),
        };
    }

    public static List<Conversation> FromJsonArray(string json)
    {
        var result = new List<Conversation>();
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return result;
            foreach (var el in doc.RootElement.EnumerateArray())
            {
                if (el.ValueKind == JsonValueKind.Object) result.Add(FromJson(el));
            }
        }
        catch
        {
            // ignore
        }
        return result;
    }
}
