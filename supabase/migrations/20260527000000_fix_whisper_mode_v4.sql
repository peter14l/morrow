-- =====================================================
-- FIX: WHISPER MODE / VANISHING MESSAGES LOGIC (V4)
-- =====================================================

-- 1. Corrected cleanup function for vanish mode
-- This function now respects ephemeral_duration.
-- If duration is 0 (Instant), it deletes immediately after being read.
-- If duration is > 0 (e.g. 86400), it waits for that many seconds after read_at.
CREATE OR REPLACE FUNCTION public.cleanup_vanish_mode_messages(p_conversation_id UUID)
RETURNS void AS $$
BEGIN
    DELETE FROM public.messages m
    WHERE m.conversation_id = p_conversation_id
      AND m.is_ephemeral = true
      AND EXISTS (
          SELECT 1 FROM public.message_read_receipts r
          WHERE r.message_id = m.id
          AND r.user_id != m.sender_id -- Must be read by someone other than the sender
          AND (
            m.ephemeral_duration = 0 -- Instant vanish
            OR
            r.read_at + (m.ephemeral_duration || ' seconds')::INTERVAL <= NOW() -- Timed vanish
          )
      );
END;
$$ LANGUAGE plpgsql;

-- 2. Trigger function to set message expiration upon reading
-- This provides a "source of truth" for all clients.
CREATE OR REPLACE FUNCTION public.set_message_expiration()
RETURNS TRIGGER AS $$
DECLARE
    v_ephemeral BOOLEAN;
    v_duration INTEGER;
    v_sender_id UUID;
BEGIN
    -- Get message details
    SELECT is_ephemeral, ephemeral_duration, sender_id 
    INTO v_ephemeral, v_duration, v_sender_id
    FROM public.messages
    WHERE id = NEW.message_id;

    -- Only set expiration if the message is ephemeral AND the reader is NOT the sender
    IF v_ephemeral = true AND NEW.user_id != v_sender_id THEN
        UPDATE public.messages
        SET expires_at = NEW.read_at + (v_duration || ' seconds')::INTERVAL
        WHERE id = NEW.message_id
          AND (expires_at IS NULL OR expires_at > NEW.read_at + (v_duration || ' seconds')::INTERVAL);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Re-apply the trigger to message_read_receipts
DROP TRIGGER IF EXISTS trigger_set_message_expiration ON public.message_read_receipts;
CREATE TRIGGER trigger_set_message_expiration
    AFTER INSERT OR UPDATE ON public.message_read_receipts
    FOR EACH ROW
    EXECUTE FUNCTION public.set_message_expiration();

-- 4. Create an index to optimize the cleanup query
CREATE INDEX IF NOT EXISTS idx_messages_is_ephemeral_conv 
ON public.messages(conversation_id, is_ephemeral) 
WHERE is_ephemeral = true;