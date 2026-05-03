-- =====================================================
-- UPDATE PUSH NOTIFICATIONS TO USE MODERN KEYS (ROBUST)
-- =====================================================
-- Description: Updates the notify_push_service function to authenticate
-- with the Edge Function using ONLY modern publishable/secret keys.
-- Ensures pg_net is enabled and handles missing metadata gracefully.

-- 1. Ensure the HTTP extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Re-declare the trigger function
CREATE OR REPLACE FUNCTION public.notify_push_service()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payload JSONB;
  v_project_ref TEXT;
  v_auth_key TEXT;
  v_url TEXT;
  v_metadata JSONB;
BEGIN
  -- 1. Get project reference
  SELECT value INTO v_project_ref FROM public.metadata WHERE key = 'supabase_project_ref';

  -- 2. Construct the URL
  IF v_project_ref IS NOT NULL AND v_project_ref != '' THEN
      v_url := 'https://' || v_project_ref || '.supabase.co/functions/v1/push-notifications';
  ELSE
      v_url := 'http://host.docker.internal:54321/functions/v1/push-notifications';
  END IF;

  -- 3. STRICT KEY SELECTION:
  -- We specifically look for the new short-form keys.
  -- We avoid the 208-character JWT at all costs.
  
  -- Try Publishable Key
  SELECT value INTO v_auth_key FROM public.metadata WHERE key = 'supabase_publishable_key' LIMIT 1;
  
  -- Try Secret Key if Publishable not found
  IF v_auth_key IS NULL THEN
    SELECT value INTO v_auth_key FROM public.metadata WHERE key = 'supabase_secret_key' LIMIT 1;
  END IF;

  -- Try Anon Key only if it's a short string (not a JWT)
  IF v_auth_key IS NULL THEN
    SELECT value INTO v_auth_key FROM public.metadata 
    WHERE key = 'supabase_anon_key' AND length(value) < 100 
    LIMIT 1;
  END IF;

  -- 4. Build the E2EE metadata payload
  -- We use a subquery to avoid crashing if the message is missing
  SELECT jsonb_build_object(
    'encrypted_keys', encrypted_keys,
    'iv', iv,
    'signal_message_type', signal_message_type,
    'signal_sender_content', signal_sender_content,
    'conversation_id', conversation_id
  ) INTO v_metadata
  FROM public.messages
  WHERE id = NEW.message_id;

  -- Construct final payload
  v_payload := jsonb_build_object(
    'record', row_to_json(NEW),
    'metadata', v_metadata
  );

  -- 5. Perform the async HTTP request
  PERFORM
    net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || COALESCE(v_auth_key, 'missing-key')
      ),
      body := v_payload
    );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error to Postgres stats but don't fail the insert
  RAISE WARNING 'Push notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Ensure trigger is attached
DROP TRIGGER IF EXISTS trigger_notify_push_service ON public.notifications;
CREATE TRIGGER trigger_notify_push_service
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_service();
