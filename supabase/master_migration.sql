-- =====================================================
-- OASIS MASTER DATABASE MIGRATION
-- Consolidated from all migrations for fresh Supabase setup
-- Run this file in your Supabase SQL Editor
-- =====================================================

-- =====================================================
-- SECTION 1: EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- SECTION 2: TYPES/ENUMS
-- =====================================================
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('user', 'moderator', 'admin');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE post_type AS ENUM ('text', 'image', 'video', 'link', 'poll');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE reaction_type AS ENUM ('like', 'love', 'laugh', 'sad', 'angry');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE call_status AS ENUM ('pinging', 'active', 'ended', 'missed', 'rejected');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE call_type AS ENUM ('voice', 'video');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- =====================================================
-- SECTION 3: CORE TABLES
-- =====================================================

-- PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    location TEXT,
    website TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    is_private BOOLEAN DEFAULT FALSE,
    is_pro BOOLEAN DEFAULT FALSE,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    public_key TEXT,
    encrypted_private_key TEXT,
    encrypted_private_key_v2 TEXT,
    key_salt TEXT,
    has_upgraded_security BOOLEAN DEFAULT FALSE,
    encrypted_signal_identity TEXT,
    encrypted_private_key_recovery TEXT,
    focus_mode_enabled BOOLEAN DEFAULT FALSE,
    focus_mode_schedule JSONB,
    wind_down_enabled BOOLEAN DEFAULT FALSE,
    wind_down_time TIME,
    ripples_lockout_multiplier FLOAT DEFAULT 1.0,
    ripples_last_session_end TIMESTAMPTZ,
    ripples_remaining_duration_ms BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT username_length CHECK (char_length(username) >= 3 AND char_length(username) <= 30),
    CONSTRAINT username_format CHECK (username ~ '^[a-z0-9_]+$')
);

-- POSTS TABLE
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT,
    image_url TEXT,
    video_url TEXT,
    media_urls TEXT[],
    media_types TEXT[],
    community_id UUID,
    parent_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    title TEXT,
    post_type post_type DEFAULT 'text',
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    views_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_nsfw BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    mood VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT post_has_content CHECK (
        content IS NOT NULL OR 
        image_url IS NOT NULL OR 
        video_url IS NOT NULL OR
        array_length(media_urls, 1) > 0
    )
);

-- COMMUNITIES TABLE
CREATE TABLE IF NOT EXISTS public.communities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    cover_url TEXT,
    theme TEXT DEFAULT 'General',
    rules TEXT,
    privacy_policy TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    is_restricted BOOLEAN DEFAULT FALSE,
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    members_count INTEGER DEFAULT 0,
    posts_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT community_name_length CHECK (char_length(name) >= 3 AND char_length(name) <= 50),
    CONSTRAINT community_slug_format CHECK (slug ~ '^[a-z0-9-]+$')
);

-- COMMUNITY MEMBERS TABLE
CREATE TABLE IF NOT EXISTS public.community_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    community_id UUID NOT NULL REFERENCES public.communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member' CHECK (role IN ('member', 'moderator', 'admin')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(community_id, user_id)
);

-- FOLLOWS TABLE
CREATE TABLE IF NOT EXISTS public.follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT no_self_follow CHECK (follower_id != following_id),
    UNIQUE(follower_id, following_id)
);

-- LIKES TABLE
CREATE TABLE IF NOT EXISTS public.likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- BOOKMARKS TABLE
CREATE TABLE IF NOT EXISTS public.bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);

-- COMMENTS TABLE
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    replies_count INTEGER DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT comment_content_length CHECK (char_length(content) > 0 AND char_length(content) <= 1000)
);

-- COMMENT LIKES TABLE
CREATE TABLE IF NOT EXISTS public.comment_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment_id UUID NOT NULL REFERENCES public.comments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, comment_id)
);

-- NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
    content TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECTION 4: MESSAGING TABLES
-- =====================================================

-- CONVERSATIONS TABLE
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT DEFAULT 'direct' CHECK (type IN ('direct', 'group')),
    name TEXT,
    image_url TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    last_message_id UUID,
    last_message_at TIMESTAMPTZ,
    is_whisper_mode BOOLEAN DEFAULT FALSE,
    whisper_mode INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CONVERSATION PARTICIPANTS TABLE
CREATE TABLE IF NOT EXISTS public.conversation_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member' CHECK (role IN ('member', 'admin')),
    last_read_at TIMESTAMPTZ,
    unread_count INTEGER DEFAULT 0,
    is_muted BOOLEAN DEFAULT FALSE,
    cleared_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    UNIQUE(conversation_id, user_id)
);

-- MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT,
    image_url TEXT,
    video_url TEXT,
    file_url TEXT,
    file_name TEXT,
    file_size INTEGER,
    voice_url TEXT,
    voice_duration INTEGER,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    call_id UUID REFERENCES public.calls(id) ON DELETE SET NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
    story_id UUID,
    share_data JSONB,
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_ephemeral BOOLEAN DEFAULT FALSE,
    ephemeral_duration INTEGER DEFAULT 86400,
    expires_at TIMESTAMPTZ,
    encrypted_keys JSONB,
    iv TEXT,
    signal_message_type INTEGER,
    signal_sender_content TEXT,
    signal_sender_message_type INTEGER,
    media_view_mode TEXT DEFAULT 'unlimited' CHECK (media_view_mode IN ('unlimited', 'once', 'twice')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT message_has_content CHECK (
        content IS NOT NULL OR 
        image_url IS NOT NULL OR 
        video_url IS NOT NULL OR
        file_url IS NOT NULL OR
        voice_url IS NOT NULL
    )
);

-- MESSAGE READ RECEIPTS TABLE
CREATE TABLE IF NOT EXISTS public.message_read_receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

-- MESSAGE REACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction VARCHAR(10) NOT NULL,
    username TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

-- MESSAGE MEDIA VIEWS TABLE
CREATE TABLE IF NOT EXISTS public.message_media_views (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

-- TYPING INDICATORS TABLE
CREATE TABLE IF NOT EXISTS public.typing_indicators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(conversation_id, user_id)
);

-- CHAT THEMES TABLE
CREATE TABLE IF NOT EXISTS public.chat_themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    theme_name VARCHAR(50) DEFAULT 'default',
    background_color VARCHAR(20),
    background_image_url TEXT,
    bubble_color VARCHAR(20),
    text_color VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(conversation_id, user_id)
);

-- =====================================================
-- SECTION 5: CALLS TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.calls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    channel_name TEXT NOT NULL,
    status call_status DEFAULT 'pinging',
    type call_type DEFAULT 'voice',
    sdp TEXT,
    sdp_type TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    agora_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.call_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    call_id UUID REFERENCES public.calls(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    is_muted BOOLEAN DEFAULT FALSE,
    is_video_on BOOLEAN DEFAULT TRUE,
    is_screen_sharing BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'invited',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(call_id, user_id)
);

-- =====================================================
-- SECTION 6: STORIES TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.stories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    thumbnail_url TEXT,
    caption TEXT,
    duration INTEGER DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours',
    view_count INTEGER DEFAULT 0,
    music_id TEXT,
    music_metadata JSONB,
    interactive_metadata JSONB,
    CONSTRAINT caption_length CHECK (caption IS NULL OR char_length(caption) <= 200)
);

CREATE TABLE IF NOT EXISTS public.story_views (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(story_id, viewer_id)
);

CREATE TABLE IF NOT EXISTS public.story_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(story_id, user_id)
);

-- =====================================================
-- SECTION 7: HASHTAGS & MENTIONS TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hashtags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tag TEXT UNIQUE NOT NULL,
    normalized_tag TEXT UNIQUE NOT NULL,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT tag_format CHECK (tag ~ '^[a-zA-Z0-9_]+$'),
    CONSTRAINT tag_length CHECK (char_length(tag) >= 2 AND char_length(tag) <= 50)
);

CREATE TABLE IF NOT EXISTS public.post_hashtags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    hashtag_id UUID NOT NULL REFERENCES public.hashtags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, hashtag_id)
);

CREATE TABLE IF NOT EXISTS public.mentions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    mentioned_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    mentioned_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT mention_source CHECK (
        (post_id IS NOT NULL AND comment_id IS NULL) OR
        (post_id IS NULL AND comment_id IS NOT NULL)
    )
);

