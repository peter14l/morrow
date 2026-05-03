-- =====================================================
-- UPDATE PUSH NOTIFICATIONS TO USE MODERN KEYS
-- =====================================================
-- Description: Updates the notify_push_service function to authenticate
-- with the Edge Function using modern publishable/secret keys instead of 
-- the deprecated anon key.

CREATE OR REPLACE FUNCTION public.notify_push_service()
RETURNS trigger AS $$
DECLARE
    payload JSON;
    v_project_ref TEXT;
    v_auth_key TEXT;
    v_url TEXT;
BEGIN
    -- Try to get project reference and modern keys from metadata table
    SELECT value INTO v_project_ref FROM public.metadata WHERE key = 'supabase_project_ref';
    SELECT value INTO v_auth_key FROM public.metadata WHERE key IN ('supabase_publishable_key', 'supabase_secret_key', 'supabase_anon_key', 'supabase_service_role_key') LIMIT 1;

    -- Fallback for local development or missing metadata
    IF v_project_ref IS NOT NULL AND v_project_ref != '' THEN
        v_url := 'https://' || v_project_ref || '.supabase.co/functions/v1/push-notifications';
    ELSE
        v_url := 'http://host.docker.internal:54321/functions/v1/push-notifications';
    END IF;

    IF v_auth_key IS NULL THEN
        v_auth_key := 'missing-key'; -- Prevent concatenation error, edge function will reject
    END IF;

    -- Construct the JSON payload containing the notification record
    payload := json_build_object('record', row_to_json(NEW));

    -- Perform the HTTP POST request to the Edge Function
    PERFORM net.http_post(
      url := v_url,
      headers := json_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_auth_key
      ),
      body := payload::jsonb
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log the error but don't fail the database transaction
    RAISE WARNING 'Failed to trigger push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
