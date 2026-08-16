using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Oasis.WinUI.Core.Models;
using Oasis.WinUI.Core.Networking;
using Oasis.WinUI.Core.Storage;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Core.Crypto;

/// <summary>
/// JSON converter that serializes byte arrays as arrays of ints, matching how
/// Dart's jsonEncode serializes Uint8List. This is REQUIRED for wire
/// compatibility with the Flutter app / PQ-DR native library handshake format.
/// </summary>
public sealed class ByteArrayAsIntArrayConverter : JsonConverter<byte[]>
{
    public override byte[] Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.StartArray) throw new JsonException("Expected int array.");
        var list = new List<byte>();
        while (reader.Read())
        {
            if (reader.TokenType == JsonTokenType.EndArray) break;
            list.Add(reader.GetByte());
        }
        return list.ToArray();
    }

    public override void Write(Utf8JsonWriter writer, byte[] value, JsonSerializerOptions options)
    {
        writer.WriteStartArray();
        foreach (var b in value) writer.WriteNumberValue(b);
        writer.WriteEndArray();
    }
}

public sealed record PqAuraKeyPairData(byte[] PublicKey, byte[] SecretKey);

public sealed record PqAuraBundleData(byte[] IdentityPk, byte[] SignedPreKey, byte[]? OneTimePreKey);

public sealed record PQAuraEncryptedMessage(byte[] Header, byte[] Payload);

/// <summary>
/// High-level PQ-Aura post-quantum encryption service.
/// Mirrors lib/features/messages/data/pq_aura/pq_aura_service_io.dart exactly
/// (bundle upload, Alice/Bob handshake, atomic session persistence, wire format).
/// </summary>
public sealed class PQAuraService
{
    public static PQAuraService Current { get; } = new();

    private const string IdentityKeyPairKey = "pq_aura_identity_keypair";
    private const string SignedPreKeyKey = "pq_aura_signed_prekey";
    private const string StateEncryptionKey = "pq_aura_state_encryption_key";

    private static readonly JsonSerializerOptions IntArrayOptions = new()
    {
        Converters = { new ByteArrayAsIntArrayConverter() },
    };

    private readonly Dictionary<string, PqAuraRatchet> _activeSessions = new();
    private readonly Dictionary<string, PqAuraInitialMessage> _pendingHandshakes = new();
    private readonly HashSet<string> _corruptSessions = new();
    private static readonly object _nativeLock = new();

    private bool _isInitialized;

    private PQAuraService() { }

    public bool IsReady => _isInitialized;

    public static string SessionsDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Oasis", "pqa_sessions");

    public static string SessionPathFor(string remoteUserId)
        => Path.Combine(SessionsDir, $"session_{remoteUserId}.pqa");

    // ------------------------------------------------------------------
    // Init / lifecycle
    // ------------------------------------------------------------------

    /// <summary>Loads the native lib, ensures identity keys, uploads the bundle.</summary>
    public async Task<bool> InitAsync()
    {
        if (_isInitialized) return true;

        if (!PqAuraLoader.TryLoad()) return false;

        var stored = await SecureStorage.LoadAsync(IdentityKeyPairKey);
        if (string.IsNullOrEmpty(stored))
        {
            try
            {
                using var kp = PqAuraRatchet.GenerateKeyPair();
                stored = $"{Convert.ToBase64String(kp.PublicKey)}:{Convert.ToBase64String(kp.SecretKey)}";
                await SecureStorage.SaveAsync(IdentityKeyPairKey, stored);
            }
            catch (Exception ex)
            {
                Logger.Warn("PQAura.Init", $"Key generation error: {ex.Message}");
                return false;
            }
        }

        PqAuraBundleData? bundle = null;
        var bundleJson = SecureStorage.Load(SignedPreKeyKey);
        if (!string.IsNullOrEmpty(bundleJson))
        {
            bundle = ParseBundleJson(bundleJson);
        }
        else
        {
            bundle = CreateAndStoreBundle();
        }

        if (bundle != null && !string.IsNullOrEmpty(stored))
        {
            await UploadBundleToServerAsync(stored, bundle);
        }

        _isInitialized = true;
        return true;
    }

