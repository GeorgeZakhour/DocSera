-- Appointment reminder copy v2: keep the warm, conversational tone the
-- user liked from the original T-30m reminder ("ستلتقي ... — هل أنت في
-- الطريق؟"). Each level now asks a gentle question or gives a soft cue,
-- and the time uses ص/م in Arabic.

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
  v_window    interval := interval '70 seconds';
  v_doctor    text;
  v_time_ar   text;
  v_time_en   text;
  v_hour      int;
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

    IF v_locale = 'en' THEN
      v_doctor := COALESCE(
        NULLIF(regexp_replace(r.doctor_name, '^د\.\s*', ''), ''),
        'your doctor'
      );
    ELSE
      v_doctor := COALESCE(NULLIF(trim(r.doctor_name), ''), 'الطبيب');
    END IF;

    v_hour := extract(hour from r.timestamp AT TIME ZONE 'Asia/Damascus')::int;
    v_time_en := to_char(r.timestamp AT TIME ZONE 'Asia/Damascus', 'FMHH12:MI AM');
    v_time_ar := to_char(r.timestamp AT TIME ZONE 'Asia/Damascus', 'FMHH12:MI')
                 || ' ' || CASE WHEN v_hour >= 12 THEN 'م' ELSE 'ص' END;

    IF r.rtype = 't24h' THEN
      IF v_locale = 'en' THEN
        v_title := 'Your appointment is tomorrow';
        v_body  := 'You''ll be seeing Dr. ' || v_doctor
                   || ' tomorrow at ' || v_time_en || ' — see you then!';
      ELSE
        v_title := 'موعدك غدًا';
        v_body  := 'ستلتقي د. ' || v_doctor
                   || ' غدًا الساعة ' || v_time_ar || ' — نراك قريبًا!';
      END IF;
    ELSIF r.rtype = 't2h' THEN
      IF v_locale = 'en' THEN
        v_title := 'Your appointment is in 2 hours';
        v_body  := 'You''ll be seeing Dr. ' || v_doctor
                   || ' today at ' || v_time_en || ' — getting ready?';
      ELSE
        v_title := 'موعدك بعد ساعتين';
        v_body  := 'ستلتقي د. ' || v_doctor
                   || ' اليوم الساعة ' || v_time_ar || ' — هل تستعد؟';
      END IF;
    ELSIF r.rtype = 't30m' THEN
      IF v_locale = 'en' THEN
        v_title := 'Your appointment is in 30 minutes';
        v_body  := 'You''ll be seeing Dr. ' || v_doctor
                   || ' soon — are you on your way?';
      ELSE
        v_title := 'موعدك بعد نصف ساعة';
        v_body  := 'ستلتقي د. ' || v_doctor
                   || ' قريبًا — هل أنت في الطريق؟';
      END IF;
    ELSIF r.rtype = 't0' THEN
      IF v_locale = 'en' THEN
        v_title := 'It''s appointment time';
        v_body  := 'Dr. ' || v_doctor
                   || ' is ready to see you. Have a great visit.';
      ELSE
        v_title := 'حان وقت موعدك';
        v_body  := 'د. ' || v_doctor
                   || ' بانتظارك الآن. نتمنى لك زيارة موفقة.';
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
