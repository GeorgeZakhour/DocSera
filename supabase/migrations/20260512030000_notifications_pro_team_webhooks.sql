-- =============================================================================
-- Phase 2.3 — Webhook triggers for Pro team events
-- =============================================================================
-- Wires center_invitations + center_members INSERT/UPDATE through the
-- push_notifications edge function so the dispatcher's `pro_team`
-- handler fires for each lifecycle event.
--
-- Reuses the same supabase_functions.http_request(...) trigger pattern
-- as the existing appointment-updates trigger (see information_schema
-- inspection in deployment runbook). The service-role bearer token is
-- read out of an existing trigger so the values stay consistent and
-- there's no secret-in-this-migration.

BEGIN;

DO $$
DECLARE
  v_auth text;
  v_url  text := 'https://api.docsera.app/functions/v1/push_notifications';
BEGIN
  -- Snapshot the bearer token from the existing appointment-updates
  -- trigger. If it isn't present (fresh environment), this migration
  -- silently no-ops on the team triggers and the operator can re-run
  -- once webhooks for any other table are wired up.
  SELECT regexp_replace(
           action_statement,
           '.*Authorization":"Bearer ([^"]+)".*',
           '\1'
         )
    INTO v_auth
    FROM information_schema.triggers
   WHERE trigger_name = 'appointment-updates'
   LIMIT 1;

  IF v_auth IS NULL OR length(v_auth) < 30 THEN
    RAISE NOTICE 'No existing webhook trigger found to copy auth from — skipping team-webhook setup. Re-run once another table has a hook.';
    RETURN;
  END IF;

  -- center_invitations: INSERT (invitation received), UPDATE (accepted/declined)
  EXECUTE format(
    'DROP TRIGGER IF EXISTS "pro-team-invitations" ON public.center_invitations'
  );
  EXECUTE format(
    'CREATE TRIGGER "pro-team-invitations" '
    'AFTER INSERT OR UPDATE ON public.center_invitations '
    'FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(%L, %L, %L, %L, %L)',
    v_url,
    'POST',
    json_build_object(
      'Content-type', 'application/json',
      'Authorization', 'Bearer ' || v_auth
    )::text,
    '{}',
    '10000'
  );

  -- center_members: INSERT (member added), UPDATE (role/perms/assignments/removal)
  EXECUTE format(
    'DROP TRIGGER IF EXISTS "pro-team-members" ON public.center_members'
  );
  EXECUTE format(
    'CREATE TRIGGER "pro-team-members" '
    'AFTER INSERT OR UPDATE ON public.center_members '
    'FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request(%L, %L, %L, %L, %L)',
    v_url,
    'POST',
    json_build_object(
      'Content-type', 'application/json',
      'Authorization', 'Bearer ' || v_auth
    )::text,
    '{}',
    '10000'
  );

  RAISE NOTICE 'pro-team-invitations and pro-team-members webhooks wired.';
END $$;

COMMIT;
