-- Daily prune of stale user_devices rows. Catches orphans that slip
-- past:
--   * the on-logout cleanup (NotificationService.deleteToken)
--   * the on-launch self-clean (drops other rows for our token)
--
-- Belt-and-braces: if a logout path crashes mid-flight or an old build
-- is still running on someone's device, the cron sweeps the row after
-- 90 days. Pushy tokens last forever, but a token that hasn't been
-- refreshed in 3 months is statistically dead.
--
-- "last_seen_at" is updated every time the patient app launches with
-- a valid session (see _saveDeviceTokenToSupabase). NULL means never
-- refreshed since the row was inserted — those rows go too.

CREATE OR REPLACE FUNCTION public.fn_cron_user_devices_prune()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted integer;
BEGIN
  WITH del AS (
    DELETE FROM public.user_devices
     WHERE last_seen_at IS NULL
        OR last_seen_at < now() - interval '90 days'
    RETURNING id
  )
  SELECT count(*) INTO v_deleted FROM del;

  IF v_deleted > 0 THEN
    RAISE NOTICE 'fn_cron_user_devices_prune: pruned % stale device rows', v_deleted;
  END IF;
  RETURN v_deleted;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_user_devices_prune() FROM PUBLIC;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping schedule.';
    RETURN;
  END IF;

  PERFORM cron.unschedule('user_devices_prune')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'user_devices_prune');

  PERFORM cron.schedule(
    'user_devices_prune',
    '15 3 * * *',  -- daily 03:15 UTC, after the deletion crons at 02:00/02:30
    $cmd$ SELECT public.fn_cron_user_devices_prune() $cmd$
  );
END $$;
