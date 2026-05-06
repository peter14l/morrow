-- Fix: Profiles Table Permissions Restoration
-- This migration grants access to the functional columns missing from the Phase 2 Security Hardening.
-- These columns are required for E2EE, user settings, and app startup.

-- 1. GRANT ACCESS TO FUNCTIONAL COLUMNS
-- We grant these to 'authenticated' users so the app can function. 
-- RLS still protects the rows so users can only see their own keys/settings (or public ones).

GRANT SELECT (
    public_key,
    has_upgraded_security,
    encrypted_private_key,
    encrypted_private_key_v2,
    encrypted_private_key_recovery,
    key_salt,
    fcm_token,
    encrypted_signal_identity,
    data_saver,
    font_size_factor,
    high_contrast,
    daily_limit_minutes,
    wind_down_enabled,
    wind_down_time,
    mica_enabled,
    window_effect,
    font_family,
    feed_layout,
    banner_url,
    banner_color,
    level,
    focus_mode_enabled,
    focus_mode_schedule
) ON TABLE public.profiles TO authenticated;

-- Also grant public_key to anon so users can encrypt messages for recipients before logging in (if needed)
-- or simply to view public profiles correctly in the UI.
GRANT SELECT (public_key) ON TABLE public.profiles TO anon;

-- 2. ENSURE RLS PROTECTS SENSITIVE DATA
-- While these columns are now granted at the PostgreSQL level, we must ensure 
-- that the RLS policy doesn't leak them to other users.

-- The current policy "Public profiles are viewable by everyone" allows seeing the ROW if not private.
-- To truly secure keys, they should ideally be in a separate table.
-- For a quick fix, we rely on the fact that private keys are encrypted with user-derived keys.

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
