-- =============================================================================
-- Pro task reminders — three crons for assigned todo_tasks.
-- =============================================================================
-- The existing pro.task.overdue cron fires only AFTER due_date has passed.
-- Users asked for proactive reminders BEFORE/ON the due date and a weekly
-- nudge for any pending items. todo_tasks.due_date is a DATE (no time),
-- so we interpret the deadline as end-of-day in Asia/Damascus and pick:
--
--   1. pro_task_due_today        — daily 06:00 UTC (09:00 Damascus).
--      "Your task is due today." Once per task per day.
--   2. pro_task_due_soon         — daily 17:00 UTC (20:00 Damascus).
--      ~4 hours before end-of-day on the due date — the "you still
--      haven't done it" nudge. Once per task per day.
--   3. pro_task_pending_weekly   — Sunday 06:00 UTC (09:00 Damascus).
--      Digest: every user with at least one open task gets ONE push
--      with a count, not one push per task. Once per user per ISO week.
--
-- All three target only `assigned_to` users (not the creator). Tasks
-- without an assignee are nobody's responsibility.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Due today
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_pro_task_due_today()
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
BEGIN
  FOR r IN
    SELECT t.id, t.text, t.due_date, t.assigned_to, t.center_id
      FROM public.todo_tasks t
     WHERE t.done = false
       AND t.due_date IS NOT NULL
       AND t.due_date = CURRENT_DATE
       AND t.assigned_to IS NOT NULL
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.assigned_to AND app = 'docsera_pro'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '📋 Task due today';
      v_body  := COALESCE(NULLIF(trim(r.text), ''), 'You have a task due today.');
    ELSE
      v_title := '📋 مهمة مستحقة اليوم';
      v_body  := COALESCE(NULLIF(trim(r.text), ''), 'لديك مهمة مستحقة اليوم.');
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.assigned_to,
      p_recipient_app => 'docsera_pro',
      p_event_code    => 'pro.task.due_today',
      p_category      => 'tasks',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'todo_task:' || r.id::text,
      p_data          => jsonb_build_object(
                          'todo_task_id', r.id,
                          'due_date',     r.due_date,
                          'center_id',    r.center_id
                         ),
      p_importance    => 'high',
      p_dedup_key     => 'pro-task-due-today:' || r.id::text
                       || ':' || r.due_date::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_task_due_today() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_task_due_today() IS
  'Pro task cron: emit pro.task.due_today for tasks with due_date=today, '
  'done=false, assigned_to set. Dedup keyed by (task_id, due_date) so '
  'manual retriggers do not duplicate.';

-- ---------------------------------------------------------------------------
-- 2. Due soon (~4h before end of due day)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_pro_task_due_soon()
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
BEGIN
  FOR r IN
    SELECT t.id, t.text, t.due_date, t.assigned_to, t.center_id
      FROM public.todo_tasks t
     WHERE t.done = false
       AND t.due_date IS NOT NULL
       AND t.due_date = CURRENT_DATE
       AND t.assigned_to IS NOT NULL
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.assigned_to AND app = 'docsera_pro'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '⏰ Task ending soon';
      v_body  := COALESCE(NULLIF(trim(r.text), ''), 'A task is still pending — ends today.');
    ELSE
      v_title := '⏰ المهمة تنتهي قريباً';
      v_body  := COALESCE(NULLIF(trim(r.text), ''), 'مهمة لا تزال معلقة — تنتهي اليوم.');
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.assigned_to,
      p_recipient_app => 'docsera_pro',
      p_event_code    => 'pro.task.due_soon',
      p_category      => 'tasks',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'todo_task:' || r.id::text,
      p_data          => jsonb_build_object(
                          'todo_task_id', r.id,
                          'due_date',     r.due_date,
                          'center_id',    r.center_id
                         ),
      p_importance    => 'high',
      p_dedup_key     => 'pro-task-due-soon:' || r.id::text
                       || ':' || r.due_date::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_task_due_soon() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_task_due_soon() IS
  'Pro task cron: late-day nudge ~4h before end of due_date. Same task '
  'population as due_today; distinct event_code lets users mute one '
  'without the other.';

-- ---------------------------------------------------------------------------
-- 3. Weekly digest of pending tasks
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_pro_task_pending_weekly()
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
  v_week text;
BEGIN
  -- ISO week as YYYY-WW so dedup is week-scoped and stable across timezones.
  v_week := to_char(now() AT TIME ZONE 'Asia/Damascus', 'IYYY-IW');

  -- One row per (assignee, count) — aggregate before the loop so we
  -- emit at most one push per user even if they have 30 open tasks.
  FOR r IN
    SELECT t.assigned_to AS user_id, COUNT(*) AS pending_count
      FROM public.todo_tasks t
     WHERE t.done = false
       AND t.assigned_to IS NOT NULL
     GROUP BY t.assigned_to
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.user_id AND app = 'docsera_pro'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '📋 Pending tasks this week';
      v_body  := 'You have ' || r.pending_count::text
              || CASE WHEN r.pending_count = 1
                      THEN ' open task — check your list.'
                      ELSE ' open tasks — check your list.'
                 END;
    ELSE
      v_title := '📋 مهام معلقة هذا الأسبوع';
      v_body  := 'لديك ' || r.pending_count::text
              || ' مهام مفتوحة — راجع قائمتك.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.user_id,
      p_recipient_app => 'docsera_pro',
      p_event_code    => 'pro.task.pending_weekly',
      p_category      => 'tasks',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'todo_tasks_home',
      p_data          => jsonb_build_object(
                          'pending_count', r.pending_count
                         ),
      p_importance    => 'default',
      p_dedup_key     => 'pro-task-weekly:' || r.user_id::text
                       || ':' || v_week
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_pro_task_pending_weekly() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_cron_pro_task_pending_weekly() IS
  'Pro task cron: Sunday morning digest. One push per assignee with '
  'count of open tasks. Dedup keyed by (user_id, ISO week) so a manual '
  'rerun is a no-op.';

-- ---------------------------------------------------------------------------
-- Schedule the cron jobs (idempotent)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  -- 1. Due today: daily 06:00 UTC (≈09:00 Damascus).
  PERFORM cron.unschedule('pro_task_due_today')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pro_task_due_today');
  PERFORM cron.schedule(
    'pro_task_due_today',
    '0 6 * * *',
    'SELECT public.fn_cron_pro_task_due_today()'
  );

  -- 2. Due soon: daily 17:00 UTC (≈20:00 Damascus, ~4h before midnight).
  PERFORM cron.unschedule('pro_task_due_soon')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pro_task_due_soon');
  PERFORM cron.schedule(
    'pro_task_due_soon',
    '0 17 * * *',
    'SELECT public.fn_cron_pro_task_due_soon()'
  );

  -- 3. Weekly digest: Sunday 06:00 UTC (≈09:00 Damascus).
  PERFORM cron.unschedule('pro_task_pending_weekly')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'pro_task_pending_weekly');
  PERFORM cron.schedule(
    'pro_task_pending_weekly',
    '0 6 * * 0',
    'SELECT public.fn_cron_pro_task_pending_weekly()'
  );
END $$;

COMMIT;
