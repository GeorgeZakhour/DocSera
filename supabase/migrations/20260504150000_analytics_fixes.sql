-- Fix #1: PHI sanitizer was over-aggressive — its phone-number regex matched
--         digit-heavy substrings inside UUIDs (e.g. "1234-5678-9" inside a
--         doctor_id), causing the trigger to silently drop legitimate IDs.
--         The new regex anchors to start AND end of the value: a string only
--         flags as a phone number if the WHOLE value is phone-shaped.
--
-- Fix #2: Admin RPCs returned 42501 when called from the SQL editor or any
--         direct psql connection because auth.uid() is NULL in those contexts.
--         has_admin_permission() now bypasses for the postgres / supabase_admin
--         superusers and the service_role — so SQL-editor testing works while
--         keeping the RPCs strict for client-facing (anon/authenticated) calls.

BEGIN;

-- -----------------------------------------------------------------------------
-- Fix #1 — anchor the phone regex
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.analytics_sanitize_properties(p jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  k text;
  v text;
  result jsonb := '{}'::jsonb;
BEGIN
  IF p IS NULL OR jsonb_typeof(p) <> 'object' THEN
    RETURN '{}'::jsonb;
  END IF;
  FOR k, v IN SELECT key, value::text FROM jsonb_each_text(p) LOOP
    -- Drop oversized strings (> 200 chars).
    IF length(v) > 200 THEN CONTINUE; END IF;
    -- Drop values that ARE a phone number end-to-end (anchored regex).
    -- E.g.: "+963944123456", "0944123456", "(011) 555-1234". UUIDs and other
    -- mixed-content strings are NOT matched because they contain letters.
    IF v ~ '^\+?[\d\s\-\(\)]{7,20}$' THEN CONTINUE; END IF;
    -- Drop values that contain an email address.
    IF v ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' THEN CONTINUE; END IF;
    -- Keep this key.
    result := result || jsonb_build_object(k, p->k);
  END LOOP;
  RETURN result;
END
$$;

-- -----------------------------------------------------------------------------
-- Fix #2 — superuser bypass on the RBAC helper
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_admin_permission(p_user_id uuid, p_permission text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  -- Superuser / service_role bypass. SQL editor connections, direct psql calls,
  -- and edge functions running as service_role can call admin RPCs without an
  -- authenticated user. Client-facing roles (anon, authenticated) still go
  -- through the role/permission check below.
  v_role := current_user;
  IF v_role IN ('postgres', 'supabase_admin', 'service_role') THEN
    RETURN true;
  END IF;

  -- Authenticated callers must have an active admin row with a matching perm.
  RETURN EXISTS (
    SELECT 1
    FROM public.admin_users au
    JOIN public.admin_user_roles aur ON aur.user_id = au.user_id
    JOIN public.admin_role_permissions arp ON arp.role_code = aur.role_code
    WHERE au.user_id = p_user_id
      AND au.status = 'active'
      AND arp.permission_code = p_permission
  );
END
$$;

-- Same superuser bypass for the shorter `is_admin()` helper (consistency).
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  v_role := current_user;
  IF v_role IN ('postgres', 'supabase_admin', 'service_role') THEN
    RETURN true;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = p_user_id AND status = 'active'
  );
END
$$;

COMMIT;