-- =====================================================
-- SECTION 8: COLLECTIONS TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_private BOOLEAN DEFAULT TRUE,
    items_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT collection_name_length CHECK (char_length(name) >= 1 AND char_length(name) <= 50),
    CONSTRAINT collection_description_length CHECK (description IS NULL OR char_length(description) <= 200)
);

CREATE TABLE IF NOT EXISTS public.collection_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_id UUID NOT NULL REFERENCES public.collections(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(collection_id, post_id)
);

-- =====================================================
-- SECTION 9: MODERATION TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE SET NULL,
    comment_id UUID REFERENCES public.comments(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending',
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    resolution_note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT report_category_check CHECK (category IN (
        'spam', 'harassment', 'hate_speech', 'violence', 'nudity', 'misinformation', 'copyright', 'other'
    )),
    CONSTRAINT report_status_check CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    CONSTRAINT report_has_target CHECK (
        reported_user_id IS NOT NULL OR post_id IS NOT NULL OR comment_id IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT no_self_block CHECK (blocker_id != blocked_id),
    UNIQUE(blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS public.muted_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    muter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    muted_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    CONSTRAINT no_self_mute CHECK (muter_id != muted_id),
    UNIQUE(muter_id, muted_id)
);

-- =====================================================
-- SECTION 10: CANVAS & CIRCLES TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.canvases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT DEFAULT 'Our Canvas',
    created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    cover_color TEXT DEFAULT '#3B82F6',
    is_encrypted BOOLEAN DEFAULT true,
    unlock_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.canvas_members (
    canvas_id UUID REFERENCES public.canvases(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (canvas_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.canvas_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    canvas_id UUID REFERENCES public.canvases(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    content TEXT,
    x_pos DOUBLE PRECISION NOT NULL,
    y_pos DOUBLE PRECISION NOT NULL,
    rotation DOUBLE PRECISION DEFAULT 0.0,
    scale DOUBLE PRECISION DEFAULT 1.0,
    color TEXT DEFAULT '#252930',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.circles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT DEFAULT 'My Circle',
    emoji TEXT DEFAULT '🌊',
    created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    streak_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.circle_members (
    circle_id UUID REFERENCES public.circles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (circle_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.commitments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    circle_id UUID REFERENCES public.circles(id) ON DELETE CASCADE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.commitment_responses (
    commitment_id UUID REFERENCES public.commitments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    intent TEXT NOT NULL,
    completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    note TEXT,
    PRIMARY KEY (commitment_id, user_id)
);

-- =====================================================
-- SECTION 11: TIME CAPSULES TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.time_capsules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) NOT NULL,
    content TEXT NOT NULL,
    media_url TEXT,
    media_type TEXT DEFAULT 'none',
    unlock_date TIMESTAMPTZ NOT NULL,
    is_locked BOOLEAN DEFAULT true,
    is_collaborative BOOLEAN DEFAULT FALSE,
    contributor_ids UUID[] DEFAULT '{}',
    location_trigger TEXT,
    location_radius DOUBLE PRECISION,
    music_url TEXT,
    music_title TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.capsule_contributions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    capsule_id UUID REFERENCES public.time_capsules(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    image_urls TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECTION 12: RIPPLES TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.ripples (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    caption TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    saves_count INT DEFAULT 0,
    is_private BOOLEAN DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.ripple_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ripple_id UUID REFERENCES public.ripples(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(ripple_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.ripple_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ripple_id UUID REFERENCES public.ripples(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ripple_saves (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ripple_id UUID REFERENCES public.ripples(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(ripple_id, user_id)
);

-- =====================================================
-- SECTION 13: STUDY SESSIONS TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.study_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    creator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ DEFAULT NOW(),
    duration_minutes INTEGER NOT NULL,
    status TEXT DEFAULT 'active',
    is_locked_in BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.study_session_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID REFERENCES public.study_sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    exit_status TEXT DEFAULT 'joined',
    xp_earned INTEGER DEFAULT 0,
    UNIQUE(session_id, user_id)
);

-- =====================================================
-- SECTION 14: POLLS TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS public.polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    poll_type VARCHAR(20) DEFAULT 'single',
    is_anonymous BOOLEAN DEFAULT FALSE,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    option_order INT DEFAULT 0,
    is_correct BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS public.poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_poll_vote UNIQUE (poll_id, user_id, option_id)
);

-- =====================================================
-- SECTION 15: OTHER TABLES
-- =====================================================

-- SIGNAL KEYS TABLE
CREATE TABLE IF NOT EXISTS public.signal_keys (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    identity_key TEXT NOT NULL,
    registration_id INT NOT NULL,
    signed_prekey JSONB NOT NULL,
    onetime_prekeys JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- WELLNESS ACHIEVEMENTS TABLE
CREATE TABLE IF NOT EXISTS public.wellness_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_type VARCHAR(50) NOT NULL,
    achievement_name VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_achievement UNIQUE (user_id, achievement_type, achievement_name)
);

-- VAULT ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.vault_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    item_type VARCHAR(20) NOT NULL,
    item_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    plan_id VARCHAR(50) NOT NULL,
    payment_provider VARCHAR(20) NOT NULL,
    provider_subscription_id VARCHAR(100) UNIQUE,
    current_period_start TIMESTAMPTZ DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- METADATA TABLE
CREATE TABLE IF NOT EXISTS public.metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SECTION 16: INDEXES
-- =====================================================

-- Profile indexes
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_xp ON public.profiles(xp DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_security_upgrade ON public.profiles(has_upgraded_security) WHERE has_upgraded_security = FALSE;

-- Posts indexes
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_community_id ON public.posts(community_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_is_pinned ON public.posts(is_pinned) WHERE is_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_posts_mood ON public.posts(mood) WHERE mood IS NOT NULL;

-- Communities indexes
CREATE INDEX IF NOT EXISTS idx_communities_slug ON public.communities(slug);
CREATE INDEX IF NOT EXISTS idx_communities_creator_id ON public.communities(creator_id);
CREATE INDEX IF NOT EXISTS idx_communities_created_at ON public.communities(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_communities_members_count ON public.communities(members_count DESC);

-- Community members indexes
CREATE INDEX IF NOT EXISTS idx_community_members_community_id ON public.community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_community_members_user_id ON public.community_members(user_id);
CREATE INDEX IF NOT EXISTS idx_community_members_role ON public.community_members(role);

-- Follows indexes
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows(following_id);

-- Likes indexes
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON public.likes(user_id);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_created_at ON public.likes(created_at DESC);

-- Bookmarks indexes
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON public.bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_post_id ON public.bookmarks(post_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON public.bookmarks(created_at DESC);

-- Comments indexes
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON public.comments(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent_comment_id ON public.comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON public.comments(created_at DESC);

-- Comment likes indexes
CREATE INDEX IF NOT EXISTS idx_comment_likes_user_id ON public.comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_likes_comment_id ON public.comment_likes(comment_id);

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_message_id ON public.notifications(message_id);

-- Conversations indexes
CREATE INDEX IF NOT EXISTS idx_conversations_type ON public.conversations(type);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON public.conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at ON public.conversations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_whisper_mode ON public.conversations(is_whisper_mode) WHERE is_whisper_mode = TRUE;

-- Conversation participants indexes
CREATE INDEX IF NOT EXISTS idx_conversation_participants_conversation_id ON public.conversation_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversation_participants_user_id ON public.conversation_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_conversation_participants_unread_count ON public.conversation_participants(unread_count) WHERE unread_count > 0;

-- Messages indexes
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id ON public.messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_messages_expires_at ON public.messages(expires_at) WHERE expires_at IS NOT NULL;

-- Message read receipts indexes
CREATE INDEX IF NOT EXISTS idx_message_read_receipts_message_id ON public.message_read_receipts(message_id);
CREATE INDEX IF NOT EXISTS idx_message_read_receipts_user_id ON public.message_read_receipts(user_id);

-- Message reactions indexes
CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON public.message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id ON public.message_reactions(user_id);

-- Message media views indexes
CREATE INDEX IF NOT EXISTS idx_message_media_views_message_id ON public.message_media_views(message_id);
CREATE INDEX IF NOT EXISTS idx_message_media_views_user_id ON public.message_media_views(user_id);

-- Typing indicators indexes
CREATE INDEX IF NOT EXISTS idx_typing_indicators_conversation_id ON public.typing_indicators(conversation_id);
CREATE INDEX IF NOT EXISTS idx_typing_indicators_user_id ON public.typing_indicators(user_id);

-- Calls indexes
CREATE INDEX IF NOT EXISTS idx_calls_conversation_id ON public.calls(conversation_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON public.calls(status);
CREATE INDEX IF NOT EXISTS idx_call_participants_call_id ON public.call_participants(call_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_user_id ON public.call_participants(user_id);

-- Stories indexes
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON public.stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON public.stories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stories_expires_at ON public.stories(expires_at);

-- Story views indexes
CREATE INDEX IF NOT EXISTS idx_story_views_story_id ON public.story_views(story_id);
CREATE INDEX IF NOT EXISTS idx_story_views_viewer_id ON public.story_views(viewer_id);
CREATE INDEX IF NOT EXISTS idx_story_views_viewed_at ON public.story_views(viewed_at DESC);

-- Story reactions indexes
CREATE INDEX IF NOT EXISTS idx_story_reactions_story_id ON public.story_reactions(story_id);
CREATE INDEX IF NOT EXISTS idx_story_reactions_user_id ON public.story_reactions(user_id);

-- Hashtags indexes
CREATE INDEX IF NOT EXISTS idx_hashtags_tag ON public.hashtags(tag);
CREATE INDEX IF NOT EXISTS idx_hashtags_normalized_tag ON public.hashtags(normalized_tag);
CREATE INDEX IF NOT EXISTS idx_hashtags_usage_count ON public.hashtags(usage_count DESC);
CREATE INDEX IF NOT EXISTS idx_hashtags_last_used_at ON public.hashtags(last_used_at DESC);

-- Post hashtags indexes
CREATE INDEX IF NOT EXISTS idx_post_hashtags_post_id ON public.post_hashtags(post_id);
CREATE INDEX IF NOT EXISTS idx_post_hashtags_hashtag_id ON public.post_hashtags(hashtag_id);

-- Mentions indexes
CREATE INDEX IF NOT EXISTS idx_mentions_post_id ON public.mentions(post_id);
CREATE INDEX IF NOT EXISTS idx_mentions_comment_id ON public.mentions(comment_id);
CREATE INDEX IF NOT EXISTS idx_mentions_mentioned_user_id ON public.mentions(mentioned_user_id);
CREATE INDEX IF NOT EXISTS idx_mentions_mentioned_by_user_id ON public.mentions(mentioned_by_user_id);

-- Collections indexes
CREATE INDEX IF NOT EXISTS idx_collections_user_id ON public.collections(user_id);
CREATE INDEX IF NOT EXISTS idx_collections_created_at ON public.collections(created_at DESC);

-- Collection items indexes
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id ON public.collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_post_id ON public.collection_items(post_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_added_at ON public.collection_items(added_at DESC);

-- Reports indexes
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON public.reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_post_id ON public.reports(post_id);
CREATE INDEX IF NOT EXISTS idx_reports_comment_id ON public.reports(comment_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_category ON public.reports(category);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports(created_at DESC);

-- Blocked users indexes
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker_id ON public.blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_id ON public.blocked_users(blocked_id);

-- Muted users indexes
CREATE INDEX IF NOT EXISTS idx_muted_users_muter_id ON public.muted_users(muter_id);
CREATE INDEX IF NOT EXISTS idx_muted_users_muted_id ON public.muted_users(muted_id);
CREATE INDEX IF NOT EXISTS idx_muted_users_expires_at ON public.muted_users(expires_at);

-- Time capsules indexes
CREATE INDEX IF NOT EXISTS idx_time_capsules_user_id ON public.time_capsules(user_id);

-- Wellness achievements indexes
CREATE INDEX IF NOT EXISTS idx_wellness_achievements_user ON public.wellness_achievements(user_id);

-- Study sessions indexes
CREATE INDEX IF NOT EXISTS idx_study_sessions_status ON public.study_sessions(status);

-- Ripples indexes
CREATE INDEX IF NOT EXISTS idx_ripples_user_id ON public.ripples(user_id);
CREATE INDEX IF NOT EXISTS idx_ripples_created_at ON public.ripples(created_at DESC);

-- =====================================================
-- SECTION 17: FOREIGN KEYS
-- =====================================================

-- Add foreign key for posts community_id
ALTER TABLE public.posts 
ADD CONSTRAINT fk_posts_community_id 
FOREIGN KEY (community_id) 
REFERENCES public.communities(id) 
ON DELETE SET NULL;

-- Add foreign key for conversations last_message_id
ALTER TABLE public.conversations 
ADD CONSTRAINT fk_conversations_last_message_id 
FOREIGN KEY (last_message_id) 
REFERENCES public.messages(id) 
ON DELETE SET NULL;

-- =====================================================
-- SECTION 18: ENABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_read_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_media_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_hashtags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.muted_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canvases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canvas_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.canvas_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commitments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commitment_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_capsules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.capsule_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ripples ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ripple_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ripple_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ripple_saves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_session_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signal_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wellness_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vault_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Set REPLICA IDENTITY FULL for realtime
ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;
ALTER TABLE public.message_read_receipts REPLICA IDENTITY FULL;
ALTER TABLE public.typing_indicators REPLICA IDENTITY FULL;

-- =====================================================
-- SECTION 19: RLS POLICIES
-- =====================================================

-- PROFILES POLICIES
-- 1. FIX PROFILES RECURSION
-- Create a SECURITY DEFINER function to check pro status without triggering RLS
CREATE OR REPLACE FUNCTION public.check_is_pro_status(profile_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT is_pro FROM public.profiles WHERE id = profile_id;
$$;

DROP POLICY IF EXISTS "Users can update own profile except pro status" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own encryption keys" ON public.profiles;

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

CREATE POLICY "Authenticated users can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);
CREATE POLICY "Users can delete their own profile" ON public.profiles FOR DELETE USING ((SELECT auth.uid()) = id);
CREATE POLICY "Users can read public keys" ON public.profiles FOR SELECT USING (true);

-- POSTS POLICIES
CREATE POLICY "Users can view posts" ON public.posts FOR SELECT
USING (
  (NOT EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = posts.user_id AND profiles.is_private = true)
   OR posts.user_id = (SELECT auth.uid())
   OR EXISTS (SELECT 1 FROM public.follows WHERE follows.follower_id = (SELECT auth.uid()) AND follows.following_id = posts.user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = posts.user_id AND blocked_id = (SELECT auth.uid()))
    OR (blocker_id = (SELECT auth.uid()) AND blocked_id = posts.user_id)
  )
);
CREATE POLICY "Users can insert their own posts" ON public.posts FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can update their own posts" ON public.posts FOR UPDATE USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can delete their own posts" ON public.posts FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- LIKES POLICIES
CREATE POLICY "Users can view likes" ON public.likes FOR SELECT USING (EXISTS (SELECT 1 FROM public.posts WHERE posts.id = likes.post_id AND (NOT EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = posts.user_id AND profiles.is_private = true) OR posts.user_id = (SELECT auth.uid()) OR EXISTS (SELECT 1 FROM public.follows WHERE follows.follower_id = (SELECT auth.uid()) AND follows.following_id = posts.user_id))));
CREATE POLICY "Users can like posts" ON public.likes FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can unlike posts" ON public.likes FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- BOOKMARKS POLICIES
CREATE POLICY "Users can view their own bookmarks" ON public.bookmarks FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can bookmark posts" ON public.bookmarks FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can remove bookmarks" ON public.bookmarks FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- COMMENTS POLICIES
CREATE POLICY "Users can create comments" ON public.comments FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can update their own comments" ON public.comments FOR UPDATE USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can delete their own comments" ON public.comments FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- COMMENT LIKES POLICIES
CREATE POLICY "Comment likes are viewable by everyone" ON public.comment_likes FOR SELECT USING (true);
CREATE POLICY "Users can like comments" ON public.comment_likes FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can unlike comments" ON public.comment_likes FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- NOTIFICATIONS POLICIES
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can insert notifications as actor" ON public.notifications FOR INSERT WITH CHECK (actor_id = (SELECT auth.uid()));
CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING ((SELECT auth.uid()) = user_id);
CREATE POLICY "Users can delete their own notifications" ON public.notifications FOR DELETE USING ((SELECT auth.uid()) = user_id);

-- FOLLOWS POLICIES
CREATE POLICY "Authenticated users can view follows" ON public.follows FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can follow others" ON public.follows FOR INSERT WITH CHECK ((SELECT auth.uid()) = follower_id);
CREATE POLICY "Users can unfollow" ON public.follows FOR DELETE USING ((SELECT auth.uid()) = follower_id);

-- COMMUNITIES POLICIES
CREATE POLICY "Authenticated users can view communities" ON public.communities FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Authenticated users can create communities" ON public.communities FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Community creators can update communities" ON public.communities FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Community creators can delete communities" ON public.communities FOR DELETE USING (auth.uid() = creator_id);

-- COMMUNITY MEMBERS POLICIES
CREATE POLICY "Authenticated users can view memberships" ON public.community_members FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Users can join communities" ON public.community_members FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can leave communities" ON public.community_members FOR DELETE USING (auth.uid() = user_id);
CREATE POLICY "Admins can update member roles" ON public.community_members FOR UPDATE USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);

-- CONVERSATIONS POLICIES
CREATE POLICY "Users can view their conversations" ON public.conversations FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = conversations.id AND user_id = auth.uid()));
CREATE POLICY "Users can create conversations" ON public.conversations FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Conversation admins can update conversations" ON public.conversations FOR UPDATE USING (auth.uid() = created_by OR EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = conversations.id AND user_id = auth.uid() AND role = 'admin'));
CREATE POLICY "Conversation creators can delete conversations" ON public.conversations FOR DELETE USING (auth.uid() = created_by);

-- CONVERSATION PARTICIPANTS POLICIES
CREATE POLICY "Users can view conversation participants" ON public.conversation_participants FOR SELECT USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);
CREATE POLICY "Conversation admins can add participants" ON public.conversation_participants FOR INSERT WITH CHECK (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.conversations WHERE id = conversation_participants.conversation_id AND created_by = auth.uid()));
CREATE POLICY "Users can update their own participant settings" ON public.conversation_participants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can leave or admins can remove participants" ON public.conversation_participants FOR DELETE USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.conversations WHERE id = conversation_participants.conversation_id AND created_by = auth.uid()));

-- MESSAGES POLICIES
CREATE POLICY "Users can view messages in their conversations" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Users can send messages to their conversations" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = messages.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Users can update their own messages" ON public.messages FOR UPDATE USING (auth.uid() = sender_id);
CREATE POLICY "Users can delete their own messages" ON public.messages FOR DELETE USING (auth.uid() = sender_id);

-- MESSAGE READ RECEIPTS POLICIES
CREATE POLICY "Users can view read receipts in their conversations" ON public.message_read_receipts FOR SELECT USING (EXISTS (SELECT 1 FROM public.messages m INNER JOIN public.conversation_participants cp ON m.conversation_id = cp.conversation_id WHERE m.id = message_read_receipts.message_id AND cp.user_id = auth.uid()));
CREATE POLICY "Users can create their own read receipts" ON public.message_read_receipts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own read receipts" ON public.message_read_receipts FOR UPDATE USING (auth.uid() = user_id);

-- MESSAGE REACTIONS POLICIES
CREATE POLICY "Users can view reactions in their conversations" ON public.message_reactions FOR SELECT USING (EXISTS (SELECT 1 FROM public.messages m INNER JOIN public.conversation_participants cp ON m.conversation_id = cp.conversation_id WHERE m.id = message_reactions.message_id AND cp.user_id = auth.uid()));
CREATE POLICY "Users can add reactions" ON public.message_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can remove their own reactions" ON public.message_reactions FOR DELETE USING (auth.uid() = user_id);

-- MESSAGE MEDIA VIEWS POLICIES
CREATE POLICY "Users can see their own media view counts" ON public.message_media_views FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Senders can see media view counts for their messages" ON public.message_media_views FOR SELECT USING (EXISTS (SELECT 1 FROM public.messages WHERE messages.id = message_media_views.message_id AND messages.sender_id = auth.uid()));
CREATE POLICY "Users can insert their own media view counts" ON public.message_media_views FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own media view counts" ON public.message_media_views FOR UPDATE USING (auth.uid() = user_id);

-- TYPING INDICATORS POLICIES
CREATE POLICY "Users can view typing indicators in their conversations" ON public.typing_indicators FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = typing_indicators.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Users can create their own typing indicators" ON public.typing_indicators FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own typing indicators" ON public.typing_indicators FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own typing indicators" ON public.typing_indicators FOR DELETE USING (auth.uid() = user_id);

-- CHAT THEMES POLICIES
CREATE POLICY "Users can manage chat themes for their conversations" ON public.chat_themes FOR ALL USING (EXISTS (SELECT 1 FROM public.conversation_participants WHERE conversation_id = chat_themes.conversation_id AND user_id = auth.uid()));

-- CALLS POLICIES
CREATE POLICY "Users can see calls they are part of" ON public.calls FOR SELECT USING (EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = calls.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Users can initiate calls in conversations they are part of" ON public.calls FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM conversation_participants WHERE conversation_id = conversation_id AND user_id = auth.uid()));
CREATE POLICY "Host can update their call" ON public.calls FOR UPDATE USING (host_id = auth.uid());

-- CALL PARTICIPANTS POLICIES
CREATE POLICY "Users can see participants of calls they are part of" ON public.call_participants FOR SELECT USING (EXISTS (SELECT 1 FROM conversation_participants cp JOIN calls c ON c.conversation_id = cp.conversation_id WHERE c.id = call_participants.call_id AND cp.user_id = auth.uid()));
CREATE POLICY "Users can update their own participant status" ON public.call_participants FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can join calls they are invited to" ON public.call_participants FOR INSERT WITH CHECK (user_id = auth.uid());

-- STORIES POLICIES
CREATE POLICY "Stories are viewable by everyone for public profiles" ON public.stories FOR SELECT USING (expires_at > NOW() AND (EXISTS (SELECT 1 FROM public.profiles WHERE id = stories.user_id AND is_private = FALSE) OR EXISTS (SELECT 1 FROM public.follows WHERE following_id = stories.user_id AND follower_id = auth.uid()) OR user_id = auth.uid()));
CREATE POLICY "Users can create their own stories" ON public.stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own stories" ON public.stories FOR DELETE USING (auth.uid() = user_id);

-- STORY VIEWS POLICIES
CREATE POLICY "Users can view their own story views" ON public.story_views FOR SELECT USING (EXISTS (SELECT 1 FROM public.stories WHERE id = story_views.story_id AND user_id = auth.uid()));
CREATE POLICY "Users can create story views" ON public.story_views FOR INSERT WITH CHECK (auth.uid() = viewer_id);

-- STORY REACTIONS POLICIES
CREATE POLICY "Users can view story reactions" ON public.story_reactions FOR SELECT USING (EXISTS (SELECT 1 FROM public.stories WHERE id = story_reactions.story_id AND (user_id = auth.uid() OR expires_at > NOW())));
CREATE POLICY "Users can create story reactions" ON public.story_reactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own story reactions" ON public.story_reactions FOR DELETE USING (auth.uid() = user_id);

-- HASHTAGS POLICIES
CREATE POLICY "Hashtags are viewable by everyone" ON public.hashtags FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create hashtags" ON public.hashtags FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- POST HASHTAGS POLICIES
CREATE POLICY "Post hashtags are viewable by everyone" ON public.post_hashtags FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create post hashtags" ON public.post_hashtags FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- MENTIONS POLICIES
CREATE POLICY "Users can view their mentions" ON public.mentions FOR SELECT USING (auth.uid() = mentioned_user_id OR auth.uid() = mentioned_by_user_id OR EXISTS (SELECT 1 FROM public.posts WHERE id = mentions.post_id AND user_id = auth.uid()) OR EXISTS (SELECT 1 FROM public.comments WHERE id = mentions.comment_id AND user_id = auth.uid()));
CREATE POLICY "Authenticated users can create mentions" ON public.mentions FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- COLLECTIONS POLICIES
CREATE POLICY "Users can view their own collections" ON public.collections FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view public collections" ON public.collections FOR SELECT USING (is_private = FALSE);
CREATE POLICY "Users can create their own collections" ON public.collections FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own collections" ON public.collections FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own collections" ON public.collections FOR DELETE USING (auth.uid() = user_id);

-- COLLECTION ITEMS POLICIES
CREATE POLICY "Users can view collection items" ON public.collection_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.collections WHERE id = collection_items.collection_id AND (user_id = auth.uid() OR is_private = FALSE)));
CREATE POLICY "Users can add items to their own collections" ON public.collection_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.collections WHERE id = collection_id AND user_id = auth.uid()));
CREATE POLICY "Users can remove items from their own collections" ON public.collection_items FOR DELETE USING (EXISTS (SELECT 1 FROM public.collections WHERE id = collection_id AND user_id = auth.uid()));

-- REPORTS POLICIES
CREATE POLICY "Users can view their own reports" ON public.reports FOR SELECT USING (auth.uid() = reporter_id);
CREATE POLICY "Users can create reports" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- BLOCKED USERS POLICIES
CREATE POLICY "Users can view their own blocks" ON public.blocked_users FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can create blocks" ON public.blocked_users FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can remove their own blocks" ON public.blocked_users FOR DELETE USING (auth.uid() = blocker_id);

-- MUTED USERS POLICIES
CREATE POLICY "Users can view their own mutes" ON public.muted_users FOR SELECT USING (auth.uid() = muter_id);
CREATE POLICY "Users can create mutes" ON public.muted_users FOR INSERT WITH CHECK (auth.uid() = muter_id);
CREATE POLICY "Users can update their own mutes" ON public.muted_users FOR UPDATE USING (auth.uid() = muter_id) WITH CHECK (auth.uid() = muter_id);
CREATE POLICY "Users can remove their own mutes" ON public.muted_users FOR DELETE USING (auth.uid() = muter_id);

-- CANVASES POLICIES
CREATE POLICY "Users can view canvases they are members of" ON public.canvases FOR SELECT USING (EXISTS (SELECT 1 FROM public.canvas_members WHERE canvas_id = canvases.id AND user_id = auth.uid()));
CREATE POLICY "Users can view canvases they created" ON public.canvases FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can insert canvases" ON public.canvases FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Canvas members can update canvases" ON public.canvases FOR UPDATE USING (EXISTS (SELECT 1 FROM public.canvas_members WHERE canvas_id = canvases.id AND user_id = auth.uid()));

-- CANVAS MEMBERS POLICIES
CREATE POLICY "Users can view canvas members of their canvases" ON public.canvas_members FOR SELECT USING (public.is_canvas_member(canvas_id));
CREATE POLICY "Canvas creator can add members, users can add themselves" ON public.canvas_members FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()) OR EXISTS (SELECT 1 FROM public.canvases WHERE id = canvas_id AND created_by = (SELECT auth.uid())));
CREATE POLICY "Users can remove themselves from canvases" ON public.canvas_members FOR DELETE USING (user_id = auth.uid());

-- CANVAS ITEMS POLICIES
CREATE POLICY "Users can view items in their canvases" ON public.canvas_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.canvas_members WHERE canvas_id = canvas_items.canvas_id AND user_id = auth.uid()));
CREATE POLICY "Users can add items to their canvases" ON public.canvas_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.canvas_members WHERE canvas_id = canvas_items.canvas_id AND user_id = auth.uid()));
CREATE POLICY "Users can update items in their canvases" ON public.canvas_items FOR UPDATE USING (EXISTS (SELECT 1 FROM public.canvas_members WHERE canvas_id = canvas_items.canvas_id AND user_id = auth.uid()));
CREATE POLICY "Users can delete their own items" ON public.canvas_items FOR DELETE USING (author_id = auth.uid());

-- CIRCLES POLICIES
CREATE POLICY "Users can view circles they are members of" ON public.circles FOR SELECT USING (EXISTS (SELECT 1 FROM public.circle_members WHERE circle_id = circles.id AND user_id = auth.uid()));
CREATE POLICY "Users can view circles they created" ON public.circles FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Users can create circles" ON public.circles FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Creators can delete their own circles" ON public.circles FOR DELETE USING (auth.uid() = created_by);

-- CIRCLE MEMBERS POLICIES
CREATE POLICY "Users can view circle members of their circles" ON public.circle_members FOR SELECT USING (public.is_circle_member(circle_id));
CREATE POLICY "Circle creator can add members, users can join circles" ON public.circle_members FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()) OR EXISTS (SELECT 1 FROM public.circles WHERE id = circle_id AND created_by = (SELECT auth.uid())));
CREATE POLICY "Users can leave circles" ON public.circle_members FOR DELETE USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.circles WHERE id = circle_id AND created_by = auth.uid()));

-- COMMITMENTS POLICIES
CREATE POLICY "Users can view commitments in their circles" ON public.commitments FOR SELECT USING (EXISTS (SELECT 1 FROM public.circle_members WHERE circle_id = commitments.circle_id AND user_id = auth.uid()));
CREATE POLICY "Circle members can add commitments" ON public.commitments FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.circle_members WHERE circle_id = commitments.circle_id AND user_id = auth.uid()));

