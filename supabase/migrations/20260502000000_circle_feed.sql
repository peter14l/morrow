-- =====================================================
-- OASIS - CIRCLE FEED IMPLEMENTATION (FIXED V2)
-- =====================================================

-- 1. ADD CIRCLE_ID TO POSTS
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS circle_id UUID REFERENCES public.circles(id) ON DELETE CASCADE;

-- 2. DROP EXISTING FUNCTIONS TO ALLOW RETURN TYPE CHANGES
DROP FUNCTION IF EXISTS get_feed_posts(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_following_feed_posts(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_circle_feed(UUID, UUID, INTEGER, INTEGER);

-- 3. RECREATE FEED RPC TO EXCLUDE CIRCLE POSTS
CREATE OR REPLACE FUNCTION get_feed_posts(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
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
    storage_provider TEXT
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
        p.storage_provider
    FROM public.posts p
    INNER JOIN public.profiles pr ON p.user_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE 
        p.circle_id IS NULL -- Exclude circle posts from main feed
        AND (pr.is_private = FALSE OR pr.id = p_user_id OR EXISTS (
            SELECT 1 FROM public.follows f 
            WHERE f.follower_id = p_user_id AND f.following_id = pr.id
        ))
    ORDER BY p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_following_feed_posts(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
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
    storage_provider TEXT
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
        p.storage_provider
    FROM public.posts p
    INNER JOIN public.profiles pr ON p.user_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE 
        p.circle_id IS NULL -- Exclude circle posts from following feed
        AND EXISTS (
            SELECT 1 FROM public.follows f 
            WHERE f.follower_id = p_user_id AND f.following_id = pr.id
        )
    ORDER BY p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. CREATE GET_CIRCLE_FEED RPC
-- FIX: Renamed parameter to in_circle_id to avoid ambiguity with table column
CREATE OR REPLACE FUNCTION get_circle_feed(
    p_user_id UUID,
    in_circle_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
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
    storage_provider TEXT
) AS $$
#variable_conflict use_column
DECLARE
    v_circle_id UUID := in_circle_id;
BEGIN
    -- Check if user is a member of the circle
    IF NOT EXISTS (
        SELECT 1 FROM public.circle_members cm
        WHERE cm.circle_id = v_circle_id AND cm.user_id = p_user_id
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        posts.id,
        posts.user_id,
        pr.username::TEXT,
        pr.full_name::TEXT,
        pr.avatar_url::TEXT,
        pr.is_verified,
        posts.content::TEXT,
        posts.image_url::TEXT,
        COALESCE(posts.media_urls, ARRAY[]::TEXT[]),
        COALESCE(posts.media_types, ARRAY[]::TEXT[]),
        posts.community_id,
        c.name::TEXT as community_name,
        posts.mood::TEXT,
        COALESCE(posts.hashtags, ARRAY[]::TEXT[]),
        posts.thumbnail_url::TEXT,
        posts.dominant_color::TEXT,
        posts.likes_count,
        posts.comments_count,
        posts.shares_count,
        posts.created_at,
        EXISTS(SELECT 1 FROM public.likes l WHERE l.post_id = posts.id AND l.user_id = p_user_id) as is_liked,
        EXISTS(SELECT 1 FROM public.bookmarks b WHERE b.post_id = posts.id AND b.user_id = p_user_id) as is_bookmarked,
        posts.circle_id,
        posts.storage_provider
    FROM public.posts posts
    INNER JOIN public.profiles pr ON posts.user_id = pr.id
    LEFT JOIN public.communities c ON posts.community_id = c.id
    WHERE posts.circle_id = v_circle_id
    ORDER BY posts.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. UPDATE RLS POLICIES FOR POSTS
DROP POLICY IF EXISTS "Posts are viewable by everyone or circle members" ON public.posts;
CREATE POLICY "Posts are viewable by everyone or circle members" ON public.posts
FOR SELECT USING (
    (posts.circle_id IS NULL AND (
        EXISTS (
            SELECT 1 FROM public.profiles pr
            WHERE pr.id = posts.user_id AND pr.is_private = FALSE
        ) OR 
        posts.user_id = auth.uid() OR 
        EXISTS (
            SELECT 1 FROM public.follows f 
            WHERE f.follower_id = auth.uid() AND f.following_id = posts.user_id
        )
    )) OR
    (posts.circle_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.circle_members cm
        WHERE cm.circle_id = posts.circle_id AND cm.user_id = auth.uid()
    ))
);

DROP POLICY IF EXISTS "Users can only post to circles they are members of" ON public.posts;
CREATE POLICY "Users can only post to circles they are members of" ON public.posts
FOR INSERT WITH CHECK (
    (posts.circle_id IS NULL) OR
    (posts.circle_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.circle_members cm
        WHERE cm.circle_id = posts.circle_id AND cm.user_id = auth.uid()
    ))
);
