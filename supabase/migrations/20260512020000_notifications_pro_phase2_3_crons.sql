-- =============================================================================
-- Phase 2.3 — Pro-side cron-driven notifications and inbox hygiene.
-- =============================================================================
--
-- Adds:
--   1. fn_cron_pro_overdue_tasks       — daily 06:00 UTC (09:00 Damascus).
--      Finds todo_tasks where due_date < today AND done = false, and
--      emits 'pro.task.overdue' for each. Dedup key includes due_date
--      so the same row gets at most one nudge per day.
--   2. fn_cron_pro_archive_stale_arrivals — every 5 minutes.
--      Archives Pro notifications with event_code
--      'pro.appointment.patient_arrived' older than 30 minutes — they
--      are no longer actionable and clutter the inbox.
--
-- pg_cron extension is already enabled by phase 1.1. Cron jobs are
-- (re)scheduled idempotently at the bottom of this file.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Overdue tasks
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_pro_overdue_tasks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r record;
  v_locale text;
  v_title text;
  v_body text;
  v_assignee uuid;
BEGIN
  FOR r IN
    SELECT t.id, t.text, t.due_date, t.assigned_to, t.created_by, t.center_id
      FROM public.todo_tasks t
     WHERE t.done = false
       AND t.due_date IS NOT NULL
       AND t.due_date < CURRENT_DATE
       -- Only tasks where there is an assignee — unassigned tasks are
       -- inbox clutter for no one in particular.
       AND t.assigned_to IS NOT NULL
  LOOP
    v_assignee := r.assigned_to;

    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = v_assignee AND app = 'docsera_pro'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '⏰ Overdue task';
      v_body := COALESCE(r.text, 'You have an overdue task.');
    ELSE
      v_title := '⏰ مهمة متأخرة';
      v_body := COALESCE(r.text, 'لديك مهمة متأخرة.');
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => v_assignee,
      p_recipient_app => 'docsera_pro',
      p_event_code    => 'pro.task.overdue',
      p_category      => 'tasks',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'todo_task:' || r.id::text,
      p_data          => jsonb_build_object(
                          'todo_task_id', r.id,
                          'due_date', r.due_date,
                          'center_id', r.center_id
                         ),
      p_importance    => 'default',
      -- One emission per task per overdue-day. The dedup_key encodes
      -- the due_date so the same task that's been overdue 3 days fires
      -- on day 1, day 2, day 3 separately — but not multiple times
      -- per day if the cron runs more than once (manual triggers).
      p_dedup_key     => 'pro-task-overdue:' || r.id::text ||
                         ':' || r.due_date::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_overdue_tasks() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_overdue_tasks() IS
  'Phase 2.3 cron: scan todo_tasks for done=false AND due_date<today, '
  'emit pro.task.overdue to assignee. Dedup keyed by (task_id, due_date) '
  'so a task overdue 3 days gets 3 nudges (one per day).';

-- ---------------------------------------------------------------------------
-- 2. Stale "patient arrived" auto-archive
-- ---------------------------------------------------------------------------
--
-- "Patient arrived" is time-sensitive and meant to break DND. Once 30
-- minutes have passed the moment is gone — the row clutters the inbox
-- with no actionable value. Auto-archive (set archived_at) so the row
-- drops out of the default inbox view but remains accessible if the
-- doctor explicitly views archived.

CREATE OR REPLACE FUNCTION public.fn_cron_pro_archive_stale_arrivals()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.notifications
     SET archived_at = now()
   WHERE recipient_app = 'docsera_pro'
     AND event_code = 'pro.appointment.patient_arrived'
     AND archived_at IS NULL
     AND created_at < now() - interval '30 minutes';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_archive_stale_arrivals() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_archive_stale_arrivals() IS
  'Phase 2.3 cron: archive Pro "patient arrived" notifications older '
  'than 30 minutes — no longer actionable. Returns affected row count '
  'for cron job log inspection.';

-- ---------------------------------------------------------------------------
-- Schedule the cron jobs (idempotent)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  -- 1. pro_overdue_tasks — daily 06:00 UTC (≈09:00 Asia/Damascus).
  PERFORM cron.unschedule('pro_overdue_tasks')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pro_overdue_tasks');
  PERFORM cron.schedule(
    'pro_overdue_tasks',
    '0 6 * * *',
    'SELECT public.fn_cron_pro_overdue_tasks()'
  );

  -- 2. pro_archive_stale_arrivals — every 5 minutes.
  PERFORM cron.unschedule('pro_archive_stale_arrivals')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pro_archive_stale_arrivals');
  PERFORM cron.schedule(
    'pro_archive_stale_arrivals',
    '*/5 * * * *',
    'SELECT public.fn_cron_pro_archive_stale_arrivals()'
  );
END $$;

COMMIT;
