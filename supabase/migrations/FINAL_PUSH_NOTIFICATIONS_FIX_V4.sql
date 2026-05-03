-- =====================================================
-- FINAL PUSH NOTIFICATIONS FIX (X-OASIS-KEY VERSION)
-- =====================================================
-- Description: This version uses a custom header (X-Oasis-Key) for our 
-- modern key to bypass Gateway JWT validation, while keeping the standard
-- Authorization header with the anon JWT to satisfy the gateway itself.

CREATE OR REPLACE FUNCTION public.notify_push_service()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payload JSONB;
  v_project_ref TEXT;
  v_modern_key TEXT;
  v_anon_jwt TEXT;
  v_url TEXT;
  v_metadata JSONB;
BEGIN
  -- 1. Get Project Ref
  SELECT value INTO v_project_ref FROM public.metadata WHERE key = 'supabase_project_ref';
  
  -- 2. Get Modern Key (Short, for our internal check)
  SELECT value INTO v_modern_key 
  FROM public.metadata 
  WHERE key IN ('supabase_publishable_key', 'supabase_secret_key')
  ORDER BY (CASE WHEN key = 'supabase_publishable_key' THEN 1 ELSE 2 END)
  LIMIT 1;

  -- 3. Get Anon JWT (Long, for the Supabase Gateway Kong)
  SELECT value INTO v_anon_jwt 
  FROM public.metadata 
  WHERE key = 'supabase_anon_key' AND length(value) > 100
  LIMIT 1;

  -- 4. Validation
  IF v_project_ref IS NULL OR v_project_ref = '' THEN
    RAISE WARNING 'Push notification trigger failed: supabase_project_ref missing';
    RETURN NEW;
  END IF;

  v_url := 'https://' || v_project_ref || '.supabase.co/functions/v1/push-notifications';

  -- 5. Build E2EE metadata payload
  SELECT jsonb_build_object(
    'encrypted_keys', encrypted_keys,
    'iv', iv,
    'signal_message_type', signal_message_type,
    'signal_sender_content', signal_sender_content,
    'conversation_id', conversation_id
  ) INTO v_metadata
  FROM public.messages WHERE id = NEW.message_id;

  v_payload := jsonb_build_object('record', row_to_json(NEW), 'metadata', v_metadata);

  -- 6. EXECUTE ASYNC HTTP REQUEST
  -- We use the anon JWT for 'Authorization' so Kong (Gateway) lets it through.
  -- We use the modern key for 'X-Oasis-Key' so our code can verify it without Kong interfering.
  PERFORM
    net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', COALESCE(v_anon_jwt, v_modern_key),
        'Authorization', 'Bearer ' || COALESCE(v_anon_jwt, v_modern_key),
        'X-Oasis-Key', COALESCE(v_modern_key, v_anon_jwt)
      ),
      body := v_payload
    );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification trigger critical exception: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-attach trigger
DROP TRIGGER IF EXISTS trigger_notify_push_service ON public.notifications;
CREATE TRIGGER trigger_notify_push_service
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_service();
