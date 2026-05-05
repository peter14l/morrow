-- =====================================================
-- FIX: CIRCLE_ID AND USER_ID AMBIGUITY
-- =====================================================

-- 1. FIX IS_CIRCLE_MEMBER FUNCTION
CREATE OR REPLACE FUNCTION public.is_circle_member(c_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.circle_members cm WHERE cm.circle_id = c_id AND cm.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.circles c WHERE c.id = c_id AND c.created_by = auth.uid()
  );
$$;

-- 2. FIX IS_CANVAS_MEMBER FUNCTION
CREATE OR REPLACE FUNCTION public.is_canvas_member(c_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.canvas_members cm WHERE cm.canvas_id = c_id AND cm.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.canvases c WHERE c.id = c_id AND c.created_by = auth.uid()
  );
$$;

-- 3. UPDATE CIRCLE_MEMBERS RLS POLICIES
DROP POLICY IF EXISTS "Users can view circle members of their circles" ON public.circle_members;
CREATE POLICY "Users can view circle members of their circles"
    ON public.circle_members FOR SELECT
    USING ( public.is_circle_member(circle_members.circle_id) );

-- 4. UPDATE CANVAS_MEMBERS RLS POLICIES
DROP POLICY IF EXISTS "Users can view canvas members of their canvases" ON public.canvas_members;
CREATE POLICY "Users can view canvas members of their canvases"
    ON public.canvas_members FOR SELECT
    USING ( public.is_canvas_member(canvas_members.canvas_id) );

-- 5. UPDATE PROFILES SELECT POLICY FOR EXTRA SAFETY
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
ON public.profiles FOR SELECT
USING (
    profiles.is_private = FALSE OR
    auth.uid() = profiles.id OR
    EXISTS (
        SELECT 1 FROM public.follows f
        WHERE f.follower_id = auth.uid() AND f.following_id = profiles.id
    )
);

-- 6. UPDATE COMMUNITIES SELECT POLICY
DROP POLICY IF EXISTS "Public communities are viewable by everyone" ON public.communities;
CREATE POLICY "Public communities are viewable by everyone"
ON public.communities FOR SELECT
USING (
    communities.is_private = FALSE 
    OR 
    auth.uid() = communities.creator_id 
    OR 
    communities.id IN (
        SELECT cm.community_id 
        FROM public.community_members cm
        WHERE cm.user_id = auth.uid()
    )
);

-- 7. CLEANUP OVER-PERMISSIVE POST POLICIES
-- These policies allow viewing posts without checking circle_id, which causes leakage.
DROP POLICY IF EXISTS "Users can view posts" ON public.posts;
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON public.posts;
DROP POLICY IF EXISTS "Posts are viewable by everyone except blocked users" ON public.posts;

-- 8. RE-APPLY CONSOLIDATED SECURE POSTS SELECT POLICY
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

-- 9. RE-APPLY GET_CIRCLE_FEED WITH BEST PRACTICES
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
    -- Check if user is a member of the circle (Qualify everything)
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
