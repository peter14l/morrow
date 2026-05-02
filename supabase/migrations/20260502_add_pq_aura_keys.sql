-- Migration: Add PQ-Aura Post-Quantum Keys Table
-- Date: 2026-05-02
-- Purpose: Store hybrid X25519 + ML-KEM-1024 pre-key bundles for post-quantum E2EE

-- ============================================================================
-- Table: pq_keys
-- ============================================================================

CREATE TABLE IF NOT EXISTS pq_keys (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Identity public key (hybrid: 32 bytes X25519 + 1568 bytes ML-KEM-1024 = ~1600 bytes)
    -- Stored as base64 for JSON compatibility
    identity_pk TEXT NOT NULL,
    
    -- Pre-key bundle (JSON)
    bundle JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    -- Timestamp for key rotation
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Key version for rotation support
    key_version INTEGER NOT NULL DEFAULT 1
);

-- ============================================================================
-- Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_pq_keys_user_id ON pq_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_pq_keys_updated_at ON pq_keys(updated_at);

-- ============================================================================
-- Row Level Security (RLS)
-- ============================================================================

ALTER TABLE pq_keys ENABLE ROW LEVEL SECURITY;

-- Users can read their own keys
CREATE POLICY "Users can read own pq_keys"
    ON pq_keys FOR SELECT
    USING (auth.uid() = user_id);

-- Users can insert their own keys
CREATE POLICY "Users can insert own pq_keys"
    ON pq_keys FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own keys
CREATE POLICY "Users can update own pq_keys"
    ON pq_keys FOR UPDATE
    USING (auth.uid() = user_id);

-- Users can delete their own keys
CREATE POLICY "Users can delete own pq_keys"
    ON pq_keys FOR DELETE
    USING (auth.uid() = user_id);

-- Anyone can read public pq_keys (bundle is public information)
CREATE POLICY "Anyone can read pq_keys bundle"
    ON pq_keys FOR SELECT
    USING (
        -- The bundle contains only public keys, not secrets
        jsonb_exists(bundle, 'identity_pk')
    );

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to check if a user has PQ keys
CREATE OR REPLACE FUNCTION user_has_pq_keys(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    key_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO key_count
    FROM pq_keys
    WHERE user_id = p_user_id;
    
    RETURN key_count > 0;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get PQ key bundle for a user
CREATE OR REPLACE FUNCTION get_pq_bundle(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    bundle_data JSONB;
BEGIN
    SELECT bundle INTO bundle_data
    FROM pq_keys
    WHERE user_id = p_user_id;
    
    RETURN bundle_data;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to upsert PQ keys (called from client)
CREATE OR REPLACE FUNCTION upsert_pq_keys(
    p_user_id UUID,
    p_identity_pk TEXT,
    p_bundle JSONB
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO pq_keys (user_id, identity_pk, bundle)
    VALUES (p_user_id, p_identity_pk, p_bundle)
    ON CONFLICT (user_id) DO UPDATE SET
        identity_pk = EXCLUDED.identity_pk,
        bundle = EXCLUDED.bundle,
        updated_at = NOW(),
        key_version = pq_keys.key_version + 1;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION user_has_pq_keys(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pq_bundle(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_pq_keys(UUID, TEXT, JSONB) TO authenticated;

-- ============================================================================
-- Update profiles table to add PQ identity backup
-- ============================================================================

-- Add encrypted PQ identity backup (mirroring signal identity backup)
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS encrypted_pqa_identity TEXT;

-- Create index for potential future queries
CREATE INDEX IF NOT EXISTS idx_profiles_pqa_identity 
ON profiles(id) 
WHERE encrypted_pqa_identity IS NOT NULL;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE pq_keys IS 'Post-Quantum Aura keys for hybrid ML-KEM-1024 + X25519 encryption';
COMMENT ON COLUMN pq_keys.identity_pk IS 'Base64-encoded hybrid public key (X25519 + ML-KEM-1024)';
COMMENT ON COLUMN pq_keys.bundle IS 'JSON object containing identity, signed pre-key, and one-time pre-keys';
COMMENT ON COLUMN pq_keys.key_version IS 'Version number for key rotation support';

-- ============================================================================
-- Migration Complete
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'PQ-Aura migration completed successfully';
END $$;