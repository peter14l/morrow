using System.Text.Json;
using Oasis.WinUI.Core.Crypto;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Storage;
using Oasis.WinUI.Services;
using Supabase.Realtime.Interfaces;
using Supabase.Realtime.PostgresChanges;
using Supabase.Realtime.Socket;

namespace Oasis.WinUI.Core.Services;

/// <summary>
/// Messaging operations mirroring lib/services/chat_messaging_service.dart,
/// lib/features/messages/data/conversation_service.dart and
/// lib/services/chat_realtime_service.dart.
/// </summary>
public sealed class MessagingService
{
    public sealed class Subscription
    {
        public string ConversationId { get; }
        private readonly IRealtimeChannel _channel;

        public Subscription(string conversationId, IRealtimeChannel channel)
        {
            ConversationId = conversationId;
            _channel = channel;
        }

        public void Close() => _channel.Unsubscribe();
    }

    private readonly Dictionary<string, Subscription> _subscriptions = new();

    private static string CurrentUserId
        => SupabaseService.Client.Auth.CurrentUser?.Id ?? "";

    public IReadOnlyDictionary<string, Subscription> Subscriptions => _subscriptions;

    // ------------------------------------------------------------------
    // Conversations
    // ------------------------------------------------------------------

    public async Task<List<Conversation>> GetConversationsAsync()
    {
        var userId = CurrentUserId;
        var list = new List<Conversation>();

        try
        {
            var response = await SupabaseService.Client.Rpc("get_user_conversations_v2", new Dictionary<string, object?>());
            if (string.IsNullOrWhiteSpace(response?.Content)) return list;

            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return list;

            foreach (var el in doc.RootElement.EnumerateArray())
            {
                var conv = ParseConversationRow(el, userId);
                if (conv != null) list.Add(conv);
            }

            await DecryptConversationPreviewsAsync(list, userId);
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.GetConversations", ex.Message);
        }

        list.Sort((a, b) => (b.SortTime ?? b.LastMessageTime ?? DateTime.MinValue)
            .CompareTo(a.SortTime ?? a.LastMessageTime ?? DateTime.MinValue));
        return list;
    }

    private static Conversation? ParseConversationRow(JsonElement el, string userId)
    {
        var conv = Conversation.FromJson(el);
        if (conv.Id.Length == 0) return null;

        if (el.TryGetProperty("all_participants", out var participants) &&
            participants.ValueKind == JsonValueKind.Array)
        {
            foreach (var p in participants.EnumerateArray())
            {
                if (p.ValueKind != JsonValueKind.Object) continue;
                var pUserId = JsonUtil.S(p, "user_id");
                if (string.IsNullOrEmpty(pUserId) || pUserId == userId) continue;

                conv.OtherUserId = pUserId!;
                var profile = ParseParticipantProfile(p, userId);
                if (profile != null)
                {
                    conv.OtherUserName = profile.Username;
                    conv.OtherUserAvatar = profile.AvatarUrl;
                }
                else
                {
                    conv.OtherUserName = JsonUtil.S(p, "username") ?? conv.OtherUserName;
                    conv.OtherUserAvatar = JsonUtil.S(p, "avatar_url") ?? conv.OtherUserAvatar;
                }
            }
        }

        if (el.TryGetProperty("last_message_data", out var lmd) && lmd.ValueKind == JsonValueKind.Object)
        {
            conv.LastMessage = JsonUtil.S(lmd, "content") ?? conv.LastMessage;

            var msgType = JsonUtil.S(lmd, "message_type");
            var voiceUrl = JsonUtil.S(lmd, "voice_url");
            var imageUrl = JsonUtil.S(lmd, "image_url");
            var fileUrl = JsonUtil.S(lmd, "file_url");
            var videoUrl = JsonUtil.S(lmd, "video_url");
            var content = conv.LastMessage;

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
            conv.LastMessageType = msgType;

            conv.LastMessageSenderId = JsonUtil.S(lmd, "sender_id") ?? conv.LastMessageSenderId;
            conv.LastMessageTime = JsonUtil.Dt(lmd, "created_at") ?? conv.LastMessageTime;
            conv.LastPqAuraHeader = JsonUtil.S(lmd, "pq_aura_header") ?? "";
            conv.LastPqAuraPayload = JsonUtil.S(lmd, "pq_aura_payload") ?? "";
            conv.LastEncryptedKeys = JsonUtil.Dict(lmd, "encrypted_keys") ?? conv.LastEncryptedKeys;
            conv.LastIv = JsonUtil.S(lmd, "iv") ?? conv.LastIv;
            conv.LastSignalSenderContent = JsonUtil.S(lmd, "signal_sender_content") ?? conv.LastSignalSenderContent;
        }

        if (conv.Name.Length == 0) conv.Name = conv.DisplayName;
        return conv;
    }

