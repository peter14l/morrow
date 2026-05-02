# Plan: Migration to PQ-Aura (Hybrid Post-Quantum E2EE)

## Objective
Migrate the Oasis messaging system from the classical Signal Protocol (X25519) to the **PQ-Aura** system (Hybrid ML-KEM-1024 + X25519) to provide quantum-resistant end-to-end encryption.

---

## 1. PQ-DR Folder (Rust Enhancements)
The current Rust FFI is minimal. We need to expand it to handle the full cryptographic lifecycle.

### Changes:
- **`src/ffi.rs`**:
    - Add `pqa_generate_keypair()`: Generate a hybrid X25519 + ML-KEM keypair.
    - Add `pqa_create_bundle(identity_sk)`: Generate a Signed Pre-Key (SPK) and a set of One-Time Pre-Keys (OPK).
    - Add `pqa_init_alice(remote_bundle, local_identity)`: Implementation of the Hybrid-X3DH handshake for the initiator.
    - Add `pqa_init_bob(initial_msg, local_identity)`: Implementation of the Hybrid-X3DH handshake for the receiver.
    - Add `pqa_serialize_state(state_ptr)` & `pqa_deserialize_state(bytes)`: Enable persistence of the Double Ratchet state to the device's local storage.
- **`src/crypto.rs`**:
    - Ensure all keys and ciphertexts have `to_bytes()` and `from_bytes()` methods for efficient FFI transfer (avoiding Base64 where possible in the Rust-to-Dart bridge).

---

## 2. Supabase (Backend & SQL)
The backend needs to store much larger public keys and bundles.

### Changes:
- **`supabase/migrations/20260502_add_pq_aura_keys.sql`** (New File):
    - Create table `pq_keys`:
        - `user_id`: UUID (PK, FK to auth.users).
        - `identity_pk`: BYTEA (The raw 1.5KB+ hybrid public key).
        - `signed_prekey`: JSONB (Contains keyId, raw publicKey, and signature).
        - `onetime_prekeys`: JSONB (Map of ID to raw public keys). Using JSONB is still okay for the map structure, but we will store binary-friendly strings or hex.
    - Update `profiles` table:
        - Add `encrypted_pqa_identity` (TEXT/BYTEA) to store the user's encrypted master key backup.
- **`supabase/master_migration.sql`**:
    - Append the new table definition and Row Level Security (RLS) policies to the master script.

---

## 3. Flutter App (Dart & FFI)
We need to bridge the Rust library into Flutter and replace the `SignalService`.

### Changes:
- **`lib/core/crypto/pq_aura_bridge.dart`** (New File):
    - Use `dart:ffi` to map the Rust functions.
    - Handle memory management (allocating/freeing buffers for the large PQ keys).
- **`lib/features/messages/data/pq_aura/pq_aura_store.dart`** (New File):
    - Implementation of a persistent store using `flutter_secure_storage`.
    - Store the `RatchetState` blob for each conversation.
- **`lib/features/messages/data/pq_aura/pq_aura_service.dart`** (New File):
    - High-level API: `init()`, `encryptMessage()`, `decryptMessage()`.
    - Support for "Key Export": Encrypting media AES keys using the PQA session.
- **`lib/features/messages/presentation/providers/chat_provider.dart`**:
    - Update the message sending logic:
        - Check if PQ-Aura session exists.
        - If yes, use `PQAuraService` for the text payload.
        - **Critical:** Use the PQA session to encrypt the media's AES keys instead of RSA.

---

## 4. Build & Deployment
... (rest of Section 4) ...

---

## 5. Verification & Testing
... (rest of Section 5) ...

---

## 6. Flutter Implementation Details (Text & Media)

### A. Text Messages
- **Sender:** The `PQAuraService` will take the plaintext and the remote user's ID. It will return a `PQAMessage` containing a `header` and `payload_ciphertext`.
- **Recipient:** The recipient receives the `PQAMessage`, loads the `RatchetState` from local storage, and decrypts it via FFI.

### B. Media Attachments (Images, Videos, Docs)
Currently, media uses RSA to encrypt the AES key. This is NOT quantum-resistant.
- **New Flow:** 
    1.  Generate a random 32-byte AES-GCM-SIV key for the file.
    2.  Encrypt the file bytes using this key (in Dart or via FFI).
    3.  **Instead of RSA**, use the `PQ-Aura` Double Ratchet session to encrypt the 32-byte AES key.
    4.  Upload the encrypted file to R2.
    5.  Send the `PQ-Aura` encrypted key in the `encrypted_keys` field of the message.
- **Benefit:** The media content becomes as secure as the chat itself—fully post-quantum resistant.

### C. Multi-Device & Fallback
- **Self-Sync:** The "signalSenderContent" (used to see your own messages on other devices) currently uses RSA. We will update this to use a "Private PQ-Sync" where your own devices share a PQ-Aura session.
- **Legacy Fallback:** If the recipient doesn't have `pq_keys` yet, the app will fallback to the existing Signal/RSA flow but mark the message as "Classic Security" in the UI.

---

## Migration Strategy
... (rest of Migration Strategy) ...
