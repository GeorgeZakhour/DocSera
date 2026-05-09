-- Update deletion warning copy to align with the redesigned lifecycle:
-- the central DocSera account closes at day 30, but clinical records
-- stay with the doctors who treated the patient. The old copy implied
-- everything would be permanently deleted. The new copy is honest about
-- what's actually closing.
--
-- Keep titles short (lock-screen visible) and bodies one sentence.

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
    SELECT u.id, u.deletion_cancellable_until
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
      v_title := '⏳ 7 days to cancel your account closure';
      v_body  := 'Your DocSera account closes in 7 days. Tap to cancel and keep using DocSera.';
    ELSE
      v_title := '⏳ ٧ أيام لإلغاء إغلاق حسابك';
      v_body  := 'سيتم إغلاق حساب دوكسيرا الخاص بك بعد ٧ أيام. اضغط لإلغاء العملية ومتابعة استخدام دوكسيرا.';
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
      v_title := '⛔ Your DocSera account closes tomorrow';
      v_body  := 'Last chance to cancel — tap to keep your DocSera account open.';
    ELSE
      v_title := '⛔ سيتم إغلاق حساب دوكسيرا غدًا';
      v_body  := 'هذه آخر فرصة لإلغاء العملية — اضغط للحفاظ على حسابك مفتوحًا.';
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