    public void MarkNotInitialized() => _isInitialized = false;

    public bool HasSession(string remoteUserId)
        => _activeSessions.ContainsKey(remoteUserId);

    // ------------------------------------------------------------------
    // Session creation (Alice / Bob) and loading
    // ------------------------------------------------------------------

    public async Task<bool?> GetOrCreateSessionAsync(string remoteUserId)
    {
        if (!_isInitialized)
        {
            var ok = await InitAsync();
            if (!ok) return null;
        }
        if (HasSession(remoteUserId)) return true;

        var loaded = await LoadSessionAsync(remoteUserId);
        if (loaded) return true;

        return await InitSessionAliceAsync(remoteUserId);
    }

    /// <summary>Initiator (Alice) handshake: fetch remote bundle, init native state.</summary>
    public async Task<bool> InitSessionAliceAsync(string remoteUserId)
    {
        try
        {
            var response = await SupabaseService.Client.From<PqKeysRow>()
                .Select("*")
                .Filter("user_id", Postgrest.Constants.Operator.Equals, remoteUserId)
                .Limit(1)
                .Get();

            if (string.IsNullOrWhiteSpace(response?.Content)) return false;

            using var doc = JsonDocument.Parse(response.Content);
            if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0) return false;

            var row = doc.RootElement[0];
            if (!row.TryGetProperty("bundle", out var bundleEl) || bundleEl.ValueKind != JsonValueKind.Object) return false;

            var identityPkB64 = JsonUtil.S(bundleEl, "identity_pk");
            var signedPkB64 = JsonUtil.S(bundleEl, "signed_prekey");
            if (string.IsNullOrEmpty(identityPkB64) || string.IsNullOrEmpty(signedPkB64)) return false;

            var remoteIdentityPk = Convert.FromBase64String(identityPkB64);
            var remoteSignedPk = Convert.FromBase64String(signedPkB64);
            byte[]? remoteOtPk = null;
            var otB64 = JsonUtil.S(bundleEl, "onetime_prekey");
            if (!string.IsNullOrEmpty(otB64)) remoteOtPk = Convert.FromBase64String(otB64);

            var bundleMap = new Dictionary<string, object?>
            {
                ["identity_pk"] = Hybrid(remoteIdentityPk),
                ["signed_pre_key"] = Hybrid(remoteSignedPk),
                ["one_time_pre_key"] = remoteOtPk != null ? Hybrid(remoteOtPk) : null,
            };
            var bundleBytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(bundleMap, IntArrayOptions));

            var localKeys = GetIdentityKeys(stored: null);
            if (localKeys is null) return false;

            PqAuraInitialMessage initialMsg;
            lock (_nativeLock)
            {
                initialMsg = PqAuraRatchet.InitAlice(bundleBytes, localKeys.PublicKey, localKeys.SecretKey);
            }

            if (_pendingHandshakes.Remove(remoteUserId, out var old)) old.Dispose();

            await SaveSessionAtomicAsync(remoteUserId, new PqAuraRatchet(initialMsg.StatePtr));

