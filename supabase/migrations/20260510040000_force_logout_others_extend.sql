-- Extend rpc_clear_trusted_devices_except_current to also delete the
-- user_devices rows of every OTHER device. The patient app subscribes
-- to its own user_devices row via Supabase realtime; when the row is
-- deleted, the app signs out immediately. End result: changing the
-- password with "sign out other devices" checked kicks every other
-- session within ~1 second, not "up to 1 hour" (the access-token TTL).
--
-- The function takes:
--   p_device_id : the trusted_devices fingerprint (iOS identifierForVendor
--                 or Android Settings.Secure.ANDROID_ID) we want to KEEP.
--   p_pushy_token: the Pushy token of the row we want to KEEP in
--                  user_devices. Different concept from p_device_id —
--                  user_devices is keyed by (user, token, app), not by
--                  device fingerprint, so we need this separately.
-- If p_pushy_token is NULL/empty we still clear trusted_devices but
-- leave user_devices alone (best-effort fallback for rare cases where
-- the patient app doesn't have a token cached).

DROP FUNCTION IF EXISTS public.rpc_clear_trusted_devices_except_current(text);

CREATE FUNCTION public.rpc_clear_trusted_devices_except_current(
  p_device_id text,
  p_pushy_token text DEFAULT NULL
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

  -- Keep only this device in the trusted set.
  UPDATE public.users
     SET trusted_devices = ARRAY[p_device_id],
         updated_at = now()
   WHERE id = v_user_id;

  -- Drop every OTHER user_devices row so realtime DELETE fires on
  -- those devices and they sign out instantly (the patient app's
  -- listener handles that).
  IF p_pushy_token IS NOT NULL AND length(trim(p_pushy_token)) > 0 THEN
    DELETE FROM public.user_devices
     WHERE user_id = v_user_id
       AND token <> p_pushy_token;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.rpc_clear_trusted_devices_except_current(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_clear_trusted_devices_except_current(text, text) TO authenticated;
