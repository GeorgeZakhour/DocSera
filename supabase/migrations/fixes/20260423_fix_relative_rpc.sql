-- Return type changed from the previous version, so CREATE OR REPLACE fails
-- with 42P13. Drop then recreate, and re-grant EXECUTE (DROP wipes grants).
DROP FUNCTION IF EXISTS rpc_add_my_relative(JSONB);

CREATE FUNCTION rpc_add_my_relative(p_data JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_relative_id UUID;
  v_email TEXT;
  v_phone TEXT;
  v_user_email TEXT;
  v_user_phone TEXT;
BEGIN
  v_email := p_data->>'email';
  v_phone := p_data->>'phone_number';

  SELECT email, phone_number INTO v_user_email, v_user_phone
  FROM public.users WHERE id = v_user_id;

  -- Validate email is unique (allow if it matches the parent user's email)
  IF v_email IS NOT NULL AND v_email != '' AND v_email != v_user_email THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE email = v_email) OR
       EXISTS (SELECT 1 FROM public.relatives WHERE email = v_email AND user_id != v_user_id) THEN
      RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    END IF;
  END IF;

  -- Validate phone is unique (allow if it matches the parent user's phone)
  IF v_phone IS NOT NULL AND v_phone != '' AND v_phone != v_user_phone THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE phone_number = v_phone) OR
       EXISTS (SELECT 1 FROM public.relatives WHERE phone_number = v_phone AND user_id != v_user_id) THEN
      RAISE EXCEPTION 'PHONE_ALREADY_EXISTS';
    END IF;
  END IF;

  INSERT INTO public.relatives (
    user_id,
    first_name,
    last_name,
    gender,
    date_of_birth,
    email,
    phone_number,
    address,
    is_active
  ) VALUES (
    v_user_id,
    p_data->>'first_name',
    p_data->>'last_name',
    p_data->>'gender',
    (p_data->>'date_of_birth')::timestamp,
    v_email,
    v_phone,
    p_data->'address',
    true
  ) RETURNING id INTO v_relative_id;

  RETURN jsonb_build_object('id', v_relative_id);
END;
$$;

DROP FUNCTION IF EXISTS rpc_update_my_relative(UUID, JSONB);

CREATE FUNCTION rpc_update_my_relative(p_relative_id UUID, p_data JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email TEXT;
  v_phone TEXT;
  v_user_email TEXT;
  v_user_phone TEXT;
BEGIN
  -- Ensure the relative belongs to the user
  IF NOT EXISTS (SELECT 1 FROM public.relatives WHERE id = p_relative_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  v_email := p_data->>'email';
  v_phone := p_data->>'phone_number';

  SELECT email, phone_number INTO v_user_email, v_user_phone
  FROM public.users WHERE id = v_user_id;

  -- Validate email is unique (allow if it matches the parent user's email)
  IF v_email IS NOT NULL AND v_email != '' AND v_email != v_user_email THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE email = v_email) OR
       EXISTS (SELECT 1 FROM public.relatives WHERE email = v_email AND id != p_relative_id) THEN
      RAISE EXCEPTION 'EMAIL_ALREADY_EXISTS';
    END IF;
  END IF;

  -- Validate phone is unique (allow if it matches the parent user's phone)
  IF v_phone IS NOT NULL AND v_phone != '' AND v_phone != v_user_phone THEN
    IF EXISTS (SELECT 1 FROM public.users WHERE phone_number = v_phone) OR
       EXISTS (SELECT 1 FROM public.relatives WHERE phone_number = v_phone AND id != p_relative_id) THEN
      RAISE EXCEPTION 'PHONE_ALREADY_EXISTS';
    END IF;
  END IF;

  UPDATE public.relatives SET
    first_name = COALESCE(p_data->>'first_name', first_name),
    last_name = COALESCE(p_data->>'last_name', last_name),
    gender = COALESCE(p_data->>'gender', gender),
    date_of_birth = COALESCE((p_data->>'date_of_birth')::timestamp, date_of_birth),
    email = v_email,
    phone_number = v_phone,
    address = COALESCE(p_data->'address', address),
    updated_at = NOW()
  WHERE id = p_relative_id AND user_id = v_user_id;

  RETURN (SELECT to_jsonb(r) FROM public.relatives r WHERE r.id = p_relative_id);
END;
$$;

-- Mirror rpc_get_my_relatives grants (Supabase default). The SECURITY DEFINER
-- body gates access via auth.uid(), so PUBLIC EXECUTE is safe here.
GRANT EXECUTE ON FUNCTION rpc_add_my_relative(JSONB) TO PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_update_my_relative(UUID, JSONB) TO PUBLIC;
