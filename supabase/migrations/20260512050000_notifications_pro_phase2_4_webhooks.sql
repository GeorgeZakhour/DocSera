-- =============================================================================
-- Phase 2.4 — Webhook triggers for Pro verification + subscription events
-- =============================================================================
-- Wires doctor_verifications + subscriptions through the
-- push_notifications edge function. Reuses the bearer token from the
-- existing appointment-updates trigger (same pattern as the team
-- webhook migration).

BEGIN;

DO $$
DECLARE
  v_auth text;
  v_url  text := 'https://api.docsera.app/functions/v1/push_notifications';
BEGIN
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
    RAISE NOTICE 'No existing webhook trigger found to copy auth from — skipping verification/subscription webhook setup.';
    RETURN;
  END IF;

  -- doctor_verifications: INSERT (submission), UPDATE (status / partial-doc flips)
  EXECUTE format(
    'DROP TRIGGER IF EXISTS "pro-verifications" ON public.doctor_verifications'
  );
  EXECUTE format(
    'CREATE TRIGGER "pro-verifications" '
    'AFTER INSERT OR UPDATE ON public.doctor_verifications '
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

  -- subscriptions: UPDATE only (renewal detection)
  EXECUTE format(
    'DROP TRIGGER IF EXISTS "pro-subscriptions" ON public.subscriptions'
  );
  EXECUTE format(
    'CREATE TRIGGER "pro-subscriptions" '
    'AFTER UPDATE ON public.subscriptions '
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

  RAISE NOTICE 'pro-verifications and pro-subscriptions webhooks wired.';
END $$;

COMMIT;
