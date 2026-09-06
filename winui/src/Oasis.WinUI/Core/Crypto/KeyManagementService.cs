using System.Security.Cryptography;
using System.Text;
using Isopoh.Cryptography.Argon2;

namespace Oasis.WinUI.Core.Crypto;

/// <summary>
/// PIN-based RSA key backup/restore and message decryption, mirroring
/// lib/services/key_management_service.dart and
/// lib/features/messages/data/encryption_service.dart.
/// </summary>
public static class KeyManagementService
{
    public static string PrivateKeyKey(string uid) => $"rsa_private_key_{uid}";
    public static string PublicKeyKey(string uid) => $"rsa_public_key_{uid}";

    /// <summary>
    /// Derives a 32-byte key from the User ID for legacy seamless backup encryption (v1).
    /// </summary>
    public static byte[] DeriveLegacyBackupKey(string userId)
    {
        var bytes = Encoding.UTF8.GetBytes(userId);
        return SHA256.HashData(bytes);
    }

    /// <summary>
    /// Derives the 32-byte backup encryption key from the 6-digit PIN using
    /// Argon2id (version 0x13, iterations 2, 4096 KiB memory, 1 lane),
    /// matching key_management_service.dart.deriveSecureBackupKey.
    /// </summary>
    public static byte[] DeriveSecureBackupKey(string pin, string saltBase64)
    {
        var config = new Argon2Config
        {
            Password = Encoding.UTF8.GetBytes(pin),
            Salt = Convert.FromBase64String(saltBase64),
            TimeCost = 2,
            MemoryCost = 4096,
            Lanes = 1,
            Threads = 1,
            HashLength = 32,
            Type = Argon2Type.HybridAddressing,
            Version = Argon2Version.Nineteen,
        };
        var encoded = Argon2.Hash(config).Split('$')[^1];
        if (encoded.Length % 4 != 0) encoded = encoded.PadRight(encoded.Length + (4 - encoded.Length % 4), '=');
        return Convert.FromBase64String(encoded);
    }

