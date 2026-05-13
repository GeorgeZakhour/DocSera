-- =============================================================================
-- @mentions in patient memo notes (Pro)
-- =============================================================================
-- The note body is encrypted on the client side (body_enc), so SQL
-- can't parse `@Name` tokens out of it. Instead, the client populates
-- a separate `mentioned_user_ids uuid[]` column when saving, listing
-- the team members it intends to notify. A trigger compares old vs
-- new and fans out `pro.team.mentioned_in_note` to each newly-added
-- recipient — same fn_emit_notification path everything else uses.
--
-- Why a column and not a join table:
--   - Mentions on a note are usually 1–3 people; a 1:N column avoids
--     a separate table + join for every read.
--   - Trigger diffs (old vs new array) are trivial in PL/pgSQL.
--   - RLS on the note carries through implicitly.

BEGIN;

-- 1. Column.
ALTER TABLE public.patient_memo_notes
  ADD COLUMN IF NOT EXISTS mentioned_user_ids uuid[] NOT NULL DEFAULT '{}'::uuid[];

COMMENT ON COLUMN public.patient_memo_notes.mentioned_user_ids IS
  'Auth user_ids @-mentioned in the note body. Client-managed because '
  'the body itself is encrypted. The notify-on-mention trigger reads '
  'this column to fan out pro.team.mentioned_in_note events.';

-- 2. Trigger function.
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

  -- Compute the set of newly-added mentions (members that weren't in
  -- OLD.mentioned_user_ids). On INSERT, OLD doesn't exist → all new.
  FOR added_id IN
    SELECT u FROM unnest(NEW.mentioned_user_ids) AS u
    WHERE TG_OP = 'INSERT'
       OR u <> ALL (COALESCE(OLD.mentioned_user_ids, '{}'::uuid[]))
  LOOP
    -- Skip self-mentions (the editor mentioned themselves).
    IF added_id = v_actor THEN CONTINUE; END IF;

    -- Resolve actor display name from users table — same pattern the
    -- todo_tasks handler uses now.
    SELECT
      COALESCE(NULLIF(trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')), ''),
               phone, email, 'Someone')
      INTO v_actor_label
      FROM public.users
     WHERE id = v_actor;
    v_actor_label := COALESCE(v_actor_label, 'Someone');

    -- Recipient locale.
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
      -- One emission per (note, user, edit-timestamp) — re-adding the
      -- same mention after removing it WILL fire again, which is the
      -- desired behavior (they were re-pulled into the thread).
      p_dedup_key     => 'note-mention:' || NEW.id::text
                       || ':' || added_id::text
                       || ':' || COALESCE(NEW.updated_at, NEW.created_at)::text
    );
  END LOOP;

  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION public.fn_notify_memo_note_mentions() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_notify_memo_note_mentions ON public.patient_memo_notes;
CREATE TRIGGER trg_notify_memo_note_mentions
  AFTER INSERT OR UPDATE OF mentioned_user_ids ON public.patient_memo_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_notify_memo_note_mentions();

COMMIT;
