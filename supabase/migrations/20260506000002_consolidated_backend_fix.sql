-- FIX: Infinite recursion on profiles and circle persistence issues
-- Migration created on 2025-01-24

-- 1. Consolidate Profiles UPDATE policies to prevent recursion and security holes
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own encryption keys" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile except pro status" ON public.profiles;

CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
    auth.uid() = id 
    AND (
        -- Protect is_pro status from being changed by the user
        is_pro = public.check_is_pro_status(id)
    )
);

-- 2. Ensure all trigger functions that update other tables are SECURITY DEFINER
CREATE OR REPLACE FUNCTION increment_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.comments
    SET likes_count = likes_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION decrement_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.comments
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = OLD.comment_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION increment_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET followers_count = followers_count + 1
    WHERE id = NEW.following_id;
    
    UPDATE public.profiles
    SET following_count = following_count + 1
    WHERE id = NEW.follower_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION decrement_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET followers_count = GREATEST(0, followers_count - 1)
    WHERE id = OLD.following_id;
    
    UPDATE public.profiles
    SET following_count = GREATEST(0, following_count - 1)
    WHERE id = OLD.follower_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION increment_user_posts_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET posts_count = posts_count + 1
    WHERE id = NEW.user_id;
    
    IF NEW.community_id IS NOT NULL THEN
        UPDATE public.communities
        SET posts_count = posts_count + 1
        WHERE id = NEW.community_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION decrement_user_posts_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET posts_count = GREATEST(0, posts_count - 1)
    WHERE id = OLD.user_id;
    
    IF OLD.community_id IS NOT NULL THEN
        UPDATE public.communities
        SET posts_count = GREATEST(0, posts_count - 1)
        WHERE id = OLD.community_id;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION increment_community_members_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.communities
    SET members_count = members_count + 1
    WHERE id = NEW.community_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION decrement_community_members_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.communities
    SET members_count = GREATEST(0, members_count - 1)
    WHERE id = OLD.community_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Verify/Ensure Circles DELETE policies are correct
DROP POLICY IF EXISTS "Creators can delete their own circles" ON public.circles;
CREATE POLICY "Creators can delete their own circles" 
ON public.circles FOR DELETE 
USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "Users can leave circles" ON public.circle_members;
CREATE POLICY "Users can leave circles" 
ON public.circle_members FOR DELETE 
USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.circles WHERE id = circle_id AND created_by = auth.uid()));