-- COMMITMENT RESPONSES POLICIES
CREATE POLICY "Users can view commitment responses in their circles" ON public.commitment_responses FOR SELECT USING (EXISTS (SELECT 1 FROM public.commitments c JOIN public.circle_members cm ON cm.circle_id = c.circle_id WHERE c.id = commitment_responses.commitment_id AND cm.user_id = auth.uid()));
CREATE POLICY "Users can respond to commitments in their circles" ON public.commitment_responses FOR INSERT WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM public.commitments c JOIN public.circle_members cm ON cm.circle_id = c.circle_id WHERE c.id = commitment_responses.commitment_id AND cm.user_id = auth.uid()));
CREATE POLICY "Users can update their own commitment responses" ON public.commitment_responses FOR UPDATE USING (user_id = auth.uid());

-- TIME CAPSULES POLICIES
CREATE POLICY "Users can view their own capsules" ON public.time_capsules FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own capsules" ON public.time_capsules FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Public can view capsules" ON public.time_capsules FOR SELECT USING (true);

-- CAPSULE CONTRIBUTIONS POLICIES
CREATE POLICY "Users can contribute to capsules they are invited to" ON public.capsule_contributions FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.time_capsules WHERE id = capsule_id AND (user_id = auth.uid() OR contributor_ids @> ARRAY[auth.uid()])));
CREATE POLICY "Users can view contributions for capsules they can see" ON public.capsule_contributions FOR SELECT USING (EXISTS (SELECT 1 FROM public.time_capsules WHERE id = capsule_id));

