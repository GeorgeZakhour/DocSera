-- Dedicated RPC for the patient app to write a verified phone onto
-- public.users after the unified verify_phone_otp succeeds. Splits the
-- "validate the code" responsibility (rpc_verify_phone_otp, shared with
-- DocSera-Pro) from the "persist phone on the user row" responsibility
-- (this RPC, patient-only). rpc_update_my_user intentionally does not
-- expose phone_number to avoid letting clients bypass OTP verification.

CREATE OR REPLACE FUNCTION public.rpc_set_my_phone(
  p_phone text,
  p_verified boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  IF p_phone IS NULL OR length(trim(p_phone)) = 0 THEN
    RAISE EXCEPTION 'INVALID_PHONE';
  END IF;

  -- Defense in depth: don't let two users end up with the same phone.
  IF EXISTS (
    SELECT 1 FROM public.users
     WHERE phone_number = p_phone
       AND id <> v_user_id
  ) THEN
    RAISE EXCEPTION 'PHONE_ALREADY_EXISTS';
  END IF;

  UPDATE public.users
     SET phone_number   = p_phone,
         phone_verified = COALESCE(p_verified, true),
         updated_at     = now()
   WHERE id = v_user_id;
END $$;

REVOKE ALL ON FUNCTION public.rpc_set_my_phone(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_set_my_phone(text, boolean) TO authenticated;