    /// <summary>
    /// Decrypts an AES-256-CBC (PKCS7) blob with a 16-byte IV prepended,
    /// matching key_management_service.dart.decryptWithKey (v2 backup format).
    /// </summary>
    public static string? DecryptWithKey(string combinedBase64, byte[] key)
    {
        try
        {
            var combined = Convert.FromBase64String(combinedBase64);
            if (combined.Length <= 16) return null;
            var iv = combined[..16];
            var ciphertext = combined[16..];
            using var aes = Aes.Create();
            aes.Key = key;
            aes.IV = iv;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;
            using var decryptor = aes.CreateDecryptor();
            var plain = decryptor.TransformFinalBlock(ciphertext, 0, ciphertext.Length);
            return Encoding.UTF8.GetString(plain);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// RSA-PKCS1-decrypts one encrypted_keys entry and base64-decodes the
    /// result into the 32-byte AES message key, matching
    /// encryption_service.dart._tryDecryptWithPrivateKey.
    /// </summary>
    public static byte[]? DecryptRsaKey(string privateKeyPem, string encryptedValueBase64)
    {
        try
        {
            using var rsa = RSA.Create();
            rsa.ImportFromPem(privateKeyPem);
            var decrypted = rsa.Decrypt(
                Convert.FromBase64String(encryptedValueBase64), RSAEncryptionPadding.Pkcs1);
            return Convert.FromBase64String(Encoding.UTF8.GetString(decrypted));
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// AES-CBC decrypt with PKCS7 padding, matching Dart encrypt package's AES(key, mode: AESMode.cbc).
    /// </summary>
    public static string? AesCbcDecrypt(byte[] key, byte[] iv, string ciphertextBase64)
    {
        try
        {
            var ciphertext = Convert.FromBase64String(ciphertextBase64);
            if (ciphertext.Length == 0) return null;
            if (iv.Length != 16) return null;

            using var aes = Aes.Create();
            aes.Key = key;
            aes.IV = iv;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;
            using var decryptor = aes.CreateDecryptor();
            var plain = decryptor.TransformFinalBlock(ciphertext, 0, ciphertext.Length);
            return Encoding.UTF8.GetString(plain);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// AES-SIC (CTR) decrypt with PKCS7 padding, matching encrypt
    /// package's default AES(AESMode.sic, PKCS7). Counter starts at the IV
    /// and increments once per 16-byte block (big-endian carry).
    /// </summary>
    public static string? AesSicDecrypt(byte[] key, byte[] iv, string ciphertextBase64)
    {
        try
        {
            var ciphertext = Convert.FromBase64String(ciphertextBase64);
            if (ciphertext.Length == 0 || ciphertext.Length % 16 != 0) return null;
            if (iv.Length != 16) return null;

            using var aes = Aes.Create();
            aes.Key = key;
            aes.Mode = CipherMode.ECB;
            aes.Padding = PaddingMode.None;
            using var encryptor = aes.CreateEncryptor();

            var counter = (byte[])iv.Clone();
            var plain = new byte[ciphertext.Length];
            for (var off = 0; off < ciphertext.Length; off += 16)
            {
                var keystream = encryptor.TransformFinalBlock(counter, 0, 16);
                for (var i = 0; i < 16; i++) plain[off + i] = (byte)(ciphertext[off + i] ^ keystream[i]);
                IncrementCounter(counter);
            }
            return StripPkcs7(plain);
        }
        catch
        {
            return null;
        }
    }

    public static string? AesDecryptAny(byte[] key, byte[] iv, string ciphertextBase64)
    {
        return AesSicDecrypt(key, iv, ciphertextBase64) ?? AesCbcDecrypt(key, iv, ciphertextBase64);
    }

    public static string HashPublicKey(string pem)
    {
        var normalized = pem
            .Replace("-----BEGIN PUBLIC KEY-----", "")
            .Replace("-----END PUBLIC KEY-----", "")
            .Replace("-----BEGIN RSA PUBLIC KEY-----", "")
            .Replace("-----END RSA PUBLIC KEY-----", "")
            .Replace("\r", "")
            .Replace("\n", "")
            .Trim();
        var bytes = Encoding.UTF8.GetBytes(normalized);
        return Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant()[..16];
    }

    /// <summary>
    /// RSA-PKCS1 encrypts an AES key with a recipient's public key PEM.
    /// </summary>
    public static string? EncryptRsaKey(string publicKeyPem, byte[] aesKey)
    {
        try
        {
            using var rsa = RSA.Create();
            rsa.ImportFromPem(publicKeyPem);
            var base64Key = Convert.ToBase64String(aesKey);
            var encrypted = rsa.Encrypt(Encoding.UTF8.GetBytes(base64Key), RSAEncryptionPadding.Pkcs1);
            return Convert.ToBase64String(encrypted);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Generates RSA fallback ciphertext and encrypted keys for cross-platform dual layer decryption.
    /// </summary>
    public static (string Ciphertext, string Iv, Dictionary<string, string> EncryptedKeys)? EncryptMessageFallback(
        string content, IEnumerable<string> publicKeysPem)
    {
        try
        {
            var aesKey = new byte[32];
            var iv = new byte[16];
            RandomNumberGenerator.Fill(aesKey);
            RandomNumberGenerator.Fill(iv);

            using var aes = Aes.Create();
            aes.Key = aesKey;
            aes.IV = iv;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;
            using var encryptor = aes.CreateEncryptor();
            var contentBytes = Encoding.UTF8.GetBytes(content);
            var encryptedBytes = encryptor.TransformFinalBlock(contentBytes, 0, contentBytes.Length);
            var ciphertextBase64 = Convert.ToBase64String(encryptedBytes);

            var encryptedKeys = new Dictionary<string, string>();
            foreach (var pubKey in publicKeysPem)
            {
                if (string.IsNullOrWhiteSpace(pubKey)) continue;
                var encKey = EncryptRsaKey(pubKey, aesKey);
                if (encKey != null)
                {
                    encryptedKeys[HashPublicKey(pubKey)] = encKey;
                }
            }

            return (ciphertextBase64, Convert.ToBase64String(iv), encryptedKeys);
        }
        catch
        {
            return null;
        }
    }

    private static void IncrementCounter(byte[] counter)
    {
        for (var i = counter.Length - 1; i >= 0; i--)
        {
            counter[i]++;
            if (counter[i] != 0) break;
        }
    }

    private static string? StripPkcs7(byte[] plain)
    {
        if (plain.Length == 0) return null;
        var pad = plain[^1];
        if (pad < 1 || pad > 16 || pad > plain.Length) return Encoding.UTF8.GetString(plain);
        for (var i = plain.Length - pad; i < plain.Length; i++)
        {
            if (plain[i] != pad) return Encoding.UTF8.GetString(plain);
        }
        return Encoding.UTF8.GetString(plain, 0, plain.Length - pad);
    }
}
