-- RPC to create a group conversation
CREATE OR REPLACE FUNCTION create_group_conversation(
    p_name TEXT,
    p_participant_ids UUID[],
    p_created_by UUID
) RETURNS UUID AS $$
DECLARE
    v_conversation_id UUID;
    v_participant_id UUID;
BEGIN
    -- Create the conversation
    INSERT INTO public.conversations (type, name, created_by)
    VALUES ('group', p_name, p_created_by)
    RETURNING id INTO v_conversation_id;

    -- Add all participants (including creator)
    FOREACH v_participant_id IN ARRAY p_participant_ids
    LOOP
        INSERT INTO public.conversation_participants (conversation_id, user_id, role)
        VALUES (v_conversation_id, v_participant_id, CASE WHEN v_participant_id = p_created_by THEN 'admin' ELSE 'member' END);
    END LOOP;

    RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to add members to a group
CREATE OR REPLACE FUNCTION add_group_members(
    p_conversation_id UUID,
    p_participant_ids UUID[]
) RETURNS VOID AS $$
DECLARE
    v_participant_id UUID;
BEGIN
    FOREACH v_participant_id IN ARRAY p_participant_ids
    LOOP
        INSERT INTO public.conversation_participants (conversation_id, user_id, role)
        VALUES (p_conversation_id, v_participant_id, 'member')
        ON CONFLICT (conversation_id, user_id) DO NOTHING;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