-- RIPPLES POLICIES
CREATE POLICY "Users can view ripples" ON public.ripples FOR SELECT USING (true);
CREATE POLICY "Users can create ripples" ON public.ripples FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own ripples" ON public.ripples FOR DELETE USING (auth.uid() = user_id);

-- RIPPLE LIKES POLICIES
CREATE POLICY "Users can like ripples" ON public.ripple_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike ripples" ON public.ripple_likes FOR DELETE USING (auth.uid() = user_id);

-- RIPPLE COMMENTS POLICIES
CREATE POLICY "Users can comment on ripples" ON public.ripple_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RIPPLE SAVES POLICIES
CREATE POLICY "Users can save ripples" ON public.ripple_saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unsave ripples" ON public.ripple_saves FOR DELETE USING (auth.uid() = user_id);

-- STUDY SESSIONS POLICIES
CREATE POLICY "Anyone can see active study sessions" ON public.study_sessions FOR SELECT USING (status = 'active');
CREATE POLICY "Users can create study sessions" ON public.study_sessions FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Participants can see their sessions" ON public.study_session_participants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can join sessions" ON public.study_session_participants FOR INSERT WITH CHECK (auth.uid() = user_id);

-- POLLS POLICIES
CREATE POLICY "Anyone can view polls" ON public.polls FOR SELECT USING (true);
CREATE POLICY "Anyone can view poll options" ON public.poll_options FOR SELECT USING (true);
CREATE POLICY "Users can vote" ON public.poll_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view votes" ON public.poll_votes FOR SELECT USING (true);

