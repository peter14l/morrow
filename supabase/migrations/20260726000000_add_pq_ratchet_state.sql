-- PQ-Aura Server-Side Ratchet State
-- Stores encrypted ratchet state for web clients that can't persist state locally.
-- The state is encrypted with a per-session key derived from the user's auth.

CREATE TABLE IF NOT EXISTS pq_ratchet_state (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  peer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_state BYTEA NOT NULL,
  state_nonce BYTEA NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, peer_id)
);

-- Index for fast lookups by user + peer
CREATE INDEX IF NOT EXISTS idx_pq_ratchet_state_lookup
  ON pq_ratchet_state(user_id, peer_id);

-- RLS policies: users can only read/write their own ratchet state
ALTER TABLE pq_ratchet_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own ratchet state"
  ON pq_ratchet_state FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own ratchet state"
  ON pq_ratchet_state FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own ratchet state"
  ON pq_ratchet_state FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own ratchet state"
  ON pq_ratchet_state FOR DELETE
  USING (auth.uid() = user_id);

-- RPC function to upsert ratchet state (atomic)
CREATE OR REPLACE FUNCTION upsert_pq_ratchet_state(
  p_user_id UUID,
  p_peer_id UUID,
  p_encrypted_state BYTEA,
  p_state_nonce BYTEA
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO pq_ratchet_state (user_id, peer_id, encrypted_state, state_nonce)
  VALUES (p_user_id, p_peer_id, p_encrypted_state, p_state_nonce)
  ON CONFLICT (user_id, peer_id)
  DO UPDATE SET
    encrypted_state = EXCLUDED.encrypted_state,
    state_nonce = EXCLUDED.state_nonce,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC function to get ratchet state
CREATE OR REPLACE FUNCTION get_pq_ratchet_state(
  p_user_id UUID,
  p_peer_id UUID
)
RETURNS TABLE(encrypted_state BYTEA, state_nonce BYTEA) AS $$
BEGIN
  RETURN QUERY
  SELECT s.encrypted_state, s.state_nonce
  FROM pq_ratchet_state s
  WHERE s.user_id = p_user_id AND s.peer_id = p_peer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
