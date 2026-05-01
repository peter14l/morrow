# Implementation Plan: Security Hardening (Oasis)

This plan outlines the steps to remediate identified security vulnerabilities in the Oasis backend (Supabase RPCs and Edge Functions).

## Phase 1: RPC Hardening (Logic Injection & Impersonation)

### 1.1. Fix `send_message_v3` Impersonation
- **Task:** Modify the function signature and body to remove the `p_sender_id` parameter and use `auth.uid()` directly.
- **File:** `supabase/migrations/20260429000000_send_message_v3.sql` (and any newer overrides).
- **Verification:** Attempt to call RPC with a forged sender ID from a test client.

### 1.2. Fix `get_user_conversations_v2` Metadata Leak
- **Task:** Modify the function to remove `p_user_id` and use `auth.uid()`.
- **File:** `supabase/migrations/20260421000000_scalability_optimizations.sql`.
- **Verification:** Ensure users can still see their own conversations but cannot fetch others'.

### 1.3. Secure `increment_xp`
- **Task:** Restrict this function. Since XP should only be granted for specific actions (like posting), we will check if the caller is authorized or move the logic to an internal trigger that cannot be called via RPC.
- **Strategy:** If kept as RPC, verify `auth.uid()` and perhaps add a server-side cooldown.

## Phase 2: Edge Function Authentication

### 2.1. Authenticate `push-notifications`
- **Task:** 
    - Extract JWT from `Authorization` header.
    - Use `supabase.auth.getUser(jwt)` to verify identity.
    - Verify that the sender (`actor_id`) in the payload matches the authenticated user.
- **File:** `supabase/functions/push-notifications/index.ts`.

### 2.2. Authenticate `transcribe-voice`
- **Task:**
    - Verify JWT.
    - Check if the authenticated user is the sender of the `message_id` being transcribed.
- **File:** `supabase/functions/transcribe-voice/index.ts`.

## Phase 3: Rate Limiting Mechanism

### 3.1. Database-Level Rate Limiting
- **Task:** Create a `request_logs` table and a `check_rate_limit` PL/pgSQL function.
- **Schema:**
    ```sql
    CREATE TABLE public.rate_limits (
        user_id UUID REFERENCES auth.users(id),
        action TEXT,
        last_request TIMESTAMPTZ,
        request_count INT,
        PRIMARY KEY (user_id, action)
    );
    ```
- **Integration:** Call `check_rate_limit(auth.uid(), 'send_message')` inside `send_message_v3`.

## Phase 4: Frontend Alignment
- **Task:** Update Flutter services to stop sending the redundant/insecure parameters (`sender_id`, `user_id`) to the hardened RPCs.
- **Files:**
    - `lib/services/chat_messaging_service.dart`
    - `lib/services/notification_manager.dart`
    - `lib/features/messages/data/message_operations_service.dart` (if applicable)

## Verification
- Run existing integration tests (`integration_test/e2ee_flow_test.dart`).
- Perform manual "Attack Scenarios" via Supabase Dashboard / Postman.
