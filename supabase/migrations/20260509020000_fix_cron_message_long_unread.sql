-- Fix fn_cron_message_long_unread: the original referenced m.created_at and
-- m.is_seen, neither of which exist on public.messages. The actual columns
-- are m.timestamp (when the message was sent) and m.read_by_user (boolean).

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
           m.timestamp AS msg_at,
           c.patient_id,
           c.relative_id,
           c.doctor_name,
           extract(epoch from now() - m.timestamp)/3600 AS hours_old
      FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
     WHERE m.is_user = false
       AND COALESCE(m.read_by_user, false) = false
       AND m.timestamp < now() - interval '48 hours'
       AND m.timestamp > now() - interval '14 days'
     ORDER BY m.conversation_id, m.timestamp DESC
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
      p_dedup_key     => 'longunread:' || r.conversation_id::text || ':' || to_char(r.msg_at, 'YYYYMMDD')
    );
  END LOOP;
END $$;
