-- Fix: Unread message counter not updating in real-time
--
-- Root cause: conversation_participants table was never added to the
-- supabase_realtime publication, so onPostgresChanges subscriptions
-- on this table never fire. Additionally, REPLICA IDENTITY FULL was
-- never set, so DELETE events would have incomplete payloads.

-- 1. Enable REPLICA IDENTITY FULL so realtime payloads include all columns
ALTER TABLE public.conversation_participants REPLICA IDENTITY FULL;

-- 2. Add to realtime publication so Postgres changes are broadcast
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;

-- 3. Also ensure messages table is in the publication (needed by
--    get_user_conversations_v2 which calculates unread dynamically)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'messages'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END
$$;

-- 4. Ensure conversations table is in the publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
    AND tablename = 'conversations'
    AND schemaname = 'public'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  END IF;
END
$$;
