-- Fix two bugs in fn_notify_new_trusted_device:
--
-- (1) Type mismatch: I joined user_devices.id (uuid PK) against
--     d_id (text from trusted_devices). Android device fingerprints
--     are 16-char hex strings (not UUIDs), so the implicit text→uuid
--     cast errored, the trigger raised, the UPDATE on users rolled
--     back, trust_current_device threw to the client, and the OTP
--     screen showed "invalid code". (Verify had already succeeded
--     by then — the OTP row was consumed — so the error message was
--     misleading.) Worse: `users.trusted_devices` device ids and
--     `user_devices.id` row pks are completely different concepts;
--     they were never meant to join.
--
-- (2) The trigger raised INTO the parent UPDATE. The parent
--     trust_current_device call is part of a critical login path —
--     a notification side-effect must NEVER take it down. Wrap the
--     fn_emit_notification call in EXCEPTION as defense-in-depth.
--
-- Fix:
--   * Drop the user_devices lookup. We don't need platform info —
--     a generic "new device signed in" message is fine and avoids
--     all the join issues. If we want platform later, the right
--     source is the most-recent user_devices row for the user
--     (any device, by last_seen_at), not a join by device-id.
--   * Wrap the body in EXCEPTION so the parent UPDATE always
--     succeeds even if notification emission fails.

CREATE OR REPLACE FUNCTION public.fn_notify_new_trusted_device()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  added_devices text[];
  d_id          text;
  v_locale      text;
  v_other       int;
  v_title       text;
  v_body        text;
BEGIN
  added_devices := ARRAY(
    SELECT new_id
      FROM unnest(COALESCE(NEW.trusted_devices, ARRAY[]::text[])) AS new_id
     WHERE new_id IS NOT NULL
       AND NOT (COALESCE(OLD.trusted_devices, ARRAY[]::text[]) @> ARRAY[new_id])
  );
  IF array_length(added_devices, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  -- Pick a locale from any registered device for the user. Best-effort.
  SELECT COALESCE(locale, 'ar') INTO v_locale
    FROM public.user_devices
   WHERE user_id = NEW.id AND app = 'docsera'
   ORDER BY last_seen_at DESC NULLS LAST
   LIMIT 1;
  v_locale := COALESCE(v_locale, 'ar');

  FOREACH d_id IN ARRAY added_devices
  LOOP
    -- Suppress on the first device (signup, not "new sign-in elsewhere").
    -- Count OTHER trusted devices on the user record.
    v_other := array_length(COALESCE(OLD.trusted_devices, ARRAY[]::text[]), 1);
    IF v_other IS NULL OR v_other = 0 THEN CONTINUE; END IF;

    IF v_locale = 'en' THEN
      v_title := '🔔 New sign-in to your account';
      v_body  := 'A new device just signed in to your DocSera account. '
                 || 'If this wasn''t you, change your password immediately.';
    ELSE
      v_title := '🔔 تسجيل دخول جديد إلى حسابك';
      v_body  := 'تم تسجيل الدخول إلى حساب دوكسيرا الخاص بك من جهاز جديد. '
                 || 'إن لم يكن أنت، غيّر كلمة المرور فورًا.';
    END IF;

    BEGIN
      PERFORM public.fn_emit_notification(
        p_user_id       => NEW.id,
        p_recipient_app => 'docsera',
        p_event_code    => 'security.new_device_login',
        p_category      => 'security',
        p_locale        => v_locale,
        p_title         => v_title,
        p_body          => v_body,
        p_deep_link     => 'account:security',
        p_data          => jsonb_build_object('device_id', d_id),
        p_importance    => 'high',
        p_dedup_key     => 'newdev:' || NEW.id::text || ':' || d_id
      );
    EXCEPTION WHEN OTHERS THEN
      -- Critical: never let a notification side-effect take down the
      -- parent UPDATE on users.trusted_devices. Log and move on.
      RAISE NOTICE 'fn_notify_new_trusted_device: emit failed for % %, continuing: %',
        NEW.id, d_id, SQLERRM;
    END;
  END LOOP;

  RETURN NEW;
END $$;
