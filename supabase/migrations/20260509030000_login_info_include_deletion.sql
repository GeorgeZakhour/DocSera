-- Allow login during the 30-day account-deletion grace window. The account
-- is_active flag is flipped to false the moment deletion is requested
-- (rpc_request_account_deletion) so the user can't log in to cancel the
-- deletion — they're trapped behind the same "account disabled" message
-- that's used for permanent bans. Fix: surface deletion_requested_at to the
-- pre-auth check so the client can distinguish a soft "pending deletion"
-- state from a hard "disabled" state and allow the former to log in,
-- routing to the pending-deletion screen on the way to home.

DROP FUNCTION IF EXISTS public.rpc_get_login_info(text);

CREATE FUNCTION public.rpc_get_login_info(p_identifier text)
RETURNS TABLE(
  email text,
  is_active boolean,
  user_id uuid,
  deletion_requested_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  p_identifier := lower(trim(p_identifier));

  RETURN QUERY
  SELECT
    u.email,
    coalesce(u.is_active, true) AS is_active,
    u.id AS user_id,
    u.deletion_requested_at
  FROM public.users u
  WHERE
    lower(u.email) = p_identifier
    OR u.phone_number = p_identifier
  LIMIT 1;
END;
$$;
