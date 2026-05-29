-- Migration: Add Microtransactions Monetization Schema
-- Date: 2026-05-29

-- 1. Add boost_tokens column to public.profiles if not exists
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS boost_tokens INTEGER DEFAULT 0;

-- 2. Create User Customizations Table
CREATE TABLE IF NOT EXISTS public.user_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL, -- 'profile_theme', 'avatar_frame', 'haptic_pack'
    item_id VARCHAR(100) NOT NULL,  -- e.g. 'theme_cyberpunk', 'theme_e_ink'
    is_active BOOLEAN DEFAULT false,
    purchased_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, item_type, item_id)
);

-- 3. Create Circle Boosting Table
CREATE TABLE IF NOT EXISTS public.circle_boosts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id UUID REFERENCES public.circles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    boosted_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    expires_at TIMESTAMP WITH TIME ZONE -- NULL if lifetime/unlimited
);

-- 4. Create First-Party Ad Campaigns Table
CREATE TABLE IF NOT EXISTS public.ad_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    banner_url TEXT NOT NULL,
    destination_url TEXT NOT NULL,
    category_target VARCHAR(100) NOT NULL, -- 'wellness', 'productivity', 'tech'
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.user_customizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_campaigns ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies

-- User Customizations Policies
CREATE POLICY "Users can view their own customizations" ON public.user_customizations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update their customizations" ON public.user_customizations
    FOR ALL USING (auth.uid() = user_id);

-- Circle Boosts Policies
CREATE POLICY "Anyone can view circle boosts" ON public.circle_boosts
    FOR SELECT USING (true);

CREATE POLICY "Users can manage their own boosts" ON public.circle_boosts
    FOR ALL USING (auth.uid() = user_id);

-- Ad Campaigns Policies
CREATE POLICY "Anyone can view active ad campaigns" ON public.ad_campaigns
    FOR SELECT USING (is_active = true AND now() BETWEEN start_date AND end_date);

-- 7. RPC function to increment user boosts
CREATE OR REPLACE FUNCTION public.increment_user_boosts(user_id UUID, boost_count INT)
RETURNS VOID AS $$
BEGIN
    UPDATE public.profiles
    SET boost_tokens = COALESCE(boost_tokens, 0) + boost_count
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
