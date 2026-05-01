# Security Audit Report: Oasis Flutter & Supabase

**Date:** May 1, 2026
**Status:** REMEDIATED (Phase 1)
**Severity Scale:** Critical, High, Medium, Low, Informational

---

## Executive Summary
A comprehensive security audit of the Oasis codebase was performed. Critical and High-severity vulnerabilities related to user impersonation, metadata leaks, and unprotected service endpoints have been successfully remediated on the `pre-release` branch. Payment webhook verification remains a pending task for future implementation once payments are active.

---

## 1. Critical Vulnerabilities

### 1.1. User Impersonation via `send_message_v3`
- **Status:** ✅ RESOLVED
- **Remediation:** Removed `p_sender_id` parameter. The function now uses `auth.uid()` to strictly identify the sender. Added rate limiting (1 msg/sec).
- **Migration:** `supabase/migrations/20260501000000_security_hardening_rpc.sql`

### 1.2. Unverified Payment Webhooks (Financial Fraud)
- **Status:** ⏳ PENDING (Deferred by User)
- **Description:** Webhooks for Razorpay and RevenueCat lack signature verification.
- **Risk:** High (Potential for free Pro status).
- **Plan:** Implement HMAC verification before enabling production payments.

---

## 2. High Severity Vulnerabilities

### 2.1. Unprotected Edge Functions (Service Abuse)
- **Status:** ✅ RESOLVED
- **Remediation:** Implemented Supabase JWT authentication in `push-notifications` and `transcribe-voice`. The functions now verify the caller's identity via `supabase.auth.getUser()`.
- **Files:**
    - `supabase/functions/push-notifications/index.ts`
    - `supabase/functions/transcribe-voice/index.ts`

### 2.2. Unauthorized Metadata Access via `get_user_conversations_v2`
- **Status:** ✅ RESOLVED
- **Remediation:** Removed `p_user_id` parameter. The function now strictly returns conversations where `auth.uid()` is a participant.
- **Migration:** `supabase/migrations/20260501000000_security_hardening_rpc.sql`

---

## 3. Medium Severity Vulnerabilities

### 3.1. Lack of Rate Limiting
- **Status:** ✅ RESOLVED
- **Remediation:** Implemented a global `rate_limits` system. 
    - Added `check_rate_limit` (authenticated) and `check_rate_limit_anon` (unauthenticated).
    - Applied throttling to `send_message_v3` and `get_email_by_username`.
- **Migration:** `supabase/migrations/20260501000001_harden_signin_and_ratelimit.sql`

### 3.2. Unauthorized XP Inflation
- **Status:** ✅ RESOLVED
- **Remediation:** Hardened `increment_xp` to only update the authenticated user's profile and capped the maximum XP boost to 100 per call.
- **Migration:** `supabase/migrations/20260501000000_security_hardening_rpc.sql`

---

## 4. Low & Informational Findings

### 4.1. Email Harvesting (Sign-in w/ Username)
- **Status:** ✅ MITIGATED
- **Remediation:** Added rate limiting (3 lookups per minute per username) to the `get_email_by_username` RPC to slow down harvesting attempts while maintaining the "Sign in with Username" feature.

---

## Conclusion
The Oasis backend is now significantly more resilient against logic injection and impersonation attacks. The use of `SECURITY DEFINER` functions has been audited and secured with internal `auth.uid()` checks.