-- SIGNAL KEYS POLICIES
CREATE POLICY "Authenticated users can read signal key bundles" ON public.signal_keys FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users can insert their own signal keys" ON public.signal_keys FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own signal keys" ON public.signal_keys FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- WELLNESS ACHIEVEMENTS POLICIES
CREATE POLICY "Users can view own achievements" ON public.wellness_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert achievements" ON public.wellness_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);

-- VAULT ITEMS POLICIES
CREATE POLICY "Users can manage own vault items" ON public.vault_items FOR ALL USING (auth.uid() = user_id);

-- SUBSCRIPTIONS POLICIES
CREATE POLICY "Users can view own subscription" ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);

-- =====================================================
-- SECTION 20: FUNCTIONS
-- =====================================================

-- UPDATED_AT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- PROFILE CREATION TRIGGER
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_username TEXT;
    v_base_username TEXT;
    v_count INTEGER := 0;
BEGIN
    v_base_username := COALESCE(
        NEW.raw_user_meta_data->>'username', 
        NEW.raw_user_meta_data->>'full_name',
        SPLIT_PART(NEW.email, '@', 1)
    );
    v_base_username := LOWER(REGEXP_REPLACE(v_base_username, '[^a-zA-Z0-9_]', '', 'g'));
    IF CHAR_LENGTH(v_base_username) < 3 THEN
        v_base_username := v_base_username || '_user';
    END IF;
    v_base_username := LEFT(v_base_username, 25);
    v_username := v_base_username;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = v_username) LOOP
        v_count := v_count + 1;
        v_username := v_base_username || v_count::TEXT;
    END LOOP;
    INSERT INTO public.profiles (id, email, username, full_name, avatar_url, xp, created_at, updated_at)
    VALUES (NEW.id, NEW.email, v_username, COALESCE(NEW.raw_user_meta_data->>'full_name', v_username), COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL), 0, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- USER METADATA UPDATE FUNCTION
