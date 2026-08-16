using System.Runtime.InteropServices;
using Oasis.WinUI.Services;

namespace Oasis.WinUI.Core.Crypto;

// ---------------------------------------------------------------------------
// Opaque + FFI structs matching PQ-DR/src/ffi.rs (#[repr(C)])
// Rust `bool` is 1 byte -> use byte in C# structs; marshal params as UnmanagedType.I1.
// ---------------------------------------------------------------------------

internal unsafe struct RatchetState { }

internal unsafe struct FfiMessage
{
    public byte* header;
    public nint header_len;
    public byte* payload;
    public nint payload_len;
}

internal unsafe struct FfiKeyPair
{
    public byte* public_key;
    public nint public_key_len;
    public byte* secret_key;
    public nint secret_key_len;
}

internal unsafe struct FfiPreKeyBundle
{
    public byte* identity_pk;
    public nint identity_pk_len;
    public byte* signed_pre_key;
    public nint signed_pre_key_len;
    public byte* one_time_pre_key;
    public nint one_time_pre_key_len;
    public byte has_one_time;
}

internal unsafe struct FfiInitialMessage
{
    public RatchetState* state_ptr;
    public byte* alice_identity_pk;
    public nint alice_identity_pk_len;
    public byte* ephemeral_pk;
    public nint ephemeral_pk_len;
    public byte* kem_ciphertext_identity;
    public nint kem_ciphertext_identity_len;
    public byte* kem_ciphertext_signed;
    public nint kem_ciphertext_signed_len;
    public byte* kem_ciphertext_one_time;
    public nint kem_ciphertext_one_time_len;
    public byte has_one_time;
    public byte* ratchet_message_header;
    public nint ratchet_message_header_len;
    public byte* ratchet_message_payload;
    public nint ratchet_message_payload_len;
}

internal static class PqAuraExports
{
    private const string Lib = "pq_aura";

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_generate_keypair();

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_keypair(IntPtr kp);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_create_bundle(byte[] identityPk, nint identityPkLen);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_bundle(IntPtr bundle);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_init_alice(
        byte[] remoteBundleJson, nint remoteBundleLen,
        byte[] idPk, nint idPkLen,
        byte[] idSk, nint idSkLen);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_init_bob(
        byte[] initialMsgJson, nint initialMsgLen,
        byte[] idPk, nint idPkLen,
        byte[] idSk, nint idSkLen,
        byte[] signedSk, nint signedSkLen,
        byte[]? otSk, nint otSkLen,
        [MarshalAs(UnmanagedType.I1)] bool hasOtSk);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_encrypt(
        IntPtr state, byte[] plaintext, nint plaintextLen, byte[] ad, nint adLen);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_decrypt(
        IntPtr state, byte[] header, nint headerLen, byte[] payload, nint payloadLen,
        byte[] ad, nint adLen, out nint outLen);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_message(IntPtr msg);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_buffer(IntPtr ptr, nint len);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_serialize_state(IntPtr state);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint pqa_serialize_state_len(IntPtr state);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_deserialize_state(byte[] bytes, nint len);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_state(IntPtr state);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void pqa_free_initial_message(IntPtr msg);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    internal static extern bool pqa_save_atomic(IntPtr state, [MarshalAs(UnmanagedType.LPUTF8Str)] string path, byte[] key32);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)]
    internal static extern unsafe IntPtr pqa_load_atomic([MarshalAs(UnmanagedType.LPUTF8Str)] string path, byte[] key32);
}

// ---------------------------------------------------------------------------
// High-level wrappers (safe API surface used by the app)
// ---------------------------------------------------------------------------

public sealed class PqAuraKeyPair : IDisposable
{
    internal IntPtr NativePtr;
    public byte[] PublicKey { get; }
    public byte[] SecretKey { get; }

    internal PqAuraKeyPair(IntPtr ptr, byte[] publicKey, byte[] secretKey)
    {
        NativePtr = ptr;
        PublicKey = publicKey;
        SecretKey = secretKey;
    }

    public void Dispose()
    {
        if (NativePtr != IntPtr.Zero)
        {
            PqAuraExports.pqa_free_keypair(NativePtr);
            NativePtr = IntPtr.Zero;
        }
    }
}

public sealed class PqAuraBundle : IDisposable
{
    internal IntPtr NativePtr;
    public byte[] IdentityPk { get; }
    public byte[] SignedPreKey { get; }
    public byte[]? OneTimePreKey { get; }

    internal PqAuraBundle(IntPtr ptr, byte[] identityPk, byte[] signedPreKey, byte[]? oneTimePreKey)
    {
        NativePtr = ptr;
        IdentityPk = identityPk;
        SignedPreKey = signedPreKey;
        OneTimePreKey = oneTimePreKey;
    }

    public void Dispose()
    {
        if (NativePtr != IntPtr.Zero)
        {
            PqAuraExports.pqa_free_bundle(NativePtr);
            NativePtr = IntPtr.Zero;
        }
    }
}

