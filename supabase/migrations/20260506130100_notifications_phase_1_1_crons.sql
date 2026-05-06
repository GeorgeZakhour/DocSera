-- =============================================================================
-- Phase 1.1: pg_cron jobs for notifications
-- =============================================================================
-- Daily jobs that emit cron-driven notifications and enforce 90-day retention.
-- Times are in UTC (pg_cron uses UTC); comments show Damascus equivalents.
--
-- All times are off-peak so they don't compete with user traffic. Stagger
-- across the morning so each job has its own window for logs.

BEGIN;

-- pg_cron extension must be enabled separately by an operator if not already.
-- This file only creates job functions and schedules.

-- ---------------------------------------------------------------------------
-- 1. Account deletion warning at T-7d (day 23 of the 30-day window)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_deletion_warning_t7d()
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
    SELECT u.id,
           u.deletion_cancellable_until
      FROM public.users u
     WHERE u.deletion_requested_at IS NOT NULL
       AND u.deletion_pseudonymized_at IS NULL
       AND u.deletion_cancellable_until BETWEEN now() + interval '6.5 days'
                                             AND now() + interval '7.5 days'
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '⏳ 7 days left to cancel deletion';
      v_body  := 'Your account will be permanently deleted in 7 days. Tap to cancel before it''s too late.';
    ELSE
      v_title := '⏳ ٧ أيام متبقية لحذف الحساب';
      v_body  := 'سيتم حذف حسابك نهائيًا بعد ٧ أيام. اضغط للإلغاء قبل فوات الأوان.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_warning_t7d',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account_deletion:pending',
      p_data          => jsonb_build_object('days_left', 7),
      p_importance    => 'high',
      p_dedup_key     => 'apt-deletion-t7d:' || r.id::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_deletion_warning_t7d() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 2. Account deletion warning at T-1d (day 29)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_deletion_warning_t1d()
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
    SELECT u.id, u.deletion_cancellable_until
      FROM public.users u
     WHERE u.deletion_requested_at IS NOT NULL
       AND u.deletion_pseudonymized_at IS NULL
       AND u.deletion_cancellable_until BETWEEN now() + interval '12 hours'
                                             AND now() + interval '36 hours'
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '⛔ Account deletes tomorrow';
      v_body  := 'Last chance to cancel your scheduled deletion. Tap now.';
    ELSE
      v_title := '⛔ غدًا سيتم حذف حسابك';
      v_body  := 'هذه آخر فرصة لإلغاء حذف حسابك. اضغط الآن.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_warning_t1d',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account_deletion:pending',
      p_data          => jsonb_build_object('days_left', 1),
      p_importance    => 'time_sensitive',
      p_dedup_key     => 'apt-deletion-t1d:' || r.id::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_deletion_warning_t1d() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. Voucher expiring in 7 days
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_voucher_expiring_7d()
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
    SELECT v.id, v.user_id, v.expires_at
      FROM public.vouchers v
     WHERE v.status = 'active'
       AND v.expires_at BETWEEN now() + interval '6.5 days'
                             AND now() + interval '7.5 days'
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.user_id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '🎁 Your voucher expires in 7 days';
      v_body  := 'Use it before ' || to_char(r.expires_at AT TIME ZONE 'Asia/Damascus', 'DD Mon YYYY') || '.';
    ELSE
      v_title := '🎁 قسيمتك ستنتهي خلال ٧ أيام';
      v_body  := 'استخدمها قبل ' || to_char(r.expires_at AT TIME ZONE 'Asia/Damascus', 'DD/MM/YYYY') || '.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.user_id,
      p_recipient_app => 'docsera',
      p_event_code    => 'loyalty.voucher_expiring_7d',
      p_category      => 'loyalty',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'voucher:' || r.id::text,
      p_data          => jsonb_build_object('voucher_id', r.id, 'expires_at', r.expires_at),
      p_importance    => 'default',
      p_dedup_key     => 'vchexp7:' || r.id::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_voucher_expiring_7d() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 4. Voucher expiring in 1 day
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_voucher_expiring_1d()
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
    SELECT v.id, v.user_id, v.expires_at
      FROM public.vouchers v
     WHERE v.status = 'active'
       AND v.expires_at BETWEEN now() + interval '12 hours'
                             AND now() + interval '36 hours'
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.user_id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '⏰ Your voucher expires tomorrow';
      v_body  := 'Last chance to use it. Tap to view.';
    ELSE
      v_title := '⏰ قسيمتك تنتهي غدًا';
      v_body  := 'هذه آخر فرصة لاستخدامها. اضغط للعرض.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.user_id,
      p_recipient_app => 'docsera',
      p_event_code    => 'loyalty.voucher_expiring_1d',
      p_category      => 'loyalty',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'voucher:' || r.id::text,
      p_data          => jsonb_build_object('voucher_id', r.id, 'expires_at', r.expires_at),
      p_importance    => 'high',
      p_dedup_key     => 'vchexp1:' || r.id::text
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_voucher_expiring_1d() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 5. Message long unread (>= 48h, max once per conversation)
-- ---------------------------------------------------------------------------
-- Find unread messages from doctors that are 48h+ old, where this conversation
-- hasn't already received a long_unread notification (dedup_key is conversation
-- id so we only nag once until the user reads or doctor sends a new message).

