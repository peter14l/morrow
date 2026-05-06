-- Security Hardening: Phase 2 (Column-Level RLS & Privacy)
-- Date: May 6, 2026

-- 1. ENFORCE COLUMN-LEVEL SECURITY ON PROFILES
-- We revoke all public/authenticated access and explicitly grant back only non-sensitive columns.
REVOKE SELECT ON TABLE public.profiles FROM anon, authenticated;

-- Grant access to public/non-sensitive fields
GRANT SELECT (
    id, 
    username, 
    full_name, 
    avatar_url, 
    bio, 
    location, 
    website, 
    is_verified, 
    is_private, 
    followers_count, 
    following_count, 
    posts_count, 
    is_pro, 
    created_at, 
    xp
) ON TABLE public.profiles TO anon, authenticated;

-- Note: encrypted_private_key, encrypted_private_key_v2, encrypted_private_key_recovery, and key_salt 
-- are now strictly restricted to SERVICE_ROLE or the owner (via separate policies if needed).
-- However, standard SELECT * will now fail for normal users.

-- 2. MASK EMAIL RECOVERY
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT AS $$
DECLARE
    v_email TEXT;
BEGIN
    -- Rate limit lookups for a specific username
    PERFORM public.check_rate_limit_anon('lookup_' || p_username, 3, '1 minute');

    SELECT email INTO v_email FROM public.profiles WHERE username = p_username;
    
    IF v_email IS NULL THEN
        RETURN NULL;
    END IF;

    -- Return masked email (e.g., sh***@gmail.com)
    RETURN SUBSTRING(v_email FROM 1 FOR 2) || '***' || SUBSTRING(v_email FROM POSITION('@' IN v_email));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. IP-BASED RATE LIMITING
-- Update the rate limiting functions to include IP tracking.
CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_user_id UUID,
    p_action TEXT,
    p_max_requests INT,
    p_interval INTERVAL
)
RETURNS VOID AS $$
DECLARE
    v_ip TEXT := current_setting('request.headers', true)::json->>'x-forwarded-for';
    v_identifier TEXT := COALESCE(v_ip, 'unknown') || '_' || p_user_id::text || '_' || p_action;
    v_current_count INT;
BEGIN
    INSERT INTO public.rate_limits (identifier, last_request, request_count)
    VALUES (v_identifier, NOW(), 1)
    ON CONFLICT (identifier) DO UPDATE
    SET 
        request_count = CASE 
            WHEN rate_limits.last_request < NOW() - p_interval THEN 1
            ELSE rate_limits.request_count + 1
        END,
        last_request = CASE 
            WHEN rate_limits.last_request < NOW() - p_interval THEN NOW()
            ELSE rate_limits.last_request
        END
    RETURNING request_count INTO v_current_count;

    IF v_current_count > p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded for action: %', p_action;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.check_rate_limit_anon(
    p_action_key TEXT,
    p_max_requests INT,
    p_interval INTERVAL
)
RETURNS VOID AS $$
DECLARE
    v_ip TEXT := current_setting('request.headers', true)::json->>'x-forwarded-for';
    v_identifier TEXT := COALESCE(v_ip, 'unknown') || '_' || p_action_key;
    v_current_count INT;
BEGIN
    INSERT INTO public.rate_limits (identifier, last_request, request_count)
    VALUES (v_identifier, NOW(), 1)
    ON CONFLICT (identifier) DO UPDATE
    SET 
        request_count = CASE 
            WHEN rate_limits.last_request < NOW() - p_interval THEN 1
            ELSE rate_limits.request_count + 1
        END,
        last_request = CASE 
            WHEN rate_limits.last_request < NOW() - p_interval THEN NOW()
            ELSE rate_limits.last_request
        END
    RETURNING request_count INTO v_current_count;

    IF v_current_count > p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded. Please try again later.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