CREATE OR REPLACE FUNCTION public.handle_user_metadata_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.raw_app_meta_data->>'is_pro' IS NOT NULL THEN
    UPDATE public.profiles
    SET is_pro = (NEW.raw_app_meta_data->>'is_pro')::BOOLEAN
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- INCREMENT POST LIKES COUNT
CREATE OR REPLACE FUNCTION public.increment_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.posts
    SET likes_count = likes_count + 1
    WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DECREMENT POST LIKES COUNT
CREATE OR REPLACE FUNCTION public.decrement_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.posts
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- INCREMENT POST COMMENTS COUNT
CREATE OR REPLACE FUNCTION public.increment_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.posts
    SET comments_count = comments_count + 1
    WHERE id = NEW.post_id;
    
    IF NEW.parent_comment_id IS NOT NULL THEN
        UPDATE public.comments
        SET replies_count = replies_count + 1
        WHERE id = NEW.parent_comment_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- DECREMENT POST COMMENTS COUNT
CREATE OR REPLACE FUNCTION public.decrement_post_comments_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.posts
    SET comments_count = GREATEST(0, comments_count - 1)
    WHERE id = OLD.post_id;
    
    IF OLD.parent_comment_id IS NOT NULL THEN
        UPDATE public.comments
        SET replies_count = GREATEST(0, replies_count - 1)
        WHERE id = OLD.parent_comment_id;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- INCREMENT COMMENT LIKES COUNT
CREATE OR REPLACE FUNCTION increment_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.comments
    SET likes_count = likes_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- DECREMENT COMMENT LIKES COUNT
CREATE OR REPLACE FUNCTION decrement_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.comments
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = OLD.comment_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- INCREMENT FOLLOW COUNTS
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

-- DECREMENT FOLLOW COUNTS
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

-- INCREMENT USER POSTS COUNT
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

-- DECREMENT USER POSTS COUNT
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

-- INCREMENT COMMUNITY MEMBERS COUNT
CREATE OR REPLACE FUNCTION increment_community_members_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.communities
    SET members_count = members_count + 1
    WHERE id = NEW.community_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- DECREMENT COMMUNITY MEMBERS COUNT
CREATE OR REPLACE FUNCTION decrement_community_members_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.communities
    SET members_count = GREATEST(0, members_count - 1)
    WHERE id = OLD.community_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- CREATE LIKE NOTIFICATION
CREATE OR REPLACE FUNCTION public.create_like_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_post_user_id UUID;
BEGIN
    SELECT user_id INTO v_post_user_id
    FROM public.posts
    WHERE id = NEW.post_id;

    IF v_post_user_id IS NOT NULL AND v_post_user_id != NEW.user_id THEN
        INSERT INTO public.notifications (user_id, actor_id, type, post_id)
        VALUES (v_post_user_id, NEW.user_id, 'like', NEW.post_id)
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CREATE COMMENT NOTIFICATION
CREATE OR REPLACE FUNCTION create_comment_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_post_user_id UUID;
    v_parent_comment_user_id UUID;
BEGIN
    SELECT user_id INTO v_post_user_id
    FROM public.posts
    WHERE id = NEW.post_id;
    
    IF v_post_user_id != NEW.user_id THEN
        INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, content)
        VALUES (v_post_user_id, NEW.user_id, 'comment', NEW.post_id, NEW.id, NEW.content)
        ON CONFLICT DO NOTHING;
    END IF;
    
    IF NEW.parent_comment_id IS NOT NULL THEN
        SELECT user_id INTO v_parent_comment_user_id
        FROM public.comments
        WHERE id = NEW.parent_comment_id;
        
        IF v_parent_comment_user_id != NEW.user_id AND v_parent_comment_user_id != v_post_user_id THEN
            INSERT INTO public.notifications (user_id, actor_id, type, post_id, comment_id, content)
            VALUES (v_parent_comment_user_id, NEW.user_id, 'comment', NEW.post_id, NEW.id, NEW.content)
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CREATE FOLLOW NOTIFICATION
CREATE OR REPLACE FUNCTION create_follow_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (NEW.following_id, NEW.follower_id, 'follow')
    ON CONFLICT DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- HANDLE NEW MESSAGE (conversations update)
CREATE OR REPLACE FUNCTION public.handle_new_message()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.conversations
    SET 
        last_message_id = NEW.id,
        last_message_at = NEW.created_at,
        updated_at = NOW()
    WHERE id = NEW.conversation_id
    AND (last_message_at IS NULL OR NEW.created_at >= last_message_at);

    UPDATE public.conversation_participants
    SET 
        unread_count = unread_count + 1,
        updated_at = NOW()
    WHERE conversation_id = NEW.conversation_id
    AND user_id != NEW.sender_id;
    
    UPDATE public.conversation_participants
    SET updated_at = NOW()
    WHERE conversation_id = NEW.conversation_id
    AND user_id = NEW.sender_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- HANDLE MESSAGE WHISPER SETTINGS
CREATE OR REPLACE FUNCTION public.handle_message_whisper_settings()
RETURNS TRIGGER AS $$
DECLARE
    v_whisper_mode INTEGER;
BEGIN
    SELECT whisper_mode INTO v_whisper_mode
    FROM public.conversations
    WHERE id = NEW.conversation_id;

    IF v_whisper_mode > 0 THEN
        NEW.is_ephemeral := TRUE;
        NEW.ephemeral_duration := CASE 
            WHEN v_whisper_mode = 1 THEN 0 
            WHEN v_whisper_mode = 2 THEN 86400 
            ELSE 86400 
        END;
    ELSE
        NEW.is_ephemeral := FALSE;
        NEW.ephemeral_duration := 86400;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- APPLY MESSAGE EXPIRATION
CREATE OR REPLACE FUNCTION public.apply_message_expiration()
RETURNS TRIGGER AS $$
DECLARE
    v_is_ephemeral BOOLEAN;
    v_duration INTEGER;
    v_sender_id UUID;
BEGIN
    SELECT is_ephemeral, ephemeral_duration, sender_id 
    INTO v_is_ephemeral, v_duration, v_sender_id
    FROM public.messages
    WHERE id = NEW.message_id;

    IF v_is_ephemeral = TRUE AND NEW.user_id != v_sender_id THEN
        UPDATE public.messages
        SET expires_at = CASE 
            WHEN v_duration = 0 THEN NOW()
            ELSE NOW() + (v_duration || ' seconds')::INTERVAL
        END
        WHERE id = NEW.message_id AND expires_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CLEANUP VANISH MODE MESSAGES
CREATE OR REPLACE FUNCTION cleanup_vanish_mode_messages(p_conversation_id UUID)
RETURNS void AS $$
BEGIN
    DELETE FROM public.messages m
    WHERE m.conversation_id = p_conversation_id
      AND m.is_ephemeral = true
      AND EXISTS (
          SELECT 1 FROM public.message_read_receipts r 
          WHERE r.message_id = m.id 
          AND r.user_id != m.sender_id
      );
