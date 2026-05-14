-- =============================================================================
-- Switch fn_notify_memo_note_mentions to fn_user_display_name.
-- =============================================================================
-- Previous version queried public.users directly, which only carries
-- names for clinicians (and not even all of them). Secretaries store
-- their names in team_profiles, so a secretary @-mention surfaced as
-- "Someone mentioned you in a patient note". fn_user_display_name
-- already walks doctors → team_profiles → users — reuse it here.

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_notify_memo_note_mentions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp, extensions
AS $$
DECLARE
  added_id  uuid;
  v_locale  text;
  v_actor   uuid := COALESCE(NEW.last_edited_by, NEW.created_by);
  v_actor_label text;
  v_title   text;
  v_body    text;
BEGIN
  IF NEW.mentioned_user_ids IS NULL THEN RETURN NEW; END IF;

  FOR added_id IN
    SELECT u FROM unnest(NEW.mentioned_user_ids) AS u
    WHERE TG_OP = 'INSERT'
       OR u <> ALL (COALESCE(OLD.mentioned_user_ids, '{}'::uuid[]))
  LOOP
    IF added_id = v_actor THEN CONTINUE; END IF;

    -- Shared name lookup (covers clinicians + staff).
    v_actor_label := public.fn_user_display_name(v_actor);

    SELECT locale INTO v_locale
      FROM public.user_devices
     WHERE user_id = added_id AND app = 'docsera_pro'
     ORDER BY last_seen_at DESC NULLS LAST
     LIMIT 1;
    v_locale := COALESCE(v_locale, 'ar');

    IF v_locale = 'en' THEN
      v_title := '💬 You were mentioned';
      v_body  := v_actor_label || ' mentioned you in a patient note.';
    ELSE
      v_title := '💬 تمت الإشارة إليك';
      v_body  := v_actor_label || ' أشار إليك في ملاحظة مريض.';
    END IF;

    PERFORM public.fn_emit_notification(
      p_user_id       => added_id,
      p_recipient_app => 'docsera_pro',
      p_event_code    => 'pro.team.mentioned_in_note',
      p_category      => 'team',
      p_locale        => v_locale,
      p_title         => v_title,
      p_body          => v_body,
      p_deep_link     => 'patient:' || NEW.patient_ref_id::text,
      p_data          => jsonb_build_object(
                          'note_id',         NEW.id,
                          'patient_type',    NEW.patient_type,
                          'patient_ref_id',  NEW.patient_ref_id,
                          'center_id',       NEW.center_id,
                          'actor_user_id',   v_actor,
                          'actor_name',      v_actor_label
                         ),
      p_importance    => 'high',
      p_dedup_key     => 'note-mention:' || NEW.id::text
                       || ':' || added_id::text
                       || ':' || COALESCE(NEW.updated_at, NEW.created_at)::text
    );
  END LOOP;

  RETURN NEW;
END $$;

COMMIT;
