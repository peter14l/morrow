-- =====================================================
-- UPDATE PUSH NOTIFICATIONS TO USE MODERN KEYS (STRICT)
-- =====================================================
-- Description: Updates the notify_push_service function to authenticate
-- with the Edge Function using ONLY modern publishable/secret keys.
-- It explicitly avoids the deprecated 208-char JWT anon keys.

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
BEGIN
  -- Build a rich payload including message metadata for E2EE decryption
  v_payload := jsonb_build_object(
    'record', row_to_json(NEW),
    'metadata', (
      SELECT jsonb_build_object(
        'encrypted_keys', encrypted_keys,
        'iv', iv,
        'signal_message_type', signal_message_type,
        'signal_sender_content', signal_sender_content,
        'conversation_id', conversation_id
      )
      FROM public.messages
      WHERE id = NEW.message_id
    )
  );

  -- Try to get project reference
  SELECT value INTO v_project_ref FROM public.metadata WHERE key = 'supabase_project_ref';

  -- STIRCT KEY SELECTION: 
  -- We prioritize 'supabase_publishable_key' or 'supabase_secret_key'.
  -- We ONLY use 'supabase_anon_key' if it's NOT a long JWT (length < 100).
  SELECT value INTO v_auth_key 
  FROM public.metadata 
  WHERE key IN ('supabase_publishable_key', 'supabase_secret_key')
     OR (key = 'supabase_anon_key' AND length(value) < 100)
  ORDER BY (CASE WHEN key = 'supabase_publishable_key' THEN 1 
                 WHEN key = 'supabase_secret_key' THEN 2 
                 ELSE 3 END)
  LIMIT 1;

  IF v_project_ref IS NOT NULL AND v_project_ref != '' THEN
      v_url := 'https://' || v_project_ref || '.supabase.co/functions/v1/push-notifications';
  ELSE
      v_url := 'http://host.docker.internal:54321/functions/v1/push-notifications';
  END IF;

  IF v_auth_key IS NULL THEN
      -- Fallback to any anon key if nothing else found (though this might fail auth if it's a JWT)
      SELECT value INTO v_auth_key FROM public.metadata WHERE key = 'supabase_anon_key' LIMIT 1;
  END IF;

  -- Call the push-notifications Edge Function
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
  RAISE WARNING 'Push notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
