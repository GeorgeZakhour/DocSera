-- =============================================================================
-- Phase 2 follow-up: security events for DocSera-Pro
-- =============================================================================
-- The patient app already fires security.* notifications via
-- fn_notify_auth_change + fn_notify_new_device_login (see
-- 20260506130000_notifications_phase_1_1.sql). Those functions
-- hardcode recipient_app='docsera'. This migration replaces them
-- with dual-firing variants that emit ONCE PER APP the user has a
-- device registered on, so a doctor signed in on both DocSera and
-- DocSera-Pro gets the security notice on both surfaces.
--
-- Dedup keys are now scoped per (event, user, app, …) to prevent
-- the (user_id, event_code, dedup_key) unique index from collapsing
-- the docsera + docsera_pro emissions into a single row.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Auth change (password / email / phone) — dual-fire
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_notify_auth_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_event   text;
  v_dedup   text;
  app_row   record;
  v_locale  text;
  v_title   text;
  v_body    text;
BEGIN
  -- Determine which field changed.
  IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    v_event := 'security.password_changed';
    -- Per-event-time dedup so future password changes always emit.
    v_dedup := 'pwd:' || NEW.id::text || ':'
            || extract(epoch from now())::bigint::text;
  ELSIF NEW.email IS DISTINCT FROM OLD.email THEN
    v_event := 'security.email_changed';
    v_dedup := 'email:' || NEW.id::text || ':' || COALESCE(NEW.email, '');
  ELSIF NEW.phone IS DISTINCT FROM OLD.phone THEN
    v_event := 'security.phone_changed';
    v_dedup := 'phone:' || NEW.id::text || ':' || COALESCE(NEW.phone, '');
  ELSE
    RETURN NEW;
  END IF;

  -- Fire one notification per app the user has a registered device on.
  -- This way a doctor with both the patient app and Pro sees the
  -- security event in both inboxes / both push streams.
  FOR app_row IN
    SELECT DISTINCT app FROM public.user_devices WHERE user_id = NEW.id
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = NEW.id AND app = app_row.app
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    -- Localized copy (same wording on both apps — the platform label
    -- "DocSera" vs "DocSera Pro" is implicit from where they're
    -- reading it).
    IF v_event = 'security.password_changed' THEN
      IF v_locale = 'en' THEN
        v_title := '🔐 Password changed';
        v_body  := 'Your password was just changed. If this wasn''t you, secure your account now.';
      ELSE
        v_title := '🔐 تم تغيير كلمة المرور';
        v_body  := 'تم تغيير كلمة المرور للتو. إن لم تكن أنت، أمّن حسابك الآن.';
      END IF;
    ELSIF v_event = 'security.email_changed' THEN
      IF v_locale = 'en' THEN
        v_title := '✉️ Email changed';
        v_body  := 'Your account email was just updated. If this wasn''t you, contact support.';
      ELSE
        v_title := '✉️ تم تغيير البريد الإلكتروني';
        v_body  := 'تم تحديث بريد حسابك. إن لم تكن أنت، تواصل مع الدعم.';
      END IF;
    ELSE  -- phone
      IF v_locale = 'en' THEN
        v_title := '📱 Phone number changed';
        v_body  := 'Your account phone number was just updated. If this wasn''t you, contact support.';
      ELSE
        v_title := '📱 تم تغيير رقم الهاتف';
        v_body  := 'تم تحديث رقم هاتف حسابك. إن لم تكن أنت، تواصل مع الدعم.';
      END IF;
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => app_row.app,
      p_event_code    => v_event,
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account:security',
      p_data          => '{}'::jsonb,
      p_importance    => 'high',
      -- Per-app dedup so the same user × event with different
      -- recipient_app doesn't collide.
      p_dedup_key     => v_dedup || ':' || app_row.app
    );
  END LOOP;

  RETURN NEW;
END $$;

-- Trigger definition unchanged from the previous migration; this
-- migration replaces the FUNCTION body, the AFTER UPDATE OF trigger
-- still calls into it.

-- ---------------------------------------------------------------------------
-- 2. New device login — emit for the SAME app the new device registered to.
-- ---------------------------------------------------------------------------
-- The patient-side version hardcoded recipient_app='docsera'. A doctor's
-- Pro device registering would emit nothing. Fix: use NEW.app so the
-- notification lands on whichever app the new device belongs to.

CREATE OR REPLACE FUNCTION public.fn_notify_new_device_login()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_other_count int;
  v_locale      text;
  v_title       text;
  v_body        text;
  v_app         text;
  v_app_label   text;
BEGIN
  IF NEW.user_id IS NULL THEN RETURN NEW; END IF;

  -- Only fire on a TRUE new-device login — i.e., the user already has
  -- at least one OTHER device on this app. Otherwise this is a
  -- first-time registration which isn't a "new device" event.
  SELECT count(*) INTO v_other_count
    FROM public.user_devices
   WHERE user_id = NEW.user_id
     AND app = NEW.app
     AND id <> NEW.id;
  IF v_other_count = 0 THEN RETURN NEW; END IF;

  v_locale := COALESCE(NEW.locale, 'ar');
  v_app := COALESCE(NEW.app, 'docsera');
  v_app_label := CASE WHEN v_app = 'docsera_pro' THEN 'DocSera Pro' ELSE 'DocSera' END;

  IF v_locale = 'en' THEN
    v_title := '🔔 New device signed in';
    v_body  := 'A new ' || COALESCE(NEW.platform, 'device')
            || ' just signed in to your ' || v_app_label
            || ' account. If this wasn''t you, change your password.';
  ELSE
    v_title := '🔔 تسجيل دخول من جهاز جديد';
    v_body  := 'تم تسجيل دخول جديد إلى حساب ' || v_app_label
            || ' من ' || COALESCE(NEW.platform, 'جهاز')
            || '. إن لم يكن أنت، غيّر كلمة المرور.';
  END IF;

  PERFORM public.fn_emit_notification(
    p_user_id       => NEW.user_id,
    p_recipient_app => v_app,
    p_event_code    => 'security.new_device_login',
    p_category      => 'security',
    p_locale        => v_locale,
    p_title         => v_title,
    p_body          => v_body,
    p_deep_link     => 'account:security',
    p_data          => jsonb_build_object(
                        'device_id', NEW.id,
                        'platform',  NEW.platform,
                        'app',       NEW.app
                       ),
    p_importance    => 'high',
    p_dedup_key     => 'newdev:' || NEW.id::text
  );

  RETURN NEW;
END $$;

COMMIT;
