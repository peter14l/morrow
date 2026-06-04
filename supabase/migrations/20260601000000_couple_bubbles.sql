-- Migration: couple_bubbles and partner_invites
-- Created: 2026-06-01

-- ============================================================
-- TABLE: couple_bubbles
-- ============================================================
CREATE TABLE IF NOT EXISTS public.couple_bubbles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  user2_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'dissolved')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user1_id, user2_id),
  CHECK (user1_id != user2_id)
);

-- ============================================================
-- TABLE: partner_invites
-- ============================================================
CREATE TABLE IF NOT EXISTS public.partner_invites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (sender_id != receiver_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_couple_bubbles_user1_id
  ON public.couple_bubbles (user1_id);

CREATE INDEX IF NOT EXISTS idx_couple_bubbles_user2_id
  ON public.couple_bubbles (user2_id);

CREATE INDEX IF NOT EXISTS idx_partner_invites_sender_id
  ON public.partner_invites (sender_id);

CREATE INDEX IF NOT EXISTS idx_partner_invites_receiver_id
  ON public.partner_invites (receiver_id);

CREATE INDEX IF NOT EXISTS idx_partner_invites_status
  ON public.partner_invites (status);

-- ============================================================
-- UPDATED_AT TRIGGER FOR partner_invites
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_partner_invites_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_partner_invites_updated_at ON public.partner_invites;

CREATE TRIGGER trg_partner_invites_updated_at
  BEFORE UPDATE ON public.partner_invites
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_partner_invites_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY: couple_bubbles
-- ============================================================
ALTER TABLE public.couple_bubbles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "couple_bubbles_select"
  ON public.couple_bubbles
  FOR SELECT
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "couple_bubbles_insert"
  ON public.couple_bubbles
  FOR INSERT
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "couple_bubbles_update"
  ON public.couple_bubbles
  FOR UPDATE
  USING (auth.uid() = user1_id OR auth.uid() = user2_id)
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "couple_bubbles_delete"
  ON public.couple_bubbles
  FOR DELETE
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- ============================================================
-- ROW LEVEL SECURITY: partner_invites
-- ============================================================
ALTER TABLE public.partner_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "partner_invites_select"
  ON public.partner_invites
  FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "partner_invites_insert"
  ON public.partner_invites
  FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "partner_invites_update"
  ON public.partner_invites
  FOR UPDATE
  USING (auth.uid() = receiver_id OR auth.uid() = sender_id)
  WITH CHECK (auth.uid() = receiver_id OR auth.uid() = sender_id);

CREATE POLICY "partner_invites_delete"
  ON public.partner_invites
  FOR DELETE
  USING (auth.uid() = sender_id);
