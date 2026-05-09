-- Year-7 hard-purge cron: drops the pseudonymized public.users tombstone
-- and anything that still references it (mostly notification_events
-- audit rows and the doctor_patients.prior_user_id link). At this point
-- the doctor's manual_patient record is fully self-contained — clinical
-- history was forked at day 30 by fn_cron_account_deletion_finalize, so
-- removing the tombstone has no clinical impact.
--
-- Why 7 years: matches the Syrian medical-records retention norm we
-- chose as the upper bound. Adjust by editing the interval below if
-- legal advice settles on a different number.
--
-- This cron runs daily at 02:30 UTC (30 min after the day-30 finalize
-- so the two never race).

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_cron_account_deletion_hard_purge()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  u           record;
  v_purged    integer := 0;
BEGIN
  FOR u IN
    SELECT id
      FROM public.users
     WHERE deletion_pseudonymized_at IS NOT NULL
       AND deletion_pseudonymized_at < now() - interval '7 years'
  LOOP
    -- Sever the doctor_patients audit link so the FK on prior_user_id
    -- doesn't block the delete. The was_docsera_user flag and the
    -- docsera_account_deleted_at timestamp stay so the doctor's badge
    -- keeps reading "former DocSera user".
    UPDATE public.doctor_patients
       SET prior_user_id = NULL
     WHERE prior_user_id = u.id;

    -- Drop notification_events audit rows for this user. Audit retention
    -- ends with the user record itself.
    DELETE FROM public.notification_events e
     USING public.notifications n
     WHERE e.notification_id = n.id
       AND n.user_id = u.id;

    -- Sweep any leftover patient-side rows that the day-30 finalize
    -- missed (defensive — shouldn't normally have any).
    DELETE FROM public.notifications     WHERE user_id = u.id;
    DELETE FROM public.user_devices      WHERE user_id = u.id;
    DELETE FROM public.patient_health_profile WHERE user_id = u.id;

    -- Drop the public.users tombstone.
    BEGIN
      DELETE FROM public.users WHERE id = u.id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'fn_cron_account_deletion_hard_purge: delete users.% failed: %', u.id, SQLERRM;
      CONTINUE;
    END;

    v_purged := v_purged + 1;
  END LOOP;

  IF v_purged > 0 THEN
    RAISE NOTICE 'fn_cron_account_deletion_hard_purge: purged % users', v_purged;
  END IF;
  RETURN v_purged;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_account_deletion_hard_purge() FROM PUBLIC;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping schedule.';
    RETURN;
  END IF;

  PERFORM cron.unschedule('notif_account_deletion_hard_purge')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notif_account_deletion_hard_purge');

  PERFORM cron.schedule(
    'notif_account_deletion_hard_purge',
    '30 2 * * *',  -- daily 02:30 UTC, after the day-30 finalize at 02:00
    $cmd$ SELECT public.fn_cron_account_deletion_hard_purge() $cmd$
  );
END $$;

COMMIT;
