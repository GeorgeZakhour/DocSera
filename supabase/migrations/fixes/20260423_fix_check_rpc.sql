CREATE OR REPLACE FUNCTION rpc_check_email_exists(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_user_email TEXT;
BEGIN
  SELECT email INTO v_user_email FROM public.users WHERE id = v_user_id;
  
  -- If the email perfectly matches the current user's email, we don't consider it a duplicate
  IF p_email = v_user_email THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE email = p_email) OR
     EXISTS (SELECT 1 FROM public.relatives WHERE email = p_email) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_check_phone_exists(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_user_phone TEXT;
BEGIN
  SELECT phone_number INTO v_user_phone FROM public.users WHERE id = v_user_id;

  -- If the phone perfectly matches the current user's phone, we don't consider it a duplicate
  IF p_phone = v_user_phone THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (SELECT 1 FROM public.users WHERE phone_number = p_phone) OR
     EXISTS (SELECT 1 FROM public.relatives WHERE phone_number = p_phone) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;
