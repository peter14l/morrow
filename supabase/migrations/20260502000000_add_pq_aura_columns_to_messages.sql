-- Migration: Add PQ-Aura columns to messages table
-- Date: 2026-05-02
-- Purpose: Add columns for storing post-quantum encryption metadata in messages

-- 1. Add columns to messages table if they don't exist
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS pq_aura_header TEXT,
ADD COLUMN IF NOT EXISTS pq_aura_payload TEXT;

-- 2. Add indexes for faster retrieval
CREATE INDEX IF NOT EXISTS idx_messages_pq_aura_header ON public.messages(pq_aura_header) WHERE pq_aura_header IS NOT NULL;

-- 3. Update comments
COMMENT ON COLUMN public.messages.pq_aura_header IS 'Post-quantum encryption header for PQ-Aura protocol';
COMMENT ON COLUMN public.messages.pq_aura_payload IS 'Post-quantum encrypted payload for PQ-Aura protocol';

-- 4. Refresh schema cache
NOTIFY pgrst, 'reload schema';