END;
$$ LANGUAGE plpgsql;

-- CLEANUP EXPIRED MESSAGES
CREATE OR REPLACE FUNCTION public.cleanup_expired_messages(p_conversation_id UUID)
RETURNS void AS $$
BEGIN
    DELETE FROM public.messages
    WHERE conversation_id = p_conversation_id
      AND is_ephemeral = TRUE
      AND expires_at <= NOW();
END;
$$ LANGUAGE plpgsql;

-- INCREMENT STORY VIEW COUNT
CREATE OR REPLACE FUNCTION increment_story_view_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.stories
    SET view_count = view_count + 1
    WHERE id = NEW.story_id;
    
    RETURN NEW;
END;
$$;

-- DELETE EXPIRED STORIES
CREATE OR REPLACE FUNCTION delete_expired_stories()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.stories
    WHERE expires_at < NOW();
END;
$$;

-- UPDATE COLLECTION ITEMS COUNT
CREATE OR REPLACE FUNCTION update_collection_items_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.collections
        SET items_count = items_count + 1,
            updated_at = NOW()
        WHERE id = NEW.collection_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.collections
        SET items_count = items_count - 1,
            updated_at = NOW()
        WHERE id = OLD.collection_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- IS USER BLOCKED
CREATE OR REPLACE FUNCTION is_user_blocked(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE (blocker_id = user_a AND blocked_id = user_b)
        OR (blocker_id = user_b AND blocked_id = user_a)
    );
END;
$$;

-- IS USER MUTED
CREATE OR REPLACE FUNCTION is_user_muted(muter UUID, muted UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.muted_users
        WHERE muter_id = muter 
        AND muted_id = muted
        AND (expires_at IS NULL OR expires_at > NOW())
    );
END;
$$;

-- CLEANUP EXPIRED MUTES
CREATE OR REPLACE FUNCTION cleanup_expired_mutes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.muted_users
    WHERE expires_at IS NOT NULL AND expires_at < NOW();
END;
$$;

-- IS CANVAS MEMBER
CREATE OR REPLACE FUNCTION public.is_canvas_member(c_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM canvas_members
    WHERE canvas_id = c_id AND user_id = auth.uid()
  );
$$;

-- IS CIRCLE MEMBER
CREATE OR REPLACE FUNCTION public.is_circle_member(c_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_id = c_id AND user_id = auth.uid()
  );
$$;

-- SYNC PRO STATUS FROM SUBSCRIPTION
CREATE OR REPLACE FUNCTION public.sync_pro_status_from_subscription()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'active' AND NEW.current_period_end > NOW() THEN
        UPDATE public.profiles SET is_pro = true WHERE id = NEW.user_id;
        
        UPDATE auth.users 
        SET raw_app_meta_data = raw_app_meta_data || '{"is_pro": true}'::jsonb
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- CLEANUP EXPIRED SUBSCRIPTIONS
CREATE OR REPLACE FUNCTION public.cleanup_expired_subscriptions()
RETURNS VOID AS $$
DECLARE
    expired_user RECORD;
BEGIN
    FOR expired_user IN 
        SELECT user_id FROM public.subscriptions 
        WHERE current_period_end < NOW() AND status != 'expired'
    LOOP
        UPDATE public.profiles SET is_pro = false WHERE id = expired_user.user_id;
        
        UPDATE auth.users 
        SET raw_app_meta_data = raw_app_meta_data || '{"is_pro": false}'::jsonb
        WHERE id = expired_user.user_id;

        UPDATE public.subscriptions 
        SET status = 'expired' 
        WHERE user_id = expired_user.user_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- FILTER NOTIFICATION INSERT
CREATE OR REPLACE FUNCTION public.filter_notification_insert()
RETURNS TRIGGER AS $$
DECLARE
    v_is_blocked BOOLEAN;
    v_is_muted_user BOOLEAN;
    v_is_muted_conversation BOOLEAN;
    v_conversation_id UUID;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.blocked_users
        WHERE blocker_id = NEW.user_id AND blocked_id = NEW.actor_id
    ) INTO v_is_blocked;

    IF v_is_blocked THEN
        RETURN NULL;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.muted_users
        WHERE muter_id = NEW.user_id AND muted_id = NEW.actor_id
        AND (expires_at IS NULL OR expires_at > NOW())
    ) INTO v_is_muted_user;

    IF v_is_muted_user THEN
        RETURN NULL;
    END IF;

    IF NEW.type = 'dm' AND NEW.message_id IS NOT NULL THEN
        SELECT conversation_id INTO v_conversation_id
        FROM public.messages
        WHERE id = NEW.message_id;

        IF v_conversation_id IS NOT NULL THEN
            SELECT is_muted INTO v_is_muted_conversation
            FROM public.conversation_participants
            WHERE conversation_id = v_conversation_id AND user_id = NEW.user_id;

            IF v_is_muted_conversation THEN
                RETURN NULL;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GET_OR_CREATE_DIRECT_CONVERSATION
CREATE OR REPLACE FUNCTION get_or_create_direct_conversation(
    p_user1_id UUID,
    p_user2_id UUID
)
RETURNS UUID 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_conversation_id UUID;
    v_current_user_id UUID;
BEGIN
    v_current_user_id := auth.uid();
    
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    IF v_current_user_id != p_user1_id AND v_current_user_id != p_user2_id THEN
        RAISE EXCEPTION 'User can only create conversations they are part of';
    END IF;
    
    SELECT c.id INTO v_conversation_id
    FROM public.conversations c
    INNER JOIN public.conversation_participants cp1 ON c.id = cp1.conversation_id
    INNER JOIN public.conversation_participants cp2 ON c.id = cp2.conversation_id
    WHERE c.type = 'direct'
    AND cp1.user_id = p_user1_id
    AND cp2.user_id = p_user2_id
    LIMIT 1;
    
    IF v_conversation_id IS NULL THEN
        IF p_user1_id = p_user2_id THEN
            RAISE EXCEPTION 'Cannot create a conversation with yourself';
        END IF;
        
        INSERT INTO public.conversations (type, created_by)
        VALUES ('direct', v_current_user_id)
        RETURNING id INTO v_conversation_id;
        
        INSERT INTO public.conversation_participants (conversation_id, user_id)
        VALUES 
            (v_conversation_id, p_user1_id),
            (v_conversation_id, p_user2_id)
        ON CONFLICT (conversation_id, user_id) DO NOTHING;
    END IF;
    
    RETURN v_conversation_id;
END;
$$;

-- =====================================================
-- SECTION 21: TRIGGERS
-- =====================================================

-- AUTH TRIGGERS
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

DROP TRIGGER IF EXISTS on_auth_app_metadata_updated ON auth.users;
CREATE TRIGGER on_auth_app_metadata_updated
    AFTER UPDATE OF raw_app_meta_data ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_metadata_update();

-- UPDATED_AT TRIGGERS
DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_posts_updated_at ON public.posts;
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_communities_updated_at ON public.communities;
CREATE TRIGGER update_communities_updated_at
    BEFORE UPDATE ON public.communities
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_comments_updated_at ON public.comments;
CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_conversations_updated_at ON public.conversations;
CREATE TRIGGER update_conversations_updated_at
    BEFORE UPDATE ON public.conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_messages_updated_at ON public.messages;
CREATE TRIGGER update_messages_updated_at
    BEFORE UPDATE ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_chat_themes_updated_at ON public.chat_themes;
CREATE TRIGGER update_chat_themes_updated_at
    BEFORE UPDATE ON public.chat_themes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_signal_keys_updated_at ON public.signal_keys;
CREATE TRIGGER update_signal_keys_updated_at
    BEFORE UPDATE ON public.signal_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON public.subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();

-- LIKES TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_post_likes_count ON public.likes;
CREATE TRIGGER trigger_increment_post_likes_count
    AFTER INSERT ON public.likes
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_post_likes_count();

DROP TRIGGER IF EXISTS trigger_decrement_post_likes_count ON public.likes;
CREATE TRIGGER trigger_decrement_post_likes_count
    AFTER DELETE ON public.likes
    FOR EACH ROW
    EXECUTE FUNCTION public.decrement_post_likes_count();