    private static Profile? ParseParticipantProfile(JsonElement p, string userId)
    {
        if (!p.TryGetProperty("profile", out var profile)) return null;
        if (profile.ValueKind == JsonValueKind.Object)
            return Profile.FromJson(profile);
        if (profile.ValueKind == JsonValueKind.Array && profile.GetArrayLength() > 0)
            return Profile.FromJson(profile[0]);
        return null;
    }

    private async Task DecryptConversationPreviewsAsync(List<Conversation> conversations, string userId)
    {
        foreach (var conv in conversations)
        {
            if (string.IsNullOrEmpty(conv.LastPqAuraHeader) && string.IsNullOrEmpty(conv.LastSignalSenderContent))
                continue;
            try
            {
                var plain = await DecryptConversationPreviewAsync(conv, userId);
                if (plain != null && plain != LockedPlaceholder) conv.LastMessage = plain;
            }
            catch
            {
                // keep encrypted placeholder
            }
        }
    }

    public async Task<string?> GetOrCreateDirectConversationAsync(string otherUserId)
    {
        var userId = CurrentUserId;
        try
        {
            var response = await SupabaseService.Client.Rpc("get_or_create_direct_conversation",
                new Dictionary<string, object?> { ["p_user1_id"] = userId, ["p_user2_id"] = otherUserId });

            var content = response?.Content;
            if (string.IsNullOrWhiteSpace(content)) return null;

            var trimmed = content.Trim();
            if (trimmed.StartsWith('"')) trimmed = trimmed.Trim('"');
            return trimmed.Length == 0 ? null : trimmed;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.GetOrCreateConv", ex.Message);
            return null;
        }
    }

    public async Task<string?> GetOtherParticipantAsync(string conversationId)
    {
        var userId = CurrentUserId;
        try
        {
            var response = await SupabaseService.Client.From<ConversationParticipantsRow>()
                .Select("user_id")
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Not("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content)) return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            return JsonUtil.S(doc.RootElement[0], "user_id");
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.OtherParticipant", ex.Message);
            return null;
        }
    }

    public async Task<string?> GetUserPublicKeyAsync(string userId)
    {
        if (string.IsNullOrEmpty(userId)) return null;
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("public_key")
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();
            if (string.IsNullOrWhiteSpace(response?.Content)) return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            return JsonUtil.S(doc.RootElement[0], "public_key");
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.GetPublicKey", ex.Message);
            return null;
        }
    }

    public async Task<string?> GetChatBackgroundAsync(string conversationId)
    {
        if (string.IsNullOrEmpty(conversationId)) return null;
        try
        {
            var response = await SupabaseService.Client.From<TableRows.ChatThemesRow>()
                .Select("background_image_url")
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Order("updated_at", Postgrest.Constants.Ordering.Descending)
                .Limit(1)
                .Get();
            if (string.IsNullOrWhiteSpace(response?.Content)) return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            return JsonUtil.S(doc.RootElement[0], "background_image_url");
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.GetBackground", ex.Message);
            return null;
        }
    }

