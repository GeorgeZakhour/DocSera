-- When the calling device has no Pushy token cached (e.g. iOS hasn't
-- completed registration yet, or the row was pruned), the previous
-- version of rpc_clear_trusted_devices_except_current did NOT delete
-- any user_devices rows — making the realtime force-logout silently
-- ineffective for the most common iOS test path.
--
-- Fix: when p_pushy_token is null/empty, delete ALL user_devices rows
-- for this user. Rationale: the calling device isn't in the table
-- anyway, so "every other row" == "every row". The realtime DELETE
-- listener fires on each affected device and signs it out instantly.
--
-- trusted_devices clearing is unchanged: always set to ARRAY[p_device_id].

DROP FUNCTION IF EXISTS public.rpc_clear_trusted_devices_except_current(text, text);

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

  -- Drop OTHER user_devices rows so realtime DELETE fires on those
  -- devices and they sign out instantly.
  IF p_pushy_token IS NOT NULL AND length(trim(p_pushy_token)) > 0 THEN
    DELETE FROM public.user_devices
     WHERE user_id = v_user_id
       AND token <> p_pushy_token;
  ELSE
    -- No token to preserve → calling device isn't represented in the
    -- table → every row IS "other". Wipe them all.
    DELETE FROM public.user_devices
     WHERE user_id = v_user_id;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.rpc_clear_trusted_devices_except_current(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_clear_trusted_devices_except_current(text, text) TO authenticated;
