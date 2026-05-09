-- =============================================================================
-- Server-side appointment reminder cron
-- =============================================================================
-- The patient-app local-reminder path (Dart Timer + flutter_local_notifications)
-- only fires when the user has opened the app between booking and the reminder
-- moment with enough lead time for iOS to register the schedule. Real-world
-- testing showed this misses too often. This migration replaces it with a
-- server cron that runs every minute and fires reminders via Pushy regardless
-- of whether the app is open, closed, or never opened.
--
-- Architecture:
--   1. fn_emit_notification gains a p_hide_from_inbox flag. When true the
--      row is INSERTed with archived_at = now(), so it never appears in
--      the inbox hub but still triggers Pushy (background lock-screen
--      banner) and realtime (foreground in-app banner via the cubit's
--      _onRealtimeChange).
--   2. fn_cron_appointment_reminders runs every minute, finds any
--      live appointment whose T-{24h, 2h, 30m, 0} moment fell in the
--      last ~60 seconds, and emits the matching reminder.
--   3. dedup_key is `apt-rem-{rtype}:{id}` — so even if the cron runs
--      twice in a 60-second window, only one notification per (appt,
--      rtype) lands.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Extend fn_emit_notification with p_hide_from_inbox
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_emit_notification(
  p_user_id          uuid,
  p_recipient_app    text,
  p_event_code       text,
  p_category         text,
  p_locale           text,
  p_title            text,
  p_body             text,
  p_deep_link        text,
  p_data             jsonb   DEFAULT '{}'::jsonb,
  p_importance       text    DEFAULT 'default',
  p_dedup_key        text    DEFAULT NULL,
  p_hide_from_inbox  boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_id uuid;
  v_url text;
  v_anon text;
BEGIN
  INSERT INTO public.notifications
    (user_id, recipient_app, event_code, category, locale,
     title, body, deep_link, data, importance, dedup_key, archived_at)
  VALUES
    (p_user_id, p_recipient_app, p_event_code, p_category, p_locale,
     p_title, p_body, p_deep_link, p_data, p_importance, p_dedup_key,
     CASE WHEN p_hide_from_inbox THEN now() ELSE NULL END)
  ON CONFLICT (user_id, event_code, dedup_key) DO NOTHING
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN NULL;
  END IF;

  BEGIN
    SELECT decrypted_secret INTO v_anon
      FROM vault.decrypted_secrets WHERE name = 'edge_function_anon_key' LIMIT 1;
    SELECT decrypted_secret INTO v_url
      FROM vault.decrypted_secrets WHERE name = 'edge_function_base_url' LIMIT 1;

    IF v_anon IS NOT NULL AND v_url IS NOT NULL THEN
      PERFORM net.http_post(
        url := v_url || '/functions/v1/push_notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || v_anon
        ),
        body := jsonb_build_object(
          'type', 'EMIT',
          'table', '_emit',
          'schema', 'public',
          'record', jsonb_build_object('id', v_id)
        )
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'fn_emit_notification: pg_net call failed (%), row kept', SQLERRM;
  END;

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_emit_notification(
  uuid, text, text, text, text, text, text, text, jsonb, text, text, boolean
) FROM PUBLIC;

-- Drop the old 11-arg signature so callers don't accidentally bypass the
-- hide flag. All callers in this codebase use named args, so this is safe.
DROP FUNCTION IF EXISTS public.fn_emit_notification(
  uuid, text, text, text, text, text, text, text, jsonb, text, text
);

-- ---------------------------------------------------------------------------
-- 2. fn_cron_appointment_reminders — fires T-{24h, 2h, 30m, 0}
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_appointment_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r           record;
  v_locale    text;
  v_title     text;
  v_body      text;
  v_now       timestamptz := now();
  v_window    interval := interval '70 seconds';  -- slightly > cron interval
  v_doctor    text;
  v_time_lbl  text;
  v_emitted   integer := 0;
BEGIN
  FOR r IN
    SELECT
      a.id,
      a.user_id,
      a.doctor_name,
      a.timestamp,
      CASE
        WHEN (a.timestamp - interval '24 hours') BETWEEN v_now - v_window AND v_now THEN 't24h'
        WHEN (a.timestamp - interval '2 hours')  BETWEEN v_now - v_window AND v_now THEN 't2h'
        WHEN (a.timestamp - interval '30 minutes') BETWEEN v_now - v_window AND v_now THEN 't30m'
        WHEN  a.timestamp                          BETWEEN v_now - v_window AND v_now + v_window THEN 't0'
      END AS rtype
    FROM public.appointments a
    WHERE a.user_id IS NOT NULL
      AND a.timestamp > v_now - v_window
      AND a.timestamp < v_now + interval '25 hours'
      AND COALESCE(a.status, '') NOT IN
        ('cancelled', 'cancelled_by_doctor', 'rejected', 'done', 'no_show')
  LOOP
    IF r.rtype IS NULL THEN CONTINUE; END IF;

    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.user_id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    -- doctor name with locale-appropriate fallback. Strip leading "د. "
    -- in EN since we add "Dr." ourselves.
    IF v_locale = 'en' THEN
      v_doctor := COALESCE(
        NULLIF(regexp_replace(r.doctor_name, '^د\.\s*', ''), ''),
        'your doctor'
      );
    ELSE
      v_doctor := COALESCE(NULLIF(trim(r.doctor_name), ''), 'الطبيب');
    END IF;

    v_time_lbl := to_char(r.timestamp AT TIME ZONE 'Asia/Damascus', 'HH12:MI AM');

    IF r.rtype = 't24h' THEN
      IF v_locale = 'en' THEN
        v_title := 'Tomorrow''s appointment';
        v_body  := 'Your appointment with Dr. ' || v_doctor || ' is tomorrow at ' || v_time_lbl || '.';
      ELSE
        v_title := 'موعد الغد';
        v_body  := 'موعدك مع د. ' || v_doctor || ' غدًا الساعة ' || v_time_lbl || '.';
      END IF;
    ELSIF r.rtype = 't2h' THEN
      IF v_locale = 'en' THEN
        v_title := 'Appointment in 2 hours';
        v_body  := 'Your appointment with Dr. ' || v_doctor || ' starts at ' || v_time_lbl || '.';
      ELSE
        v_title := 'موعدك بعد ساعتين';
        v_body  := 'موعدك مع د. ' || v_doctor || ' الساعة ' || v_time_lbl || '.';
      END IF;
    ELSIF r.rtype = 't30m' THEN
      IF v_locale = 'en' THEN
        v_title := 'Appointment in 30 minutes';
        v_body  := 'You''ll be seeing Dr. ' || v_doctor || ' soon — are you on your way?';
      ELSE
        v_title := 'موعدك بعد 30 دقيقة';
        v_body  := 'ستلتقي د. ' || v_doctor || ' قريبًا — هل أنت في الطريق؟';
      END IF;
    ELSIF r.rtype = 't0' THEN
      IF v_locale = 'en' THEN
        v_title := 'Your appointment is now';
        v_body  := 'Dr. ' || v_doctor || ' is ready to see you.';
      ELSE
        v_title := 'حان وقت موعدك';
        v_body  := 'د. ' || v_doctor || ' في انتظارك الآن.';
      END IF;
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id          => r.user_id,
      p_recipient_app    => 'docsera',
      p_event_code       => 'appointment.reminder_' || r.rtype,
      p_category         => 'appointments',
      p_locale           => v_locale,
      p_title            => v_title,
      p_body             => v_body,
      p_deep_link        => 'appointment:' || r.id::text,
      p_data             => jsonb_build_object(
                              'appointment_id', r.id,
                              'reminder_type', r.rtype
                            ),
      p_importance       => CASE WHEN r.rtype IN ('t30m', 't0')
                                 THEN 'time_sensitive' ELSE 'high' END,
      p_dedup_key        => 'apt-rem-' || r.rtype || ':' || r.id::text,
      p_hide_from_inbox  => true
    );

    v_emitted := v_emitted + 1;
  END LOOP;

  IF v_emitted > 0 THEN
    RAISE NOTICE 'fn_cron_appointment_reminders: emitted % reminders', v_emitted;
  END IF;
  RETURN v_emitted;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_appointment_reminders() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. Schedule via pg_cron — every minute
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping schedule.';
    RETURN;
  END IF;

  PERFORM cron.unschedule('notif_appointment_reminders')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notif_appointment_reminders');

  PERFORM cron.schedule(
    'notif_appointment_reminders',
    '* * * * *',  -- every minute
    $cmd$ SELECT public.fn_cron_appointment_reminders() $cmd$
  );
END $$;

COMMIT;

-- Verify after applying:
--   SELECT jobname, schedule, active FROM cron.job WHERE jobname='notif_appointment_reminders';
--   SELECT public.fn_cron_appointment_reminders();   -- manual fire now