public sealed class PqAuraMessage : IDisposable
{
    internal IntPtr NativePtr;
    public byte[] Header { get; }
    public byte[] Payload { get; }

    internal PqAuraMessage(IntPtr ptr, byte[] header, byte[] payload)
    {
        NativePtr = ptr;
        Header = header;
        Payload = payload;
    }

    public void Dispose()
    {
        if (NativePtr != IntPtr.Zero)
        {
            PqAuraExports.pqa_free_message(NativePtr);
            NativePtr = IntPtr.Zero;
        }
    }
}

public sealed class PqAuraInitialMessage : IDisposable
{
    internal IntPtr NativePtr;
    public IntPtr StatePtr { get; }
    public byte[] AliceIdentityPk { get; }
    public byte[] EphemeralPk { get; }
    public byte[] KemCiphertextIdentity { get; }
    public byte[] KemCiphertextSigned { get; }
    public byte[]? KemCiphertextOneTime { get; }
    public byte[] RatchetHeader { get; }
    public byte[] RatchetPayload { get; }

    internal PqAuraInitialMessage(IntPtr ptr, IntPtr statePtr, byte[] aliceIdentityPk, byte[] ephemeralPk,
        byte[] kemIdentity, byte[] kemSigned, byte[]? kemOneTime, byte[] ratchetHeader, byte[] ratchetPayload)
    {
        NativePtr = ptr;
        StatePtr = statePtr;
        AliceIdentityPk = aliceIdentityPk;
        EphemeralPk = ephemeralPk;
        KemCiphertextIdentity = kemIdentity;
        KemCiphertextSigned = kemSigned;
        KemCiphertextOneTime = kemOneTime;
        RatchetHeader = ratchetHeader;
        RatchetPayload = ratchetPayload;
    }

    public void Dispose()
    {
        if (NativePtr != IntPtr.Zero)
        {
            PqAuraExports.pqa_free_initial_message(NativePtr);
            NativePtr = IntPtr.Zero;
        }
    }
}

/// <summary>
/// A ratchet session handle. Mirrors the PQAuraBridge in the Flutter app
/// (lib/core/crypto/pq_aura_bridge.dart).
/// </summary>
public sealed class PqAuraRatchet : IDisposable
{
    public IntPtr NativePtr { get; private set; }

    internal PqAuraRatchet(IntPtr ptr) => NativePtr = ptr;

    public bool IsValid => NativePtr != IntPtr.Zero;

    public void Dispose()
    {
        if (NativePtr != IntPtr.Zero)
        {
            PqAuraExports.pqa_free_state(NativePtr);
            NativePtr = IntPtr.Zero;
        }
    }

    public static unsafe PqAuraKeyPair GenerateKeyPair()
    {
        var ptr = PqAuraExports.pqa_generate_keypair();
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_generate_keypair failed");
        var kp = Marshal.PtrToStructure<FfiKeyPair>(ptr);
        return new PqAuraKeyPair(ptr, Copy(kp.public_key, kp.public_key_len), Copy(kp.secret_key, kp.secret_key_len));
    }

    public static unsafe PqAuraBundle CreateBundle(byte[] identityPk)
    {
        var ptr = PqAuraExports.pqa_create_bundle(identityPk, identityPk.Length);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_create_bundle failed");
        var b = Marshal.PtrToStructure<FfiPreKeyBundle>(ptr);
        var oneTime = b.has_one_time != 0 ? Copy(b.one_time_pre_key, b.one_time_pre_key_len) : null;
        return new PqAuraBundle(ptr, Copy(b.identity_pk, b.identity_pk_len), Copy(b.signed_pre_key, b.signed_pre_key_len), oneTime);
    }

    public static unsafe PqAuraInitialMessage InitAlice(byte[] remoteBundleJson, byte[] idPk, byte[] idSk)
    {
        var ptr = PqAuraExports.pqa_init_alice(remoteBundleJson, remoteBundleJson.Length, idPk, idPk.Length, idSk, idSk.Length);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_init_alice failed");
        var m = Marshal.PtrToStructure<FfiInitialMessage>(ptr);
        var oneTime = m.has_one_time != 0 ? Copy(m.kem_ciphertext_one_time, m.kem_ciphertext_one_time_len) : null;
        return new PqAuraInitialMessage(
            ptr,
            (IntPtr)m.state_ptr,
            Copy(m.alice_identity_pk, m.alice_identity_pk_len),
            Copy(m.ephemeral_pk, m.ephemeral_pk_len),
            Copy(m.kem_ciphertext_identity, m.kem_ciphertext_identity_len),
            Copy(m.kem_ciphertext_signed, m.kem_ciphertext_signed_len),
            oneTime,
            Copy(m.ratchet_message_header, m.ratchet_message_header_len),
            Copy(m.ratchet_message_payload, m.ratchet_message_payload_len));
    }

