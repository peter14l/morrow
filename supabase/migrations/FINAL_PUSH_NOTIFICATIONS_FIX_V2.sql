-- =====================================================
-- FINAL PUSH NOTIFICATIONS FIX (GATEWAY BYPASS VERSION)
-- =====================================================
-- 1. Ensure the HTTP extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Define/Update the trigger function
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
  -- A. GET PROJECT REFERENCE
  SELECT value INTO v_project_ref FROM public.metadata WHERE key = 'supabase_project_ref';
  
  -- B. CONSTRUCT URL
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    RAISE WARNING 'Push notification trigger failed: supabase_project_ref missing from metadata table';
    RETURN NEW;
  END IF;

  v_url := 'https://' || v_project_ref || '.supabase.co/functions/v1/push-notifications';

  -- C. STRICT KEY SELECTION
  -- Priority: Publishable Key -> Secret Key -> Short Anon Key
  SELECT value INTO v_auth_key 
  FROM public.metadata 
  WHERE key IN ('supabase_publishable_key', 'supabase_secret_key')
     OR (key = 'supabase_anon_key' AND length(value) < 100)
  ORDER BY (CASE WHEN key = 'supabase_publishable_key' THEN 1 
                 WHEN key = 'supabase_secret_key' THEN 2 
                 ELSE 3 END)
  LIMIT 1;

  -- D. BUILD E2EE METADATA PAYLOAD
  SELECT jsonb_build_object(
    'encrypted_keys', encrypted_keys,
    'iv', iv,
    'signal_message_type', signal_message_type,
    'signal_sender_content', signal_sender_content,
    'conversation_id', conversation_id
  ) INTO v_metadata
  FROM public.messages
  WHERE id = NEW.message_id;

  -- E. CONSTRUCT FINAL PAYLOAD
  v_payload := jsonb_build_object(
    'record', row_to_json(NEW),
    'metadata', v_metadata
  );

  -- F. EXECUTE ASYNC HTTP REQUEST
  -- IMPORTANT: We send both 'apikey' and 'Authorization' headers.
  -- This allows the request to pass through the Supabase Gateway (Kong) 
  -- when using static keys instead of JWTs.
  PERFORM
    net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', COALESCE(v_auth_key, 'missing-key'),
        'Authorization', 'Bearer ' || COALESCE(v_auth_key, 'missing-key')
      ),
      body := v_payload
    );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification trigger critical exception: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-attach the trigger to the notifications table
DROP TRIGGER IF EXISTS trigger_notify_push_service ON public.notifications;
CREATE TRIGGER trigger_notify_push_service
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_service();
