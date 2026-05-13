-- =============================================================================
-- Fix security-event deep_links — the previous functions used
-- `account:security` which the deep-link router doesn't recognise, so
-- tapping "Open" on a password-change notification landed on the
-- dashboard. Switch to the `security:` prefix, which the router now
-- maps to /account?tab=security.
-- =============================================================================
--
-- Same fn_notify_auth_change body as the dual-fire migration, only the
-- p_deep_link value changes. We keep the rest verbatim so a future
-- diff stays readable.

BEGIN;

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
  IF NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    v_event := 'security.password_changed';
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

  FOR app_row IN
    SELECT DISTINCT app FROM public.user_devices WHERE user_id = NEW.id
  LOOP
    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = NEW.id AND app = app_row.app
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

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
    ELSE
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
      -- Was 'account:security' (unmapped → router fell to /dashboard).
      -- New `security:` prefix lands on /account?tab=security.
      p_deep_link     => 'security:',
      p_data          => '{}'::jsonb,
      p_importance    => 'high',
      p_dedup_key     => v_dedup || ':' || app_row.app
    );
  END LOOP;

  RETURN NEW;
END $$;

-- Same change for new-device login.
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
    -- Was 'account:security' — fixed to the recognised prefix.
    p_deep_link     => 'security:',
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