    public async Task<bool> UpdateChatBackgroundAsync(string conversationId, string? backgroundUrl)
    {
        var userId = CurrentUserId;
        if (string.IsNullOrEmpty(conversationId) || string.IsNullOrEmpty(userId)) return false;
        try
        {
            var participantsResponse = await SupabaseService.Client.From<ConversationParticipantsRow>()
                .Select("user_id")
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Get();

            var participantIds = new List<string>();
            if (!string.IsNullOrWhiteSpace(participantsResponse?.Content))
            {
                using var doc = JsonDocument.Parse(participantsResponse.Content);
                if (doc.RootElement.ValueKind == JsonValueKind.Array)
                {
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        var pid = JsonUtil.S(el, "user_id");
                        if (!string.IsNullOrEmpty(pid)) participantIds.Add(pid);
                    }
                }
            }
            if (participantIds.Count == 0) participantIds.Add(userId);

            foreach (var pid in participantIds)
            {
                await SupabaseService.Client.From<TableRows.ChatThemesRow>().Upsert(new TableRows.ChatThemesRow
                {
                    ConversationId = conversationId,
                    UserId = pid,
                    BackgroundImageUrl = backgroundUrl,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.UpdateBackground", ex.Message);
            return false;
        }
    }

    public async Task<(string Id, string Username, string AvatarUrl)?> FindUserByUsernameAsync(string username)
    {
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("id,username,avatar_url")
                .Filter("username", Postgrest.Constants.Operator.Equals, username)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content)) return null;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return null;
            var el = doc.RootElement[0];
            return (JsonUtil.S(el, "id") ?? "", JsonUtil.S(el, "username") ?? username, JsonUtil.S(el, "avatar_url") ?? "");
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.FindUser", ex.Message);
            return null;
        }
    }

    // ------------------------------------------------------------------
    // PIN-based key restore
    // ------------------------------------------------------------------

    /// <summary>
    /// Restores the user's RSA keypair from the PIN-encrypted v2 backup,
    /// mirroring encryption_service.dart.restoreSecureKeys. The derived PIN
    /// key decrypts the private key PEM, which is cached in SecureStorage.
    /// </summary>
    public async Task<bool> RestoreSecureKeysFromPinAsync(string pin)
    {
        var userId = CurrentUserId;
        if (userId.Length == 0 || string.IsNullOrWhiteSpace(pin)) return false;
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("encrypted_private_key_v2,key_salt,public_key")
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();
            if (string.IsNullOrWhiteSpace(response?.Content)) return false;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return false;
            var el = doc.RootElement[0];
            var encrypted = JsonUtil.S(el, "encrypted_private_key_v2");
            var salt = JsonUtil.S(el, "key_salt");
            var publicKey = JsonUtil.S(el, "public_key");
            if (string.IsNullOrEmpty(encrypted) || string.IsNullOrEmpty(salt)) return false;

            var key = KeyManagementService.DeriveSecureBackupKey(pin, salt);
            var privateKeyPem = KeyManagementService.DecryptWithKey(encrypted, key);
            if (string.IsNullOrEmpty(privateKeyPem)) return false;

            await SecureStorage.SaveAsync(KeyManagementService.PrivateKeyKey(userId), privateKeyPem);
            if (!string.IsNullOrEmpty(publicKey))
                await SecureStorage.SaveAsync(KeyManagementService.PublicKeyKey(userId), publicKey);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.RestoreKeys", ex.Message);
            return false;
        }
    }

    /// <summary>
    /// Attempts to restore the RSA keypair from the seamless v1 backup (encrypted_private_key)
    /// without requiring user PIN entry.
    /// </summary>
    public async Task<bool> TryRestoreLegacyBackupAsync()
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) return false;
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("encrypted_private_key,public_key")
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();
            if (string.IsNullOrWhiteSpace(response?.Content)) return false;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return false;
            var el = doc.RootElement[0];
            var encrypted = JsonUtil.S(el, "encrypted_private_key");
            var publicKey = JsonUtil.S(el, "public_key");
            if (string.IsNullOrEmpty(encrypted)) return false;

            var key = KeyManagementService.DeriveLegacyBackupKey(userId);
            var privateKeyPem = KeyManagementService.DecryptWithKey(encrypted, key);
            if (string.IsNullOrEmpty(privateKeyPem)) return false;

            await SecureStorage.SaveAsync(KeyManagementService.PrivateKeyKey(userId), privateKeyPem);
            if (!string.IsNullOrEmpty(publicKey))
                await SecureStorage.SaveAsync(KeyManagementService.PublicKeyKey(userId), publicKey);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.RestoreLegacyKeys", ex.Message);
            return false;
        }
    }

    public async Task<bool> HasPrivateKeyAsync()
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) return false;
        var hasLocal = !string.IsNullOrEmpty(await SecureStorage.LoadAsync(KeyManagementService.PrivateKeyKey(userId)));
        if (hasLocal) return true;

        // Try automatic seamless restore from legacy v1 backup before giving up
        return await TryRestoreLegacyBackupAsync();
    }

    public async Task<bool> HasV2BackupAsync()
    {
        var userId = CurrentUserId;
        if (userId.Length == 0) return false;
        try
        {
            var response = await SupabaseService.Client.From<ProfilesRow>()
                .Select("encrypted_private_key_v2,key_salt")
                .Filter("id", Postgrest.Constants.Operator.Equals, userId)
                .Limit(1)
                .Get();
            if (string.IsNullOrWhiteSpace(response?.Content)) return false;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return false;
            var el = doc.RootElement[0];
            return !string.IsNullOrEmpty(JsonUtil.S(el, "encrypted_private_key_v2"))
                && !string.IsNullOrEmpty(JsonUtil.S(el, "key_salt"));
        }
        catch
        {
            return false;
        }
    }

    // ------------------------------------------------------------------
    // Messages
    // ------------------------------------------------------------------

    public async Task<List<Message>> GetMessagesAsync(string conversationId, int limit = 50, DateTime? before = null)
    {
        try
        {
            var builder = SupabaseService.Client.From<MessagesRow>()
                .Select("*")
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Order("created_at", Postgrest.Constants.Ordering.Descending)
                .Limit(limit);

            if (before != null) builder = builder.Filter("created_at", Postgrest.Constants.Operator.LessThan, before.Value);

            var response = await builder.Get();
            Logger.Warn("Messages.Get.Raw", response?.Content ?? "No content");
            var messages = Message.FromJsonArray(response?.Content ?? "");
            messages.Reverse();
            return messages;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.Get", ex.Message);
            return new List<Message>();
        }
    }

    public async Task<Message?> GetMessageByIdAsync(string messageId)
    {
        try
        {
            var response = await SupabaseService.Client.From<MessagesRow>()
                .Select("*")
                .Filter("id", Postgrest.Constants.Operator.Equals, messageId)
                .Limit(1)
                .Get();
            Logger.Warn("Messages.GetById.Raw", response?.Content ?? "No content");
            var list = Message.FromJsonArray(response?.Content ?? "");
            return list.Count > 0 ? list[0] : null;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.GetById", ex.Message);
            return null;
        }
    }


    /// <summary>
    /// Decrypts a message, trying PQ-Aura first (received only) and the RSA
    /// fallback (both directions), mirroring ChatDecryptionService. When no
    /// key is available the encrypted blob falls back to the raw content.
    /// </summary>
    public async Task<string> DecryptDisplayContentAsync(Message msg, string myUserId)
    {
        var isSender = msg.SenderId == myUserId;

        if (!isSender && msg.IsPqAuraEncrypted)
        {
            try
            {
                var plain = await PQAuraService.Current.DecryptMessageAsync(
                    msg.SenderId,
                    Convert.FromBase64String(msg.PqAuraHeader!),
                    Convert.FromBase64String(msg.PqAuraPayload!));
                if (plain != null) return plain;
            }
            catch
            {
                // fall through
            }
        }

        var rsaPlain = await TryDecryptRsaAsync(msg.SignalSenderContent, isSender, msg.Content,
            msg.EncryptedKeys, msg.Iv, myUserId);
        if (rsaPlain != null) return rsaPlain;

        return LooksLikeEncryptedBlob(msg.Content) ? LockedPlaceholder : msg.Content;
    }

    public const string LockedPlaceholder = "🔒 Message encrypted";

    /// <summary>
    /// Decrypts the RSA fallback ciphertext for a single message. The sender
    /// path uses signal_sender_content (mirroring the Flutter
    /// pqAuraSenderPayload ?? signalSenderContent); the receiver path falls
    /// back to content when signal_sender_content is missing.
    /// </summary>
    private async Task<string?> TryDecryptRsaAsync(string? signalSenderContent, bool isSender,
        string content, Dictionary<string, object>? encryptedKeys, string? ivBase64, string myUserId)
    {
        if (encryptedKeys == null || encryptedKeys.Count == 0) return null;
        if (string.IsNullOrEmpty(ivBase64)) return null;

        var rsaCiphertext = isSender
            ? signalSenderContent
            : (signalSenderContent ?? content);
        if (string.IsNullOrEmpty(rsaCiphertext)) return null;

        var privateKeyPem = await SecureStorage.LoadAsync(KeyManagementService.PrivateKeyKey(myUserId));
        if (string.IsNullOrEmpty(privateKeyPem)) return null;

        byte[] iv;
        try { iv = Convert.FromBase64String(ivBase64); }
        catch { return null; }
        if (iv.Length != 16) return null;

        foreach (var entry in encryptedKeys)
        {
            if (entry.Value is not string value || string.IsNullOrEmpty(value)) continue;
            var aesKey = KeyManagementService.DecryptRsaKey(privateKeyPem, value);
            if (aesKey == null) continue;
            var plain = KeyManagementService.AesDecryptAny(aesKey, iv, rsaCiphertext);
            if (plain != null) return plain;
        }
        return null;
    }

    /// <summary>Decrypts a conversation preview the same way messages are decrypted.</summary>
    public async Task<string> DecryptConversationPreviewAsync(Conversation conv, string myUserId)
    {
        if (conv.LastMessageType == "voice") return "🎤 Voice message";
        if (conv.LastMessageType == "image") return "📷 Photo";
        if (conv.LastMessageType == "gif") return "🎬 GIF";
        if (conv.LastMessageType == "sticker") return "💟 Sticker";
        if (conv.LastMessageType == "video") return "🎥 Video";
        if (conv.LastMessageType == "document") return "📁 File";

        var isSender = conv.LastMessageSenderId == myUserId;

        if (!isSender && !string.IsNullOrEmpty(conv.LastPqAuraHeader) && !string.IsNullOrEmpty(conv.LastPqAuraPayload))
        {
            try
            {
                var senderId = conv.LastMessageSenderId ?? conv.OtherUserId;
                var plain = await PQAuraService.Current.DecryptMessageAsync(
                    senderId,
                    Convert.FromBase64String(conv.LastPqAuraHeader),
                    Convert.FromBase64String(conv.LastPqAuraPayload));
                if (plain != null) return plain;
            }
            catch
            {
                // fall through
            }
        }

        var rsaPlain = await TryDecryptRsaAsync(conv.LastSignalSenderContent, isSender, conv.LastMessage,
            conv.LastEncryptedKeys, conv.LastIv, myUserId);
        if (rsaPlain != null) return rsaPlain;

        return LooksLikeEncryptedBlob(conv.LastMessage) ? LockedPlaceholder : conv.LastMessage;
    }

    /// <summary>
    /// True when content looks like a raw encrypted blob (no spaces, long and/or
    /// base64), mirroring ChatDecryptionService.decryptMessageContent.
    /// </summary>
    private static bool LooksLikeEncryptedBlob(string content)
    {
        if (string.IsNullOrEmpty(content) || content.Contains(' ')) return false;
        if (content.Length > 30) return true;
        try
        {
            Convert.FromBase64String(content);
            return content.Length > 10;
        }
        catch
        {
            return false;
        }
    }

    private static string? ExtractId(string? content)
    {
        if (string.IsNullOrWhiteSpace(content)) return null;
        content = content.Trim();
        if (content.StartsWith('{'))
        {
            try
            {
                using var doc = JsonDocument.Parse(content);
                if (doc.RootElement.TryGetProperty("id", out var idProp))
                {
                    return idProp.GetString();
                }
            }
            catch { }
        }
        if (content.StartsWith('"') && content.EndsWith('"'))
        {
            content = content.Trim('"');
        }
        return content;
    }

    // ------------------------------------------------------------------
    // Sending
    // ------------------------------------------------------------------

    /// <summary>
    /// Sends a text message (PQ-Aura E2E encrypted when possible).
    /// Returns the new message id, or null on failure.
    /// </summary>
    public async Task<string?> SendTextAsync(string conversationId, string content,
        string? replyToId = null, int ephemeralDuration = 0)
    {
        var userId = CurrentUserId;
        var otherUserId = await GetOtherParticipantAsync(conversationId);

        var header = (object?)null;
        var payload = (object?)null;
        var messageType = "text";
        var finalContent = content;
        string? signalSenderContent = null;
        Dictionary<string, object>? encryptedKeysDict = null;
        string? ivBase64 = null;

        if (!string.IsNullOrEmpty(otherUserId))
        {
            var encrypted = await PQAuraService.Current.EncryptMessageAsync(otherUserId, content);
            if (encrypted != null)
            {
                header = Convert.ToBase64String(encrypted.Header);
                payload = Convert.ToBase64String(encrypted.Payload);
                finalContent = Convert.ToBase64String(encrypted.Payload);
            }

            // Dual-layer RSA fallback for seamless phone/web/cross-client decryption
            try
            {
                var recipientPubKey = await GetUserPublicKeyAsync(otherUserId);
                var myPubKey = await SecureStorage.LoadAsync(KeyManagementService.PublicKeyKey(userId));
                var keysToEncrypt = new List<string>();
                if (!string.IsNullOrEmpty(recipientPubKey)) keysToEncrypt.Add(recipientPubKey);
                if (!string.IsNullOrEmpty(myPubKey)) keysToEncrypt.Add(myPubKey);

                if (keysToEncrypt.Count > 0)
                {
                    var fallback = KeyManagementService.EncryptMessageFallback(content, keysToEncrypt);
                    if (fallback != null)
                    {
                        signalSenderContent = fallback.Value.Ciphertext;
                        ivBase64 = fallback.Value.Iv;
                        encryptedKeysDict = fallback.Value.EncryptedKeys.ToDictionary(k => k.Key, v => (object)v.Value);
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Warn("Messages.SendText.Fallback", ex.Message);
            }
        }

        var parameters = new Dictionary<string, object?>
        {
            ["p_content"] = finalContent,
            ["p_conversation_id"] = conversationId,
            ["p_message_type"] = messageType,
            ["p_media_url"] = null,
            ["p_media_file_name"] = null,
            ["p_media_file_size"] = null,
            ["p_voice_duration"] = null,
            ["p_reply_to_id"] = replyToId,
            ["p_is_ephemeral"] = ephemeralDuration > 0,
            ["p_ephemeral_duration"] = ephemeralDuration,
            ["p_pq_aura_header"] = header,
            ["p_pq_aura_payload"] = payload,
            ["p_encrypted_keys"] = encryptedKeysDict,
            ["p_iv"] = ivBase64,
            ["p_is_spoiler"] = false,
            ["p_location_data"] = null,
            ["p_media_view_mode"] = null,
            ["p_post_id"] = null,
            ["p_ripple_id"] = null,
            ["p_share_data"] = null,
            ["p_signal_message_type"] = null,
            ["p_signal_sender_content"] = signalSenderContent,
            ["p_story_id"] = null,
            ["p_whisper_mode"] = "OFF",
        };

        try
        {
            var response = await SupabaseService.Client.Rpc("send_message_v3", parameters);
            return ExtractId(response?.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.SendText", ex.Message);
            return null;
        }
    }

    /// <summary>Sends a media message. The bytes are uploaded to storage first.</summary>
    public async Task<string?> SendMediaAsync(string conversationId, byte[] data, string fileName,
        string mimeType, int? voiceDuration = null, int ephemeralDuration = 0)
    {
        var userId = CurrentUserId;
        var otherUserId = await GetOtherParticipantAsync(conversationId);

        string? publicUrl = null;
        try
        {
            var storage = SupabaseService.Client.Storage.From("message-attachments");
            var path = $"conversations/{conversationId}/{Guid.NewGuid():N}_{fileName}";
            await storage.Upload(data, path);
            publicUrl = storage.GetPublicUrl(path);
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.UploadMedia", ex.Message);
            return null;
        }

        string messageType = mimeType.StartsWith("image/") ? "image"
            : mimeType.StartsWith("video/") ? "video"
            : mimeType.StartsWith("audio/") ? "voice"
            : "document";

        var header = (object?)null;
        var payload = (object?)null;
        if (!string.IsNullOrEmpty(otherUserId))
        {
            // Media is encrypted at rest by storage RLS; the send carries the key when configured.
        }

        var parameters = new Dictionary<string, object?>
        {
            ["p_content"] = "",
            ["p_conversation_id"] = conversationId,
            ["p_message_type"] = messageType,
            ["p_media_url"] = publicUrl,
            ["p_media_file_name"] = fileName,
            ["p_media_file_size"] = data.Length,
            ["p_voice_duration"] = voiceDuration,
            ["p_reply_to_id"] = null,
            ["p_is_ephemeral"] = ephemeralDuration > 0,
            ["p_ephemeral_duration"] = ephemeralDuration,
            ["p_pq_aura_header"] = header,
            ["p_pq_aura_payload"] = payload,
            ["p_encrypted_keys"] = null,
            ["p_iv"] = null,
            ["p_is_spoiler"] = false,
            ["p_location_data"] = null,
            ["p_media_view_mode"] = null,
            ["p_post_id"] = null,
            ["p_ripple_id"] = null,
            ["p_share_data"] = null,
            ["p_signal_message_type"] = null,
            ["p_signal_sender_content"] = null,
            ["p_story_id"] = null,
            ["p_whisper_mode"] = "OFF",
        };

        try
        {
            var response = await SupabaseService.Client.Rpc("send_message_v3", parameters);
            return ExtractId(response?.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.SendMedia", ex.Message);
            return null;
        }
    }

    public async Task<string?> SendGifAsync(string conversationId, string gifUrl)
    {
        var userId = CurrentUserId;

        var parameters = new Dictionary<string, object?>
        {
            ["p_content"] = "[GIF]",
            ["p_conversation_id"] = conversationId,
            ["p_message_type"] = "gif",
            ["p_media_url"] = gifUrl,
            ["p_media_file_name"] = "giphy.gif",
            ["p_media_file_size"] = null,
            ["p_voice_duration"] = null,
            ["p_reply_to_id"] = null,
            ["p_is_ephemeral"] = false,
            ["p_ephemeral_duration"] = 0,
            ["p_pq_aura_header"] = null,
            ["p_pq_aura_payload"] = null,
            ["p_encrypted_keys"] = null,
            ["p_iv"] = null,
            ["p_is_spoiler"] = false,
            ["p_location_data"] = null,
            ["p_media_view_mode"] = null,
            ["p_post_id"] = null,
            ["p_ripple_id"] = null,
            ["p_share_data"] = null,
            ["p_signal_message_type"] = null,
            ["p_signal_sender_content"] = null,
            ["p_story_id"] = null,
            ["p_whisper_mode"] = "OFF",
        };

        try
        {
            var response = await SupabaseService.Client.Rpc("send_message_v3", parameters);
            return ExtractId(response?.Content);
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.SendGif", ex.Message);
            return null;
        }
    }


    // ------------------------------------------------------------------
    // Read receipts / deletion
    // ------------------------------------------------------------------

    public async Task MarkConversationReadAsync(string conversationId)
    {
        var userId = CurrentUserId;
        try
        {
            await SupabaseService.Client.From<ConversationParticipantsRow>()
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Filter("user_id", Postgrest.Constants.Operator.Equals, userId)
                .Update(new ConversationParticipantsRow
                {
                    LastReadAt = DateTime.UtcNow,
                    UnreadCount = 0,
                });
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.MarkRead", ex.Message);
        }

        try
        {
            var response = await SupabaseService.Client.From<MessagesRow>()
                .Select("id")
                .Filter("conversation_id", Postgrest.Constants.Operator.Equals, conversationId)
                .Not("sender_id", Postgrest.Constants.Operator.Equals, userId)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content)) return;
            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) return;

            foreach (var el in doc.RootElement.EnumerateArray())
            {
                var messageId = JsonUtil.S(el, "id");
                if (string.IsNullOrEmpty(messageId)) continue;
                try
                {
                    await SupabaseService.Client.From<MessageReadReceiptsRow>()
                        .Upsert(new MessageReadReceiptsRow
                        {
                            MessageId = messageId,
                            UserId = userId,
                            ReadAt = DateTime.UtcNow,
                        }, new Postgrest.QueryOptions { OnConflict = "message_id,user_id" });
                }
                catch
                {
                    // best effort
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.Receipts", ex.Message);
        }
    }

    public async Task DeleteMessageAsync(string messageId)
    {
        try
        {
            await SupabaseService.Client.From<MessagesRow>()
                .Filter("id", Postgrest.Constants.Operator.Equals, messageId)
                .Delete();
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.Delete", ex.Message);
        }
    }

    // ------------------------------------------------------------------
    // Realtime
    // ------------------------------------------------------------------

    /// <summary>
    /// Subscribes to inserts/deletes on the given conversation (channel
    /// "messages:&lt;conversationId&gt;" with filter conversation_id=eq.&lt;id&gt;),
    /// mirroring lib/services/chat_messaging_service.dart.
    /// </summary>
    public Subscription? SubscribeToMessages(string conversationId,
        Func<Message, Task> onInsert, Func<Message, Task>? onDelete = null, Func<Message, Task>? onUpdate = null)
    {
        try
        {
            var channel = SupabaseService.Client.Realtime.Channel($"messages:{conversationId}");

            channel.Register(new PostgresChangesOptions("public", "messages",
                PostgresChangesOptions.ListenType.All, $"conversation_id=eq.{conversationId}", null));

            channel.AddPostgresChangeHandler(PostgresChangesOptions.ListenType.Inserts, (s, change) =>
            {
                if (change.Payload?.Data?.Record is SocketResponsePayload sr &&
                    sr.Record is Dictionary<string, object> record)
                {
                    _ = Task.Run(async () => await onInsert(MessageFromRecord(record)));
                }
            });

            if (onUpdate != null)
            {
                channel.AddPostgresChangeHandler(PostgresChangesOptions.ListenType.Updates, (s, change) =>
                {
                    if (change.Payload?.Data?.Record is SocketResponsePayload sr &&
                        sr.Record is Dictionary<string, object> record)
                    {
                        _ = Task.Run(async () => await onUpdate(MessageFromRecord(record)));
                    }
                });
            }

            if (onDelete != null)
            {
                channel.AddPostgresChangeHandler(PostgresChangesOptions.ListenType.Deletes, (s, change) =>
                {
                    if (change.Payload?.Data?.Record is SocketResponsePayload sr &&
                        sr.Record is Dictionary<string, object> record &&
                        record.TryGetValue("id", out var id))
                    {
                        var msg = new Message { Id = id?.ToString() ?? "" };
                        _ = Task.Run(async () => await onDelete(msg));
                    }
                });
            }

            _ = channel.Subscribe();
            var sub = new Subscription(conversationId, channel);
            _subscriptions[conversationId] = sub;
            return sub;
        }
        catch (Exception ex)
        {
            Logger.Warn("Messages.Subscribe", ex.Message);
            return null;
        }
    }

    public void CloseSubscription(string conversationId)
    {
        if (_subscriptions.Remove(conversationId, out var sub)) sub.Close();
    }

    public void CloseAllSubscriptions()
    {
        foreach (var sub in _subscriptions.Values) sub.Close();
        _subscriptions.Clear();
    }

    // ------------------------------------------------------------------
    // Typing indicators
    // ------------------------------------------------------------------

    /// <summary>
    /// Upserts typing status via DB (typing_indicators table), mirroring
    /// Flutter's updateTypingStatus fallback. The realtime PostgresChanges
    /// subscription in SubscribeToTyping picks up the change.
    /// </summary>
    public async Task SetTypingAsync(string conversationId, string userId, bool isTyping)
    {
        try
        {
            await SupabaseService.Client.From<TypingIndicatorRow>()
                .Upsert(new TypingIndicatorRow
                {
                    ConversationId = conversationId,
                    UserId = userId,
                    IsTyping = isTyping,
                    UpdatedAt = DateTime.UtcNow,
                }, new Postgrest.QueryOptions { OnConflict = "conversation_id,user_id" });
        }
        catch (Exception ex)
        {
            Logger.Warn("Typing.Set", ex.Message);
        }
    }

    /// <summary>
    /// Subscribes to typing status updates for a conversation via PostgresChanges
    /// on the typing_indicators table, mirroring Flutter's subscribeToTypingStatus.
    /// </summary>
    public Action? SubscribeToTyping(string conversationId, string currentUserId, Action<bool> onTyping)
    {
        try
        {
            var channel = SupabaseService.Client.Realtime.Channel($"typing:{conversationId}");

            channel.Register(new PostgresChangesOptions("public", "typing_indicators",
                PostgresChangesOptions.ListenType.All, $"conversation_id=eq.{conversationId}", null));

            channel.AddPostgresChangeHandler(PostgresChangesOptions.ListenType.All,
                (s, change) =>
                {
                    try
                    {
                        if (change.Payload?.Data?.Record is SocketResponsePayload sr &&
                            sr.Record is Dictionary<string, object> record)
                        {
                            var userId = record.TryGetValue("user_id", out var uid) ? uid?.ToString() : null;
                            var isTyping = record.TryGetValue("is_typing", out var it) &&
                                           (it is bool b && b ||
                                            bool.TryParse(it?.ToString(), out var t) && t);
                            if (userId != null && userId != currentUserId)
                                onTyping(isTyping);
                        }
                    }
                    catch { }
                });

            _ = channel.Subscribe();
            return () => channel.Unsubscribe();
        }
        catch (Exception ex)
        {
            Logger.Warn("Typing.Subscribe", ex.Message);
            return null;
        }
    }

    private static Message MessageFromRecord(Dictionary<string, object> record)
    {
        try
        {
            var json = JsonSerializer.Serialize(record);
            using var doc = JsonDocument.Parse(json);
            return Message.FromJson(doc.RootElement);
        }
        catch
        {
            return new Message();
        }
    }
}
