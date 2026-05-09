-- Update deletion_state_changed trigger fn copy: same theme as the
-- warning crons — be honest that the DocSera account closes (not "all
-- data deleted"), and that clinical records stay with doctors. Title
-- short for lock-screen, body one sentence with the date.

CREATE OR REPLACE FUNCTION public.fn_notify_deletion_state_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  v_locale text;
  v_title  text;
  v_body   text;
BEGIN
  SELECT locale INTO v_locale
    FROM public.user_devices
   WHERE user_id = NEW.id AND app = 'docsera'
   ORDER BY last_seen_at DESC NULLS LAST
   LIMIT 1;
  v_locale := COALESCE(v_locale, 'ar');

  -- Transition: NULL → NOT NULL = deletion just requested.
  IF OLD.deletion_requested_at IS NULL AND NEW.deletion_requested_at IS NOT NULL THEN
    IF v_locale = 'en' THEN
      v_title := '⚠️ Account closure scheduled';
      v_body  := 'Your DocSera account closes on '
                 || to_char(NEW.deletion_cancellable_until AT TIME ZONE 'Asia/Damascus', 'DD Mon YYYY')
                 || '. You can cancel anytime before then.';
    ELSE
      v_title := '⚠️ تم جدولة إغلاق الحساب';
      v_body  := 'سيتم إغلاق حساب دوكسيرا الخاص بك في '
                 || to_char(NEW.deletion_cancellable_until AT TIME ZONE 'Asia/Damascus', 'DD/MM/YYYY')
                 || '. يمكنك الإلغاء في أي وقت قبل ذلك.';
    END IF;
    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_scheduled',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account_deletion:pending',
      p_data          => jsonb_build_object(
        'deletion_requested_at', NEW.deletion_requested_at,
        'cancellable_until',     NEW.deletion_cancellable_until
      ),
      p_importance    => 'high',
      p_dedup_key     => 'apt-deletion-scheduled:' || NEW.id::text || ':' || NEW.deletion_requested_at::text
    );
    RETURN NEW;
  END IF;

  -- Transition: NOT NULL → NULL = deletion cancelled.
  IF OLD.deletion_requested_at IS NOT NULL AND NEW.deletion_requested_at IS NULL THEN
    IF v_locale = 'en' THEN
      v_title := '✅ Account closure cancelled';
      v_body  := 'Your DocSera account is fully active again. Welcome back.';
    ELSE
      v_title := '✅ تم إلغاء إغلاق الحساب';
      v_body  := 'حسابك في دوكسيرا مفعّل بالكامل من جديد. أهلًا بعودتك.';
    END IF;
    PERFORM public.fn_emit_notification(
      p_user_id       => NEW.id,
      p_recipient_app => 'docsera',
      p_event_code    => 'account.deletion_cancelled',
      p_category      => 'security',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'account:home',
      p_data          => '{}'::jsonb,
      p_importance    => 'high',
      p_dedup_key     => 'apt-deletion-cancelled:' || NEW.id::text || ':' || COALESCE(OLD.deletion_requested_at::text, '')
    );
  END IF;

  RETURN NEW;
END $$;
