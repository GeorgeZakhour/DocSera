-- Function to reliably mark messages as read for the user
-- Escaping RLS by using SECURITY DEFINER to allow the update
CREATE OR REPLACE FUNCTION rpc_mark_messages_read(conversation_uuid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  curr_user_id uuid;
BEGIN
  -- Get current user ID (just for audit or extra checks if needed, but RLS is bypassed)
  curr_user_id := auth.uid();

  -- 1. Mark all doctor messages in this conversation as read by user
  -- where they are not already read
  UPDATE public.messages
  SET 
    read_by_user = true,
    read_by_user_at = now()
  WHERE 
    conversation_id = conversation_uuid
    AND is_user = false -- Only mark messages FROM doctor
    AND read_by_user = false;

  -- 2. Reset the unread count for the user in the conversation
  UPDATE public.conversations
  SET 
    unread_count_for_user = 0,
    last_message_read_by_user = true
  WHERE 
    id = conversation_uuid;

END;
$$;
