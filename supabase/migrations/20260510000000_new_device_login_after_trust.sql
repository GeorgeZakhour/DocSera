-- Move the "new device signed in" notification from a user_devices
-- INSERT trigger (which fired the moment Pushy registered the device,
-- typically right after password auth — BEFORE the user completed the
-- new-device 2FA OTP) to a users UPDATE trigger that fires only when
-- a NEW device id is appended to users.trusted_devices.
--
-- That moment is the only point where a sign-in is officially
-- "complete" — password verified AND OTP verified AND device
-- trusted. Firing the notification there means:
--   * No false positives from password-then-abandoned attempts
--   * The subject of the notification is always a real, completed
--     sign-in
--
-- Also rewrites the body copy to use a friendlier device label
-- ("iPhone" / "Android phone" / "هاتف آيفون" / "هاتف اندرويد")
-- instead of the raw lowercase platform string.

DROP TRIGGER IF EXISTS trg_notify_new_device_login ON public.user_devices;

CREATE OR REPLACE FUNCTION public.fn_notify_new_trusted_device()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  added_devices text[];
  d_id          text;
  v_platform    text;
  v_locale      text;
  v_other       int;
  v_label_ar    text;
  v_label_en    text;
  v_title       text;
  v_body        text;
BEGIN
  -- Detect device ids that are in NEW.trusted_devices but not in OLD.
  added_devices := ARRAY(
    SELECT new_id
      FROM unnest(COALESCE(NEW.trusted_devices, ARRAY[]::text[])) AS new_id
     WHERE new_id IS NOT NULL
       AND NOT (COALESCE(OLD.trusted_devices, ARRAY[]::text[]) @> ARRAY[new_id])
  );
  IF array_length(added_devices, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  FOREACH d_id IN ARRAY added_devices
  LOOP
    -- Suppress the notification when this is the user's first device
    -- (signup, not "new sign-in elsewhere"). Count OTHER devices.
    SELECT count(*) INTO v_other
      FROM public.user_devices
     WHERE user_id = NEW.id
       AND app = 'docsera'
       AND id <> d_id;
    IF v_other = 0 THEN CONTINUE; END IF;

    -- Look up the device's platform + locale from user_devices.
    SELECT platform, COALESCE(locale, 'ar') INTO v_platform, v_locale
      FROM public.user_devices
     WHERE user_id = NEW.id AND id = d_id
     LIMIT 1;

    v_locale := COALESCE(v_locale, 'ar');

    -- Friendly device labels (no more raw "android" / "ios" lowercase).
    v_label_en := CASE lower(COALESCE(v_platform, ''))
                    WHEN 'ios'     THEN 'iPhone'
                    WHEN 'android' THEN 'Android phone'
                    WHEN 'web'     THEN 'web browser'
                    WHEN 'macos'   THEN 'Mac'
                    WHEN 'windows' THEN 'Windows PC'
                    ELSE 'new device'
                  END;
    v_label_ar := CASE lower(COALESCE(v_platform, ''))
                    WHEN 'ios'     THEN 'هاتف آيفون'
                    WHEN 'android' THEN 'هاتف اندرويد'
                    WHEN 'web'     THEN 'متصفح ويب'
                    WHEN 'macos'   THEN 'حاسوب ماك'
                    WHEN 'windows' THEN 'حاسوب ويندوز'
                    ELSE 'جهاز جديد'
                  END;

    IF v_locale = 'en' THEN
      v_title := '🔔 New sign-in to your account';
      v_body  := 'Your DocSera account was just signed in to from a '
                 || v_label_en
                 || '. If this wasn''t you, change your password immediately.';
    ELSE
      v_title := '🔔 تسجيل دخول جديد إلى حسابك';
      v_body  := 'تم تسجيل الدخول إلى حساب دوكسيرا الخاص بك من '
                 || v_label_ar
                 || '. إن لم يكن أنت، غيّر كلمة المرور فورًا.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'security.new_device_login',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account:security',
      p_data          => jsonb_build_object('device_id', d_id, 'platform', v_platform),
      p_importance    => 'high',
      p_dedup_key     => 'newdev:' || NEW.id::text || ':' || d_id
    );
  END LOOP;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_new_trusted_device ON public.users;
CREATE TRIGGER trg_notify_new_trusted_device
AFTER UPDATE OF trusted_devices ON public.users
FOR EACH ROW
WHEN (NEW.trusted_devices IS DISTINCT FROM OLD.trusted_devices)
EXECUTE FUNCTION public.fn_notify_new_trusted_device();
