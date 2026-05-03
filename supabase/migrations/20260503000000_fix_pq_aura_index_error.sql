-- Migration: Fix index row size error for PQ-Aura headers
-- Date: 2026-05-03
-- Purpose: Remove the B-tree index on pq_aura_header which causes errors when headers exceed 8KB

-- 1. Remove the problematic index
DROP INDEX IF EXISTS public.idx_messages_pq_aura_header;

-- 2. Refresh schema cache
NOTIFY pgrst, 'reload schema';
