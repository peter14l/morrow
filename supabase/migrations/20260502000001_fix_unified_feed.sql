-- Update get_unified_feed to exclude circle posts
CREATE OR REPLACE FUNCTION get_unified_feed(
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
    is_bookmarked BOOLEAN
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
        EXISTS(SELECT 1 FROM public.bookmarks b WHERE b.post_id = p.id AND b.user_id = p_user_id) as is_bookmarked
    FROM public.posts p
    INNER JOIN public.profiles pr ON p.user_id = pr.id
    LEFT JOIN public.communities c ON p.community_id = c.id
    WHERE 
        p.circle_id IS NULL AND -- FILTER OUT CIRCLE POSTS
        (
            p.user_id = p_user_id 
            OR pr.is_private = FALSE 
            OR EXISTS (
                SELECT 1 FROM public.follows f 
                WHERE f.follower_id = p_user_id AND f.following_id = pr.id
            )
        )
    ORDER BY p.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;
