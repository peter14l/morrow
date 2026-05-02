-- Migration: Update Messaging RPCs for PQ-Aura support
-- Date: 2026-05-02
-- Purpose: Update send_message_v3 and get_user_conversations_v2 to handle PQ-Aura columns

-- 1. Update send_message_v3 to support PQ-Aura
CREATE OR REPLACE FUNCTION public.send_message_v3(
    p_conversation_id UUID,
    p_content TEXT,
    p_message_type TEXT DEFAULT 'text',
    p_media_url TEXT DEFAULT NULL,
    p_media_file_name TEXT DEFAULT NULL,
    p_media_file_size INTEGER DEFAULT NULL,
    p_voice_duration INTEGER DEFAULT NULL,
    p_reply_to_id UUID DEFAULT NULL,
    p_is_ephemeral BOOLEAN DEFAULT FALSE,
    p_ephemeral_duration INTEGER DEFAULT 86400,
    p_encrypted_keys JSONB DEFAULT NULL,
    p_iv TEXT DEFAULT NULL,
    p_signal_message_type INTEGER DEFAULT NULL,
    p_signal_sender_content TEXT DEFAULT NULL,
    p_whisper_mode whisper_mode_type DEFAULT 'OFF',
    p_ripple_id UUID DEFAULT NULL,
    p_story_id UUID DEFAULT NULL,
    p_post_id UUID DEFAULT NULL,
    p_share_data JSONB DEFAULT NULL,
    p_location_data JSONB DEFAULT NULL,
    p_media_view_mode TEXT DEFAULT 'unlimited',
    p_is_spoiler BOOLEAN DEFAULT FALSE,
    p_pq_aura_header TEXT DEFAULT NULL,
    p_pq_aura_payload TEXT DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sender_id UUID := auth.uid();
    v_message_id UUID := gen_random_uuid();
    v_recipient_id UUID;
    v_is_blocked BOOLEAN;
    v_result JSONB;
BEGIN
    -- Security Check: Ensure authenticated
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Rate Limit Check
    PERFORM public.check_rate_limit(v_sender_id, 'send_message', 1, '1 second');

    -- 1. Check for blocks
    SELECT user_id INTO v_recipient_id
    FROM conversation_participants
    WHERE conversation_id = p_conversation_id
    AND user_id != v_sender_id
    LIMIT 1;

    IF v_recipient_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM blocked_users
            WHERE (blocker_id = v_recipient_id AND blocked_id = v_sender_id)
            OR (blocker_id = v_sender_id AND blocked_id = v_recipient_id)
        ) INTO v_is_blocked;

        IF v_is_blocked THEN
            RAISE EXCEPTION 'Message blocked';
        END IF;
    END IF;

    -- 2. Insert message
    INSERT INTO messages (
        id, conversation_id, sender_id, content, 
        image_url, voice_url, file_url, file_name, file_size,
        reply_to_id, is_ephemeral, ephemeral_duration,
        encrypted_keys, iv, signal_message_type, signal_sender_content,
        voice_duration, whisper_mode,
        ripple_id, story_id, post_id,
        share_data, location_data, media_view_mode,
        is_spoiler,
        pq_aura_header, pq_aura_payload
    ) VALUES (
        v_message_id, p_conversation_id, v_sender_id, p_content,
        CASE WHEN p_message_type IN ('image', 'gif', 'sticker') THEN p_media_url ELSE NULL END,
        CASE WHEN p_message_type = 'voice' THEN p_media_url ELSE NULL END,
        CASE WHEN p_message_type = 'document' THEN p_media_url ELSE NULL END,
        p_media_file_name, p_media_file_size,
        p_reply_to_id, p_is_ephemeral, p_ephemeral_duration,
        p_encrypted_keys, p_iv, p_signal_message_type, p_signal_sender_content,
        p_voice_duration, p_whisper_mode,
        p_ripple_id, p_story_id, p_post_id,
        p_share_data, p_location_data, p_media_view_mode,
        p_is_spoiler,
        p_pq_aura_header, p_pq_aura_payload
    );

    -- 3. Trigger notifications
    INSERT INTO notifications (user_id, type, actor_id, conversation_id, message_id, title, content)
    SELECT 
        cp.user_id, 
        'dm', 
        v_sender_id, 
        p_conversation_id, 
        v_message_id,
        (SELECT username FROM profiles WHERE id = v_sender_id),
        CASE 
            WHEN p_message_type = 'image' THEN 'Sent a photo'
            WHEN p_message_type = 'voice' THEN 'Sent a voice message'
            WHEN p_message_type = 'video' THEN 'Sent a video'
            WHEN p_message_type = 'document' THEN 'Sent a file'
            ELSE p_content
        END
    FROM conversation_participants cp
    WHERE cp.conversation_id = p_conversation_id
    AND cp.user_id != v_sender_id;

    -- 4. Update conversation metadata
    UPDATE conversations
    SET last_message_id = v_message_id,
        last_message_at = NOW()
    WHERE id = p_conversation_id;

    -- 5. Return the created message as JSON
    SELECT json_build_object(
        'id', m.id,
        'conversation_id', m.conversation_id,
        'sender_id', m.sender_id,
        'content', m.content,
        'message_type', p_message_type,
        'media_url', p_media_url,
        'file_name', m.file_name,
        'file_size', m.file_size,
        'reply_to_id', m.reply_to_id,
        'is_ephemeral', m.is_ephemeral,
        'ephemeral_duration', m.ephemeral_duration,
        'whisper_mode', m.whisper_mode,
        'is_spoiler', m.is_spoiler,
        'created_at', m.created_at,
        'pq_aura_header', m.pq_aura_header,
        'pq_aura_payload', m.pq_aura_payload,
        'sender_profile', (SELECT json_build_object('username', username, 'avatar_url', avatar_url) FROM profiles WHERE id = v_sender_id)
    ) INTO v_result
    FROM messages m
    WHERE m.id = v_message_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- 2. Update get_user_conversations_v2 to include PQ-Aura columns