    public static PqAuraRatchet InitBob(byte[] initialMsgJson, byte[] idPk, byte[] idSk, byte[] signedSk, byte[]? otSk = null)
    {
        var hasOt = otSk is not null;
        var ptr = PqAuraExports.pqa_init_bob(
            initialMsgJson, initialMsgJson.Length,
            idPk, idPk.Length,
            idSk, idSk.Length,
            signedSk, signedSk.Length,
            otSk, otSk?.Length ?? 0,
            hasOt);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_init_bob failed");
        return new PqAuraRatchet(ptr);
    }

    public PqAuraMessage Encrypt(byte[] plaintext, byte[] ad)
    {
        var ptr = PqAuraExports.pqa_encrypt(NativePtr, plaintext, plaintext.Length, ad, ad.Length);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_encrypt failed");
        unsafe
        {
            var m = Marshal.PtrToStructure<FfiMessage>(ptr);
            return new PqAuraMessage(ptr, Copy(m.header, m.header_len), Copy(m.payload, m.payload_len));
        }
    }

    public byte[]? Decrypt(byte[] header, byte[] payload, byte[] ad)
    {
        var ptr = PqAuraExports.pqa_decrypt(NativePtr, header, header.Length, payload, payload.Length, ad, ad.Length, out var outLen);
        if (ptr == IntPtr.Zero) return null;
        try
        {
            var plain = new byte[outLen];
            Marshal.Copy(ptr, plain, 0, (int)outLen);
            return plain;
        }
        finally
        {
            PqAuraExports.pqa_free_buffer(ptr, outLen);
        }
    }

    public byte[]? Serialize()
    {
        var ptr = PqAuraExports.pqa_serialize_state(NativePtr);
        var len = PqAuraExports.pqa_serialize_state_len(NativePtr);
        if (ptr == IntPtr.Zero || len == 0) return null;
        try
        {
            var data = new byte[len];
            Marshal.Copy(ptr, data, 0, (int)len);
            return data;
        }
        finally
        {
            PqAuraExports.pqa_free_buffer(ptr, len);
        }
    }

    public static PqAuraRatchet Deserialize(byte[] data)
    {
        var ptr = PqAuraExports.pqa_deserialize_state(data, data.Length);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_deserialize_state failed");
        return new PqAuraRatchet(ptr);
    }

    /// <summary>Atomically persists the ratchet state; key must be exactly 32 bytes.</summary>
    public bool SaveAtomic(string path, byte[] key32)
    {
        if (key32.Length != 32) throw new ArgumentException("Encryption key must be exactly 32 bytes.", nameof(key32));
        return PqAuraExports.pqa_save_atomic(NativePtr, path, key32);
    }

    public static PqAuraRatchet LoadAtomic(string path, byte[] key32)
    {
        if (key32.Length != 32) throw new ArgumentException("Encryption key must be exactly 32 bytes.", nameof(key32));
        var ptr = PqAuraExports.pqa_load_atomic(path, key32);
        if (ptr == IntPtr.Zero) throw new InvalidOperationException("pqa_load_atomic failed");
        return new PqAuraRatchet(ptr);
    }

    private static unsafe byte[] Copy(byte* src, nint len)
    {
        if (src == null || len <= 0) return Array.Empty<byte>();
        var result = new byte[len];
        Marshal.Copy((IntPtr)src, result, 0, (int)len);
        return result;
    }
}

/// <summary>
/// Loads the native pq_aura.dll, mirroring PQAuraBridge.load() in the Flutter app.
/// </summary>
public static class PqAuraLoader
{
    private static bool _loaded;
    private static readonly object _lock = new();

    public static bool IsLoaded => _loaded;

    public static bool TryLoad()
    {
        lock (_lock)
        {
            if (_loaded) return true;

            var candidates = new List<string>
            {
                Path.Combine(AppContext.BaseDirectory, "pq_aura.dll"),
                Path.Combine(AppContext.BaseDirectory, "Assets", "pq_aura.dll"),
                Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "windows", "libs", "pq_aura.dll")),
            };

            var extractionRoot = Path.Combine(Path.GetTempPath(), ".net");
            if (Directory.Exists(extractionRoot))
            {
                foreach (var file in Directory.EnumerateFiles(extractionRoot, "pq_aura.dll", SearchOption.AllDirectories))
                {
                    candidates.Add(file);
                }
            }

            foreach (var path in candidates)
            {
                if (File.Exists(path))
                {
                    try
                    {
                        NativeLibrary.Load(path);
                        _loaded = true;
                        Logger.Info("PqAuraLoader", $"Loaded pq_aura.dll from {path}");
                        return true;
                    }
                    catch (Exception ex)
                    {
                        Logger.Warn("PqAuraLoader", $"Failed to load from {path}: {ex.Message}");
                    }
                }
            }

            Logger.Warn("PqAuraLoader", "pq_aura.dll not found; post-quantum features disabled.");
            return false;
        }
    }
}