CREATE OR REPLACE FUNCTION public.fn_cron_message_long_unread()
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
    SELECT DISTINCT ON (m.conversation_id)
           m.conversation_id,
           m.created_at,
           c.patient_id,
           c.relative_id,
           c.doctor_name,
           extract(epoch from now() - m.created_at)/3600 AS hours_old
      FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
     WHERE m.is_user = false
       AND COALESCE(m.is_seen, false) = false
       AND m.created_at < now() - interval '48 hours'
       AND m.created_at > now() - interval '14 days'  -- don't haunt old threads
     ORDER BY m.conversation_id, m.created_at DESC
  LOOP
    IF r.patient_id IS NULL THEN CONTINUE; END IF;

    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = r.patient_id AND app = 'docsera'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := 'Unread message from Dr. ' || COALESCE(r.doctor_name, 'your doctor');
      v_body  := 'You have a message you haven''t read in ' || floor(r.hours_old/24)::text || ' days.';
    ELSE
      v_title := 'رسالة غير مقروءة من د. ' || COALESCE(r.doctor_name, 'الطبيب');
      v_body  := 'لديك رسالة لم تقرأها منذ ' || floor(r.hours_old/24)::text || ' أيام.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => r.patient_id,
      p_recipient_app => 'docsera',
      p_event_code    => 'message.long_unread',
      p_category      => 'messages',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'conversation:' || r.conversation_id::text,
      p_data          => jsonb_build_object('conversation_id', r.conversation_id),
      p_importance    => 'default',
      p_dedup_key     => 'longunread:' || r.conversation_id::text || ':' || to_char(r.created_at, 'YYYYMMDD')
    );
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_message_long_unread() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 6. 90-day retention: hard delete notifications older than 90 days
-- ---------------------------------------------------------------------------
-- The FK on notification_events was changed to ON DELETE SET NULL in the
-- companion migration, so events are preserved even after the notifications
-- row is purged.

CREATE OR REPLACE FUNCTION public.fn_cron_notifications_retention_90d()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM public.notifications
   WHERE created_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted > 0 THEN
    RAISE NOTICE 'fn_cron_notifications_retention_90d: deleted % rows', v_deleted;
  END IF;
  RETURN v_deleted;
END $$;

REVOKE ALL ON FUNCTION public.fn_cron_notifications_retention_90d() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 7. Schedule with pg_cron
-- ---------------------------------------------------------------------------
-- All times in UTC. Damascus is UTC+3, so subtract 3h from the local time.
-- Spread across the morning so logs stay readable.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping cron schedule. Run CREATE EXTENSION pg_cron; first.';
    RETURN;
  END IF;

  -- 06:00 UTC = 09:00 Damascus
  PERFORM cron.unschedule('notif_deletion_warning_t7d') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_deletion_warning_t7d');
  PERFORM cron.schedule(
    'notif_deletion_warning_t7d', '0 6 * * *',
    $cmd$ SELECT public.fn_cron_deletion_warning_t7d() $cmd$);

  PERFORM cron.unschedule('notif_deletion_warning_t1d') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_deletion_warning_t1d');
  PERFORM cron.schedule(
    'notif_deletion_warning_t1d', '5 6 * * *',
    $cmd$ SELECT public.fn_cron_deletion_warning_t1d() $cmd$);

  -- 07:00 UTC = 10:00 Damascus
  PERFORM cron.unschedule('notif_voucher_expiring_7d') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_voucher_expiring_7d');
  PERFORM cron.schedule(
    'notif_voucher_expiring_7d', '0 7 * * *',
    $cmd$ SELECT public.fn_cron_voucher_expiring_7d() $cmd$);

  PERFORM cron.unschedule('notif_voucher_expiring_1d') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_voucher_expiring_1d');
  PERFORM cron.schedule(
    'notif_voucher_expiring_1d', '5 7 * * *',
    $cmd$ SELECT public.fn_cron_voucher_expiring_1d() $cmd$);

  -- 08:00 UTC = 11:00 Damascus
  PERFORM cron.unschedule('notif_message_long_unread') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_message_long_unread');
  PERFORM cron.schedule(
    'notif_message_long_unread', '0 8 * * *',
    $cmd$ SELECT public.fn_cron_message_long_unread() $cmd$);

  -- 00:00 UTC = 03:00 Damascus — quiet hour for retention sweep.
  PERFORM cron.unschedule('notif_retention_90d') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'notif_retention_90d');
  PERFORM cron.schedule(
    'notif_retention_90d', '0 0 * * *',
    $cmd$ SELECT public.fn_cron_notifications_retention_90d() $cmd$);
END $$;

COMMIT;

-- Verify after applying:
--   SELECT jobname, schedule, command FROM cron.job
--    WHERE jobname LIKE 'notif_%' ORDER BY jobname;
