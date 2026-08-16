using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

/// <summary>
/// A chat message. Field names mirror the Flutter Message model
/// (lib/features/messages/domain/models/message.dart).
/// </summary>
public sealed class Message
{
    public string Id { get; set; } = "";
    public string ConversationId { get; set; } = "";
    public string SenderId { get; set; } = "";
    public string SenderName { get; set; } = "";
    public string SenderAvatar { get; set; } = "";
    public string Content { get; set; } = "";
    public bool IsRead { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime? AnyReadAt { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.Now;
    public string MessageType { get; set; } = "text";
    public string? MediaUrl { get; set; }
    public string? MediaThumbnailUrl { get; set; }
    public string? MediaFileName { get; set; }
    public long? MediaFileSize { get; set; }
    public string? MediaMimeType { get; set; }
    public int? VoiceDuration { get; set; }
    public bool IsEphemeral { get; set; }
    public bool IsSpoiler { get; set; }
    public int EphemeralDuration { get; set; } = 86400;
    public string WhisperMode { get; set; } = "OFF";
    public DateTime? ExpiresAt { get; set; }
    public Dictionary<string, object>? EncryptedKeys { get; set; }
    public string? Iv { get; set; }
    public int? SignalMessageType { get; set; }
    public string? SignalSenderContent { get; set; }
    public string? PqAuraHeader { get; set; }
    public string? PqAuraPayload { get; set; }
    public string? ReplyToId { get; set; }
    public string? ReplyToContent { get; set; }
    public string? ReplyToSenderName { get; set; }
    public List<string> Reactions { get; set; } = new();
    public string MediaViewMode { get; set; } = "unlimited";
    public int CurrentUserViewCount { get; set; }

    public bool IsMedia => MessageType is "image" or "video" or "voice" or "document" or "gif" or "sticker";
    public bool IsPqAuraEncrypted => !string.IsNullOrEmpty(PqAuraHeader) && !string.IsNullOrEmpty(PqAuraPayload);

    public static Message FromJson(JsonElement el)
    {
        var msgType = JsonUtil.S(el, "message_type");
        var voiceUrl = JsonUtil.S(el, "voice_url");
        var imageUrl = JsonUtil.S(el, "image_url");
        var fileUrl = JsonUtil.S(el, "file_url");
        var videoUrl = JsonUtil.S(el, "video_url");
        var content = JsonUtil.S(el, "content") ?? "";

        if (string.IsNullOrEmpty(msgType) || msgType == "text")
        {
            if (!string.IsNullOrEmpty(voiceUrl))
                msgType = "voice";
            else if (!string.IsNullOrEmpty(imageUrl))
            {
                if (content == "[STICKER]") msgType = "sticker";
                else if (content == "[GIF]") msgType = "gif";
                else msgType = "image";
            }
            else if (!string.IsNullOrEmpty(videoUrl))
                msgType = "video";
            else if (!string.IsNullOrEmpty(fileUrl))
                msgType = "document";
            else
                msgType = "text";
        }

        return new Message
        {
            Id = JsonUtil.S(el, "id") ?? "",
            ConversationId = JsonUtil.S(el, "conversation_id") ?? "",
            SenderId = JsonUtil.S(el, "sender_id") ?? "",
            SenderName = JsonUtil.S(el, "sender_name")
                         ?? JsonUtil.NestedProfile(el, "sender_profile", "username") ?? "",
            SenderAvatar = JsonUtil.S(el, "sender_avatar")
                           ?? JsonUtil.NestedProfile(el, "sender_profile", "avatar_url") ?? "",
            Content = content,
            IsRead = JsonUtil.B(el, "is_read"),
            ReadAt = JsonUtil.Dt(el, "read_at"),
            AnyReadAt = JsonUtil.Dt(el, "any_read_at"),
            Timestamp = JsonUtil.Dt(el, "created_at") ?? DateTime.Now,
            MessageType = msgType,
            MediaUrl = JsonUtil.S(el, "media_url", "image_url", "video_url", "voice_url", "file_url"),
            MediaThumbnailUrl = JsonUtil.S(el, "media_thumbnail_url"),
            MediaFileName = JsonUtil.S(el, "file_name"),
            MediaFileSize = JsonUtil.S(el, "file_size") is { } sz && long.TryParse(sz, out var fsz) ? fsz : null,
            MediaMimeType = JsonUtil.S(el, "media_mime_type"),
            VoiceDuration = JsonUtil.I(el, "voice_duration"),
            IsEphemeral = JsonUtil.B(el, "is_ephemeral"),
            IsSpoiler = JsonUtil.B(el, "is_spoiler"),
            EphemeralDuration = JsonUtil.I(el, "ephemeral_duration") is var ed && ed > 0 ? ed : 86400,
            WhisperMode = JsonUtil.S(el, "whisper_mode") ?? "OFF",
            ExpiresAt = JsonUtil.Dt(el, "expires_at"),
            Iv = JsonUtil.S(el, "iv"),
            EncryptedKeys = JsonUtil.Dict(el, "encrypted_keys"),
            SignalMessageType = JsonUtil.I(el, "signal_message_type") is var smt && smt != 0 ? smt : (int?)null,
            SignalSenderContent = JsonUtil.S(el, "signal_sender_content"),
            PqAuraHeader = JsonUtil.S(el, "pq_aura_header"),
            PqAuraPayload = JsonUtil.S(el, "pq_aura_payload"),
            ReplyToId = JsonUtil.S(el, "reply_to_id"),
            ReplyToContent = JsonUtil.NestedProfile(el, "reply_to", "content"),
            ReplyToSenderName = JsonUtil.NestedProfile(el, "reply_to", "username"),
            Reactions = JsonUtil.StrList(el, "reactions"),
            MediaViewMode = JsonUtil.S(el, "media_view_mode") ?? "unlimited",
            CurrentUserViewCount = JsonUtil.I(el, "current_user_view_count"),
        };
    }

    public static List<Message> FromJsonArray(string json)
    {
        var result = new List<Message>();
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
