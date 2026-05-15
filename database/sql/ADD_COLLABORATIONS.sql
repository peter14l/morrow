-- Migration: Add Collaborative Posts support
-- 1. Create post_collaborators table
CREATE TABLE IF NOT EXISTS public.post_collaborators (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'denied')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- 2. Add RLS Policies
ALTER TABLE public.post_collaborators ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view collaborations" ON public.post_collaborators
    FOR SELECT USING (true);

CREATE POLICY "Authors can invite collaborators" ON public.post_collaborators
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.posts WHERE id = post_id AND user_id = auth.uid())
    );

CREATE POLICY "Collaborators can update their own status" ON public.post_collaborators
    FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3. Update get_feed_posts RPC to include collaborative visibility and data
CREATE OR REPLACE FUNCTION get_feed_posts_v2(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_cursor_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    username TEXT,
    full_name TEXT,
    avatar_url TEXT,
    is_verified BOOLEAN,
    content TEXT,
    image_url TEXT,
    media_urls TEXT[],
    media_types TEXT[],
    community_id UUID,
    community_name TEXT,
    mood TEXT,
    hashtags TEXT[],
    thumbnail_url TEXT,
    dominant_color TEXT,
    likes_count INTEGER,
    comments_count INTEGER,
    shares_count INTEGER,
    created_at TIMESTAMPTZ,
    is_liked BOOLEAN,
    is_bookmarked BOOLEAN,
    circle_id UUID,
    storage_provider TEXT,
    collaborators JSONB
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.user_id,
        pr.username::TEXT,
        pr.full_name::TEXT,
        pr.avatar_url::TEXT,
        pr.is_verified,
        p.content::TEXT,
        p.image_url::TEXT,
        COALESCE(p.media_urls, ARRAY[]::TEXT[]),
        COALESCE(p.media_types, ARRAY[]::TEXT[]),
        p.community_id,
        c.name::TEXT as community_name,
        p.mood::TEXT,
        COALESCE(p.hashtags, ARRAY[]::TEXT[]),
        p.thumbnail_url::TEXT,
        p.dominant_color::TEXT,
        p.likes_count,
        p.comments_count,
        p.shares_count,
        p.created_at,
        EXISTS(SELECT 1 FROM public.likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) as is_liked,
        EXISTS(SELECT 1 FROM public.bookmarks b WHERE b.post_id = p.id AND b.user_id = p_user_id) as is_bookmarked,
        p.circle_id,
        p.storage_provider,
        (
            SELECT jsonb_agg(jsonb_build_object(
                'user_id', pc.user_id,
                'status', pc.status,
                'profiles', jsonb_build_object(
                    'username', pr2.username,
                    'avatar_url', pr2.avatar_url,
                    'is_verified', pr2.is_verified
                )
            ))
            FROM public.post_collaborators pc
            INNER JOIN public.profiles pr2 ON pc.user_id = pr2.id
            WHERE pc.post_id = p.id
        ) as collaborators
    FROM public.posts p
    INNER JOIN public.profiles pr ON p.user_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE 
        p.circle_id IS NULL AND
        (p_cursor_timestamp IS NULL OR p.created_at < p_cursor_timestamp) AND
        (
            -- Original post owner visibility
            pr.is_private = FALSE OR pr.id = p_user_id OR EXISTS (
                SELECT 1 FROM public.follows f 
                WHERE f.follower_id = p_user_id AND f.following_id = pr.id
            )
            -- OR Collaborative visibility (following an accepted collaborator)
            OR EXISTS (
                SELECT 1 FROM public.post_collaborators pc
                WHERE pc.post_id = p.id 
                AND pc.status = 'accepted'
                AND (
                    pc.user_id = p_user_id
                    OR EXISTS (
                        SELECT 1 FROM public.follows f 
                        WHERE f.follower_id = p_user_id AND f.following_id = pc.user_id
                    )
                )
            )
        )
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