            _activeSessions[remoteUserId] = new PqAuraRatchet(initialMsg.StatePtr);
            _corruptSessions.Remove(remoteUserId);
            _pendingHandshakes[remoteUserId] = initialMsg;
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("PQAura.AliceInit", $"Alice init error ({remoteUserId}): {ex.Message}");
            return false;
        }
    }

    /// <summary>Responder (Bob) handshake using an incoming initial message header.</summary>
    public async Task<bool> InitSessionBobAsync(string senderId, byte[] header, byte[] payload)
    {
        try
        {
            var localKeys = GetIdentityKeys(stored: null);
            if (localKeys is null) return false;

            PqAuraRatchet state;
            lock (_nativeLock)
            {
                // Flutter passes the identity secret key as the signed secret key and null otSk.
                state = PqAuraRatchet.InitBob(header, localKeys.PublicKey, localKeys.SecretKey, localKeys.SecretKey, null);
            }

            _activeSessions[senderId] = state;
            _corruptSessions.Remove(senderId);
            await SaveSessionAtomicAsync(senderId, state);
            return true;
        }
        catch (Exception ex)
        {
            Logger.Warn("PQAura.BobInit", $"Bob init error ({senderId}): {ex.Message}");
            return false;
        }
    }

    public async Task<bool> LoadSessionAsync(string remoteUserId)
    {
        try
        {
            var path = SessionPathFor(remoteUserId);
            if (!File.Exists(path)) return false;

            var key = GetOrCreateStateEncryptionKey();

            PqAuraRatchet? ratchet = null;
            try
            {
                ratchet = PqAuraRatchet.LoadAtomic(path, key);
            }
            catch
            {
                ratchet = null;
            }

            if (ratchet is null)
            {
                try
                {
                    ratchet = PqAuraRatchet.Deserialize(await File.ReadAllBytesAsync(path));
                }
                catch
                {
                    return false;
                }
            }

            _activeSessions[remoteUserId] = ratchet;
            _corruptSessions.Remove(remoteUserId);
            return true;
        }
        catch
        {
            return false;
        }
    }

    // ------------------------------------------------------------------
    // Encrypt / decrypt
    // ------------------------------------------------------------------

    public async Task<PQAuraEncryptedMessage?> EncryptMessageAsync(string recipientId, string plaintext)
    {
        try
        {
            var ok = await GetOrCreateSessionAsync(recipientId);
            if (ok != true) return null;
            if (!_activeSessions.TryGetValue(recipientId, out var state) || state is null || !state.IsValid) return null;

            var plaintextBytes = Encoding.UTF8.GetBytes(plaintext);
            var ad = Encoding.UTF8.GetBytes(recipientId);

            PqAuraMessage? encrypted;
            lock (_nativeLock)
            {
                try
                {
                    encrypted = state.Encrypt(plaintextBytes, ad);
                }
                catch
                {
                    encrypted = null;
                }
            }
            if (encrypted is null) return null;

            await SaveSessionAtomicAsync(recipientId, state);

            byte[] header;
            byte[] payload;

            if (_pendingHandshakes.TryGetValue(recipientId, out var initial))
            {
                _pendingHandshakes.Remove(recipientId);

                var handshake = new Dictionary<string, object?>
                {
                    ["alice_identity_pk"] = Hybrid(initial.AliceIdentityPk),
                    ["ephemeral_pk"] = Hybrid(initial.EphemeralPk),
                    ["kem_ciphertext_identity"] = initial.KemCiphertextIdentity,
                    ["kem_ciphertext_signed"] = initial.KemCiphertextSigned,
                    ["kem_ciphertext_one_time"] = initial.KemCiphertextOneTime,
                    ["ratchet_message"] = new Dictionary<string, object?>
                    {
                        ["header_ciphertext"] = encrypted.Header,
                        ["payload_ciphertext"] = encrypted.Payload,
                    },
                };

                header = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(handshake, IntArrayOptions));
                payload = encrypted.Payload;

                initial.Dispose();
            }
            else
            {
                header = encrypted.Header;
                payload = encrypted.Payload;
            }

            encrypted.Dispose();
            return new PQAuraEncryptedMessage(header, payload);
        }
        catch (Exception ex)
        {
            Logger.Warn("PQAura.Encrypt", $"Encryption error ({recipientId}): {ex.Message}");
            return null;
        }
    }

    public async Task<string?> DecryptMessageAsync(string senderId, byte[] header, byte[] payload)
    {
        try
        {
            if (!_isInitialized)
            {
                var ready = await InitAsync();
                if (!ready) return null;
            }

            if (_corruptSessions.Contains(senderId)) return null;

            if (!HasSession(senderId))
            {
                var loaded = await LoadSessionAsync(senderId);
                if (!loaded)
                {
                    var initiated = await InitSessionBobAsync(senderId, header, payload);
                    if (!initiated) return null;
                }
            }

            if (!_activeSessions.TryGetValue(senderId, out var state) || state is null || !state.IsValid) return null;

            var ad = Encoding.UTF8.GetBytes(senderId);

            byte[]? plain;
            lock (_nativeLock)
            {
                try
                {
                    plain = state.Decrypt(header, payload, ad);
                }
                catch
                {
                    plain = null;
                }
            }

            if (plain is null)
            {
                _corruptSessions.Add(senderId);
                return null;
            }

            await SaveSessionAtomicAsync(senderId, state);
            return Encoding.UTF8.GetString(plain);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Encrypts a media key with AD "media_key:&lt;recipientId&gt;" (Flutter-compatible).</summary>
    public async Task<(byte[] Header, byte[] Payload)?> EncryptMediaKeyAsync(string recipientId, byte[] mediaKey)
    {
        try
        {
            var ok = await GetOrCreateSessionAsync(recipientId);
            if (ok != true) return null;
            if (!_activeSessions.TryGetValue(recipientId, out var state) || state is null || !state.IsValid) return null;

            var ad = Encoding.UTF8.GetBytes($"media_key:{recipientId}");

            PqAuraMessage? encrypted;
            lock (_nativeLock)
            {
                try
                {
                    encrypted = state.Encrypt(mediaKey, ad);
                }
                catch
                {
                    encrypted = null;
                }
            }
            if (encrypted is null) return null;

            await SaveSessionAtomicAsync(recipientId, state);

            // A handshake is only carried on the first plaintext message, not on media keys.
            if (_pendingHandshakes.TryGetValue(recipientId, out var initial))
            {
                _pendingHandshakes.Remove(recipientId);
                initial.Dispose();
            }

            var result = (encrypted.Header, encrypted.Payload);
            encrypted.Dispose();
            return result;
        }
        catch
        {
            return null;
        }
    }

    // ------------------------------------------------------------------
    // Native memory / cleanup
    // ------------------------------------------------------------------

    public void CloseSession(string remoteUserId)
    {
        if (_activeSessions.Remove(remoteUserId, out var state)) state?.Dispose();
        if (_pendingHandshakes.Remove(remoteUserId, out var initial)) initial?.Dispose();
        try
        {
            if (File.Exists(SessionPathFor(remoteUserId)))
                File.Delete(SessionPathFor(remoteUserId));
        }
        catch { /* best effort */ }
    }

    public async Task ClearAllAsync()
    {
        foreach (var state in _activeSessions.Values) state?.Dispose();
        _activeSessions.Clear();

        foreach (var initial in _pendingHandshakes.Values) initial?.Dispose();
        _pendingHandshakes.Clear();
        _corruptSessions.Clear();

        try
        {
            if (Directory.Exists(SessionsDir))
                Directory.Delete(SessionsDir, recursive: true);
        }
        catch { /* best effort */ }

        await SecureStorage.DeleteAsync(IdentityKeyPairKey);
        await SecureStorage.DeleteAsync(SignedPreKeyKey);
        await SecureStorage.DeleteAsync(StateEncryptionKey);

        _isInitialized = false;
    }

    // ------------------------------------------------------------------
    // Key + bundle management
    // ------------------------------------------------------------------

    private static PqAuraKeyPairData? GetIdentityKeys(string? stored)
    {
        stored ??= SecureStorage.Load(IdentityKeyPairKey);
        if (string.IsNullOrEmpty(stored)) return null;

        var parts = stored.Split(':');
        if (parts.Length != 2) return null;

        try
        {
            return new PqAuraKeyPairData(
                Convert.FromBase64String(parts[0]),
                Convert.FromBase64String(parts[1]));
        }
        catch
        {
            return null;
        }
    }

    private static PqAuraBundleData? ParseBundleJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var id = JsonUtil.S(root, "identity_pk");
            var signed = JsonUtil.S(root, "signed_prekey");
            var ot = JsonUtil.S(root, "onetime_prekey");
            if (string.IsNullOrEmpty(id) || string.IsNullOrEmpty(signed)) return null;
            return new PqAuraBundleData(
                Convert.FromBase64String(id),
                Convert.FromBase64String(signed),
                ot != null ? Convert.FromBase64String(ot) : null);
        }
        catch
        {
            return null;
        }
    }

    private static PqAuraBundleData? CreateAndStoreBundle()
    {
        var keys = GetIdentityKeys(stored: null);
        if (keys is null) return null;

        PqAuraBundle bundle;
        lock (_nativeLock)
        {
            bundle = PqAuraRatchet.CreateBundle(keys.PublicKey);
        }

        var json = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["identity_pk"] = Convert.ToBase64String(bundle.IdentityPk),
            ["signed_prekey"] = Convert.ToBase64String(bundle.SignedPreKey),
            ["onetime_prekey"] = bundle.OneTimePreKey != null ? Convert.ToBase64String(bundle.OneTimePreKey) : null,
        });
        SecureStorage.Save(SignedPreKeyKey, json);

        var data = new PqAuraBundleData(bundle.IdentityPk, bundle.SignedPreKey, bundle.OneTimePreKey);
        bundle.Dispose();
        return data;
    }

    private static async Task UploadBundleToServerAsync(string identityStored, PqAuraBundleData bundle)
    {
        try
        {
            var userId = SupabaseService.Client.Auth.CurrentUser?.Id;
            if (string.IsNullOrEmpty(userId)) return;

            var keys = GetIdentityKeys(identityStored);
            if (keys is null) return;

            await SupabaseService.Client.From<PqKeysRow>()
                .Upsert(new PqKeysRow
                {
                    UserId = userId,
                    IdentityPk = Convert.ToBase64String(keys.PublicKey),
                    Bundle = new Dictionary<string, object?>
                    {
                        ["identity_pk"] = Convert.ToBase64String(bundle.IdentityPk),
                        ["signed_prekey"] = Convert.ToBase64String(bundle.SignedPreKey),
                        ["onetime_prekey"] = bundle.OneTimePreKey != null ? Convert.ToBase64String(bundle.OneTimePreKey) : null,
                    },
                }, new Postgrest.QueryOptions { OnConflict = "user_id" });
        }
        catch (Exception ex)
        {
            Logger.Warn("PQAura.UploadBundle", $"Failed to upload bundle: {ex.Message}");
        }
    }

    private static byte[] GetOrCreateStateEncryptionKey()
    {
        var stored = SecureStorage.Load(StateEncryptionKey);
        if (!string.IsNullOrEmpty(stored))
        {
            try
            {
                var existing = Convert.FromBase64String(stored);
                if (existing.Length == 32) return existing;
            }
            catch { /* regenerate */ }
        }

        var key = RandomNumberGenerator.GetBytes(32);
        SecureStorage.Save(StateEncryptionKey, Convert.ToBase64String(key));
        return key;
    }

    private async Task SaveSessionAtomicAsync(string remoteUserId, PqAuraRatchet state)
    {
        try
        {
            var path = SessionPathFor(remoteUserId);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            state.SaveAtomic(path, GetOrCreateStateEncryptionKey());
        }
        catch (Exception ex)
        {
            Logger.Warn("PQAura.SaveAtomic", ex.Message);
        }
    }

    /// <summary>Splits a flat 64-byte key into a Dart-style hybrid map {classic: [..32], quantum: [..]}.</summary>
    private static object? Hybrid(byte[]? flat)
        => flat is null ? null : new Dictionary<string, object?>
        {
            ["classic"] = flat.Take(32).ToArray(),
            ["quantum"] = flat.Skip(32).ToArray(),
        };
}
