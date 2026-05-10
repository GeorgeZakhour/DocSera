-- After a password change, the patient may opt to invalidate every
-- OTHER session (e.g. a stolen-credential scenario). Supabase's own
-- auth.signOut(scope: others) handles the JWT side, but trusted_devices
-- is a separate concept that controls whether the new-device 2FA OTP
-- is required at next login. Without clearing it, an attacker on a
-- previously-trusted device could log in with the new password and
-- skip the 2FA challenge.
--
-- This RPC keeps the current device in the trusted set and drops every
-- other entry, so any other device — even one previously trusted —
-- will be forced through the 2FA flow next time it tries to sign in.

CREATE OR REPLACE FUNCTION public.rpc_clear_trusted_devices_except_current(
  p_device_id text
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
  IF p_device_id IS NULL OR length(trim(p_device_id)) = 0 THEN
    RAISE EXCEPTION 'INVALID_DEVICE_ID';
  END IF;

  UPDATE public.users
     SET trusted_devices = ARRAY[p_device_id],
         updated_at = now()
   WHERE id = v_user_id;
END $$;

REVOKE ALL ON FUNCTION public.rpc_clear_trusted_devices_except_current(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_clear_trusted_devices_except_current(text) TO authenticated;
