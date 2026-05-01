-- Security Hardening: Phase 1.1 (Sign-in & Rate Limit Refactor)
-- Date: May 1, 2026

-- 1. Refactor Rate Limiting Table
-- We switch from (user_id, action) to a generic (identifier) to support anonymous actions.
DROP TABLE IF EXISTS public.rate_limits;
CREATE TABLE public.rate_limits (
    identifier TEXT PRIMARY KEY, -- format: 'user_uuid_action' or 'anon_action_key'
    last_request TIMESTAMPTZ DEFAULT NOW(),
    request_count INT DEFAULT 1
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
-- Note: No policies added. Table is managed via SECURITY DEFINER functions only.

-- 2. Refactor check_rate_limit for Authenticated Users
CREATE OR REPLACE FUNCTION public.check_rate_limit(
    p_user_id UUID,
    p_action TEXT,
    p_max_requests INT,
    p_interval INTERVAL
)
RETURNS VOID AS $$
DECLARE
    v_identifier TEXT := p_user_id::text || '_' || p_action;
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

-- 3. Create check_rate_limit_anon for Anonymous Actions
CREATE OR REPLACE FUNCTION public.check_rate_limit_anon(
    p_action_key TEXT,
    p_max_requests INT,
    p_interval INTERVAL
)
RETURNS VOID AS $$
DECLARE
    v_current_count INT;
BEGIN
    INSERT INTO public.rate_limits (identifier, last_request, request_count)
    VALUES (p_action_key, NOW(), 1)
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

-- 4. Harden get_email_by_username (Prevent Email Harvesting)
CREATE OR REPLACE FUNCTION public.get_email_by_username(p_username TEXT)
RETURNS TEXT AS $$
DECLARE
    v_email TEXT;
BEGIN
    -- Rate limit lookups for a specific username to 3 per minute
    PERFORM public.check_rate_limit_anon('lookup_' || p_username, 3, '1 minute');

    SELECT email INTO v_email FROM public.profiles WHERE username = p_username;
    RETURN v_email;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ensure the function is accessible to anon and authenticated users
GRANT EXECUTE ON FUNCTION public.get_email_by_username(TEXT) TO anon, authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
