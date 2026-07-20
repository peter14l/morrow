-- Fix: Call notifications never sent for backgrounded users
--
-- Root cause: The V2 calling migration (20260422) dropped the
-- call_participants table, which had the handle_call_notification()
-- trigger. No replacement trigger was added to the calls table,
-- so incoming calls never trigger push notifications.

-- 0. Ensure REPLICA IDENTITY FULL on calls for complete realtime payloads
ALTER TABLE public.calls REPLICA IDENTITY FULL;

-- 1. Create the trigger function that inserts a notification record
--    for incoming calls. The existing notify_push_service() trigger
--    on the notifications table will then fire the push-notifications
--    edge function, which sends the FCM push to the callee.
CREATE OR REPLACE FUNCTION public.handle_call_insert_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify for ringing calls (not answered/ended/missed)
  IF NEW.status = 'ringing' THEN
    INSERT INTO public.notifications (
      user_id,
      type,
      actor_id,
      content,
      read
    ) VALUES (
      NEW.receiver_id,
      'call',
      NEW.caller_id,
      jsonb_build_object(
        'call_id', NEW.id,
        'type', NEW.type,
        'conversation_id', NEW.conversation_id
      )::text,
      false
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger on the calls table
DROP TRIGGER IF EXISTS trigger_handle_call_insert_notification ON public.calls;
CREATE TRIGGER trigger_handle_call_insert_notification
  AFTER INSERT ON public.calls
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_call_insert_notification();