CREATE OR REPLACE FUNCTION get_user_conversations_v2()
RETURNS TABLE (
    id UUID,
    type TEXT,
    name TEXT,
    image_url TEXT,
    is_whisper_mode BOOLEAN,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    unread_count INTEGER,
    cleared_at TIMESTAMPTZ,
    all_participants JSONB,
    last_message_data JSONB,
    sort_time TIMESTAMPTZ
) 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    RETURN QUERY
    WITH user_convs AS (
        SELECT 
            c.id,
            c.type,
            c.name,
            c.image_url,
            c.is_whisper_mode,
            c.created_at,
            c.updated_at,
            cp.cleared_at as my_cleared,
            cp.last_read_at as my_last_read
        FROM conversations c
        JOIN conversation_participants cp ON c.id = cp.conversation_id
        WHERE cp.user_id = v_user_id
    ),
    unread_counts AS (
        SELECT 
            uc.id as conversation_id,
            COUNT(m.id)::int as count
        FROM user_convs uc
        LEFT JOIN messages m ON m.conversation_id = uc.id
            AND m.sender_id != v_user_id
            AND (m.created_at > uc.my_last_read OR uc.my_last_read IS NULL)
            AND (uc.my_cleared IS NULL OR m.created_at > uc.my_cleared)
        GROUP BY uc.id
    ),
    latest_msgs AS (
        SELECT DISTINCT ON (m.conversation_id)
            m.conversation_id,
            m.id as msg_id,
            m.content as msg_content,
            m.sender_id as msg_sender_id,
            m.created_at as msg_created_at,
            m.image_url as msg_image_url,
            m.video_url as msg_video_url,
            m.file_url as msg_file_url,
            m.voice_url as msg_voice_url,
            m.iv as msg_iv,
            m.encrypted_keys as msg_encrypted_keys,
            m.signal_message_type as msg_signal_type,
            m.signal_sender_content as msg_signal_sender_content,
            m.pq_aura_header as msg_pq_aura_header,
            m.pq_aura_payload as msg_pq_aura_payload
        FROM messages m
        JOIN user_convs uc ON m.conversation_id = uc.id
        WHERE uc.my_cleared IS NULL OR m.created_at > uc.my_cleared
        ORDER BY m.conversation_id, m.created_at DESC
    )
    SELECT 
        uc.id,
        uc.type,
        uc.name,
        uc.image_url,
        uc.is_whisper_mode,
        uc.created_at,
        uc.updated_at,
        COALESCE(ur.count, 0) as unread_count,
        uc.my_cleared as cleared_at,
        (
            SELECT jsonb_agg(jsonb_build_object(
                'user_id', cp2.user_id,
                'profile', jsonb_build_object(
                    'username', p.username,
                    'full_name', p.full_name,
                    'avatar_url', p.avatar_url
                )
            ))
            FROM conversation_participants cp2
            JOIN profiles p ON cp2.user_id = p.id
            WHERE cp2.conversation_id = uc.id
        ) as all_participants,
        CASE 
            WHEN lm.msg_id IS NOT NULL THEN
                jsonb_build_object(
                    'id', lm.msg_id,
                    'content', lm.msg_content,
                    'sender_id', lm.msg_sender_id,
                    'created_at', lm.msg_created_at,
                    'image_url', lm.msg_image_url,
                    'video_url', lm.msg_video_url,
                    'file_url', lm.msg_file_url,
                    'voice_url', lm.msg_voice_url,
                    'iv', lm.msg_iv,
                    'encrypted_keys', lm.msg_encrypted_keys,
                    'signal_message_type', lm.msg_signal_type,
                    'signal_sender_content', lm.msg_signal_sender_content,
                    'pq_aura_header', lm.msg_pq_aura_header,
                    'pq_aura_payload', lm.msg_pq_aura_payload
                )
            ELSE NULL
        END as last_message_data,
        COALESCE(lm.msg_created_at, uc.created_at) as sort_time
    FROM user_convs uc
    LEFT JOIN unread_counts ur ON uc.id = ur.conversation_id
    LEFT JOIN latest_msgs lm ON uc.id = lm.conversation_id
    ORDER BY sort_time DESC;
END;
$$ LANGUAGE plpgsql;

NOTIFY pgrst, 'reload schema';
