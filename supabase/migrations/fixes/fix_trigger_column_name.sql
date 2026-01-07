-- FIX: The trigger function was referencing "content" column which does not exist (it is named "text").
-- This caused updates (like marking as read) to fail.

CREATE OR REPLACE FUNCTION trg_prevent_message_content_update()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
  -- We check NEW.text instead of NEW.content
  IF NEW.text IS DISTINCT FROM OLD.text THEN
      RAISE EXCEPTION 'Modification of message text is not allowed.';
  END IF;
  
  -- Allow other updates (like read_by_user, read_by_doctor, etc.) to proceed
  RETURN NEW;
END;
$$;