DROP TRIGGER IF EXISTS trigger_create_like_notification ON public.likes;
CREATE TRIGGER trigger_create_like_notification
    AFTER INSERT ON public.likes
    FOR EACH ROW
    EXECUTE FUNCTION public.create_like_notification();

-- COMMENTS TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_post_comments_count ON public.comments;
CREATE TRIGGER trigger_increment_post_comments_count
    AFTER INSERT ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_post_comments_count();

DROP TRIGGER IF EXISTS trigger_decrement_post_comments_count ON public.comments;
CREATE TRIGGER trigger_decrement_post_comments_count
    AFTER DELETE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.decrement_post_comments_count();

DROP TRIGGER IF EXISTS trigger_create_comment_notification ON public.comments;
CREATE TRIGGER trigger_create_comment_notification
    AFTER INSERT ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION create_comment_notification();

-- COMMENT LIKES TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_comment_likes_count ON public.comment_likes;
CREATE TRIGGER trigger_increment_comment_likes_count
    AFTER INSERT ON public.comment_likes
    FOR EACH ROW
    EXECUTE FUNCTION increment_comment_likes_count();

DROP TRIGGER IF EXISTS trigger_decrement_comment_likes_count ON public.comment_likes;
CREATE TRIGGER trigger_decrement_comment_likes_count
    AFTER DELETE ON public.comment_likes
    FOR EACH ROW
    EXECUTE FUNCTION decrement_comment_likes_count();

-- FOLLOWS TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_follow_counts ON public.follows;
CREATE TRIGGER trigger_increment_follow_counts
    AFTER INSERT ON public.follows
    FOR EACH ROW
    EXECUTE FUNCTION increment_follow_counts();

DROP TRIGGER IF EXISTS trigger_decrement_follow_counts ON public.follows;
CREATE TRIGGER trigger_decrement_follow_counts
    AFTER DELETE ON public.follows
    FOR EACH ROW
    EXECUTE FUNCTION decrement_follow_counts();

DROP TRIGGER IF EXISTS trigger_create_follow_notification ON public.follows;
CREATE TRIGGER trigger_create_follow_notification
    AFTER INSERT ON public.follows
    FOR EACH ROW
    EXECUTE FUNCTION create_follow_notification();

-- POSTS TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_user_posts_count ON public.posts;
CREATE TRIGGER trigger_increment_user_posts_count
    AFTER INSERT ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION increment_user_posts_count();

DROP TRIGGER IF EXISTS trigger_decrement_user_posts_count ON public.posts;
CREATE TRIGGER trigger_decrement_user_posts_count
    AFTER DELETE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION decrement_user_posts_count();

-- COMMUNITY MEMBERS TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_community_members_count ON public.community_members;
CREATE TRIGGER trigger_increment_community_members_count
    AFTER INSERT ON public.community_members
    FOR EACH ROW
    EXECUTE FUNCTION increment_community_members_count();

DROP TRIGGER IF EXISTS trigger_decrement_community_members_count ON public.community_members;
CREATE TRIGGER trigger_decrement_community_members_count
    AFTER DELETE ON public.community_members
    FOR EACH ROW
    EXECUTE FUNCTION decrement_community_members_count();

-- MESSAGES TRIGGERS
DROP TRIGGER IF EXISTS trigger_handle_new_message ON public.messages;
CREATE TRIGGER trigger_handle_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_message();

DROP TRIGGER IF EXISTS trigger_message_whisper_settings ON public.messages;
CREATE TRIGGER trigger_message_whisper_settings
    BEFORE INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_message_whisper_settings();

-- MESSAGE READ RECEIPTS TRIGGERS
DROP TRIGGER IF EXISTS trigger_apply_expiration ON public.message_read_receipts;
CREATE TRIGGER trigger_apply_expiration
    AFTER INSERT ON public.message_read_receipts
    FOR EACH ROW
    EXECUTE FUNCTION public.apply_message_expiration();

-- STORY VIEWS TRIGGERS
DROP TRIGGER IF EXISTS trigger_increment_story_view_count ON public.story_views;
CREATE TRIGGER trigger_increment_story_view_count
    AFTER INSERT ON public.story_views
    FOR EACH ROW
    EXECUTE FUNCTION increment_story_view_count();

-- COLLECTION ITEMS TRIGGERS
DROP TRIGGER IF EXISTS trigger_update_collection_items_count ON public.collection_items;
CREATE TRIGGER trigger_update_collection_items_count
    AFTER INSERT OR DELETE ON public.collection_items
    FOR EACH ROW
    EXECUTE FUNCTION update_collection_items_count();

-- NOTIFICATIONS TRIGGERS
DROP TRIGGER IF EXISTS trigger_filter_notification_insert ON public.notifications;
CREATE TRIGGER trigger_filter_notification_insert
    BEFORE INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.filter_notification_insert();

-- SUBSCRIPTION TRIGGERS
DROP TRIGGER IF EXISTS on_subscription_sync_pro ON public.subscriptions;
CREATE TRIGGER on_subscription_sync_pro
    AFTER INSERT OR UPDATE ON public.subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_pro_status_from_subscription();

-- =====================================================
-- SECTION 22: STORAGE SETUP
-- =====================================================

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) 
VALUES 
    ('profile-pictures', 'profile-pictures', true),
    ('post-images', 'post-images', true),
    ('post-videos', 'post-videos', true),
    ('community-images', 'community-images', true),
    ('message-attachments', 'message-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- Update bucket file size limits
UPDATE storage.buckets 
SET file_size_limit = 157286400 
WHERE id IN ('message-attachments', 'post-images', 'post-videos', 'community-images');

UPDATE storage.buckets
SET file_size_limit = 10485760
WHERE id = 'profile-pictures' AND file_size_limit IS NULL;

-- Storage policies
CREATE POLICY "Profile pictures are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'profile-pictures');
CREATE POLICY "Users can upload their own profile pictures" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'profile-pictures' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can update their own profile pictures" ON storage.objects FOR UPDATE USING (bucket_id = 'profile-pictures' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own profile pictures" ON storage.objects FOR DELETE USING (bucket_id = 'profile-pictures' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Post images are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'post-images');
CREATE POLICY "Authenticated users can upload post images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'post-images' AND auth.role() = 'authenticated');
CREATE POLICY "Users can update their own post images" ON storage.objects FOR UPDATE USING (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own post images" ON storage.objects FOR DELETE USING (bucket_id = 'post-images' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Post videos are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'post-videos');
CREATE POLICY "Authenticated users can upload post videos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'post-videos' AND auth.role() = 'authenticated');
CREATE POLICY "Users can update their own post videos" ON storage.objects FOR UPDATE USING (bucket_id = 'post-videos' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can delete their own post videos" ON storage.objects FOR DELETE USING (bucket_id = 'post-videos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Community images are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'community-images');
CREATE POLICY "Authenticated users can upload community images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'community-images' AND auth.role() = 'authenticated');
CREATE POLICY "Community admins can update community images" ON storage.objects FOR UPDATE USING (bucket_id = 'community-images' AND auth.role() = 'authenticated');
CREATE POLICY "Community admins can delete community images" ON storage.objects FOR DELETE USING (bucket_id = 'community-images' AND auth.role() = 'authenticated');

CREATE POLICY "Message attachments are publicly accessible" ON storage.objects FOR SELECT USING (bucket_id = 'message-attachments');
CREATE POLICY "Authenticated users can upload message attachments" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'message-attachments' AND auth.role() = 'authenticated');
CREATE POLICY "Users can delete their own message attachments" ON storage.objects FOR DELETE USING (bucket_id = 'message-attachments' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =====================================================
-- SECTION 23: REALTIME SETUP
-- =====================================================

ALTER PUBLICATION supabase_realtime ADD TABLE canvas_items;
ALTER PUBLICATION supabase_realtime ADD TABLE commitments;
ALTER PUBLICATION supabase_realtime ADD TABLE commitment_responses;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_themes;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE message_read_receipts;
ALTER PUBLICATION supabase_realtime ADD TABLE conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE call_signaling;

-- =====================================================
-- SECTION 24: METADATA DEFAULTS
-- =====================================================

INSERT INTO public.metadata (key, value) 
VALUES 
    ('supabase_project_ref', 'placeholder-ref'),
    ('supabase_anon_key', 'placeholder-key')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- COMPLETE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Oasis Master Migration Complete! Database is ready.';
END $$;