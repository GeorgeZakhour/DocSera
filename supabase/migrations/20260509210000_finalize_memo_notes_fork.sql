-- Migrate patient_memo_notes properly during day-30 finalize.
-- Path: notes are scoped by center_id; doctors join centers via
-- center_members. For each note pointing at a deleted user, we fork it
-- to every manual_patient record that belongs to a doctor in that
-- center. Result: every clinic staff member who could see the note
-- before still sees it on the patient's manual record after deletion.
--
-- Without this, memos that the doctor wrote about the patient are lost
-- at day 30 — that was the missing piece in the previous "drop with
-- audit log" approach.

CREATE OR REPLACE FUNCTION public.fn_cron_account_deletion_finalize()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  u            record;
  d            record;
  pmr          record;
  doctor_uuid  uuid;
  v_full_name  text;
  v_phone_raw  text;
  v_phone_e164 text;
  v_dp_pid     uuid;
  v_processed  integer := 0;
  memo         record;
  fork_pid     uuid;
  v_memo_forks integer;
  v_memo_drops integer;
  v_audit      record;
  v_orphan_total integer;
BEGIN
  FOR u IN
    SELECT id, first_name, last_name, email, phone_number, gender, date_of_birth
      FROM public.users
     WHERE deletion_requested_at IS NOT NULL
       AND deletion_pseudonymized_at IS NULL
       AND deletion_cancellable_until IS NOT NULL
       AND deletion_cancellable_until < now()
  LOOP
    v_full_name := trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, ''));
    IF v_full_name = '' THEN v_full_name := 'Deleted User'; END IF;
    v_phone_raw := nullif(trim(coalesce(u.phone_number, '')), '');

    v_phone_e164 := NULL;
    IF v_phone_raw IS NOT NULL THEN
      IF v_phone_raw LIKE '00%' THEN
        v_phone_e164 := '+' || substring(v_phone_raw FROM 3);
      ELSIF v_phone_raw LIKE '+%' THEN
        v_phone_e164 := v_phone_raw;
      ELSIF v_phone_raw ~ '^[0-9]+$' THEN
        v_phone_e164 := '+' || v_phone_raw;
      END IF;
      IF v_phone_e164 IS NOT NULL AND v_phone_e164 !~ '^\+[0-9]{6,15}$' THEN
        v_phone_e164 := NULL;
      END IF;
    END IF;

    -- Doctor loop. Build doctor_patients fork for every doctor that
    -- ever had a clinical artifact with this user.
    FOR d IN
      SELECT DISTINCT doctor_id FROM (
        SELECT doctor_id FROM public.appointments WHERE user_id = u.id AND doctor_id IS NOT NULL
        UNION
        SELECT doctor_id FROM public.reports WHERE user_id = u.id AND doctor_id IS NOT NULL
        UNION
        SELECT doctor_id FROM public.dental_records WHERE patient_id = u.id AND doctor_id IS NOT NULL
        UNION
        SELECT doctor_id FROM public.dental_treatment_plans WHERE patient_id = u.id AND doctor_id IS NOT NULL
        UNION
        SELECT doctor_id FROM public.accounting WHERE patient_id = u.id::text AND doctor_id IS NOT NULL
        UNION
        SELECT created_by_doctor_id AS doctor_id FROM public.patient_medical_records
         WHERE patient_id = u.id AND created_by_doctor_id IS NOT NULL
        UNION
        SELECT unnest(confirmed_by_doctor_ids) AS doctor_id FROM public.patient_medical_records
         WHERE patient_id = u.id
        UNION
        -- Doctors at any center that has a memo for this user — even
        -- if no clinical artifact otherwise — get a fork so the memo
        -- can be re-pointed.
        SELECT cm.doctor_id FROM public.center_members cm
          JOIN public.patient_memo_notes pmn ON pmn.center_id = cm.center_id
         WHERE pmn.patient_type = 'user' AND pmn.patient_ref_id = u.id
           AND cm.doctor_id IS NOT NULL AND cm.is_active = true
      ) all_docs
      WHERE doctor_id IS NOT NULL
    LOOP
      v_dp_pid := NULL;
      IF v_phone_e164 IS NOT NULL THEN
        SELECT patient_id INTO v_dp_pid
          FROM public.doctor_patients
         WHERE doctor_id = d.doctor_id
           AND (phone_number = v_phone_e164 OR phone_number = v_phone_raw)
         LIMIT 1;
      END IF;

      IF v_dp_pid IS NULL THEN
        INSERT INTO public.doctor_patients
          (doctor_id, first_name, last_name, patient_name,
           email, phone_number, gender, date_of_birth,
           was_docsera_user, docsera_account_deleted_at, prior_user_id)
        VALUES
          (d.doctor_id, u.first_name, u.last_name, v_full_name,
           u.email, v_phone_e164, u.gender, u.date_of_birth,
           true, now(), u.id)
        RETURNING patient_id INTO v_dp_pid;
      ELSE
        UPDATE public.doctor_patients
           SET was_docsera_user           = true,
               docsera_account_deleted_at = now(),
               prior_user_id              = u.id,
               first_name = COALESCE(first_name, u.first_name),
               last_name  = COALESCE(last_name, u.last_name),
               patient_name = COALESCE(NULLIF(trim(patient_name), ''), v_full_name),
               email = COALESCE(email, u.email),
               phone_number = COALESCE(phone_number, v_phone_e164),
               gender = COALESCE(gender, u.gender),
               date_of_birth = COALESCE(date_of_birth, u.date_of_birth)
         WHERE patient_id = v_dp_pid;
      END IF;

      UPDATE public.appointments
         SET user_id = NULL, manual_id = v_dp_pid
       WHERE user_id = u.id AND doctor_id = d.doctor_id;

      UPDATE public.documents
         SET user_id = NULL, patient_id = v_dp_pid
       WHERE user_id = u.id AND source_doctor_id = d.doctor_id;

      UPDATE public.reports
         SET user_id = NULL, patient_id = NULL, manual_id = v_dp_pid,
             patient_source = 'manual'
       WHERE doctor_id = d.doctor_id
         AND (user_id = u.id OR patient_id = u.id);

      UPDATE public.dental_records
         SET patient_id = v_dp_pid, patient_source = 'manual'
       WHERE doctor_id = d.doctor_id AND patient_id = u.id;

      UPDATE public.dental_treatment_plans
         SET patient_id = v_dp_pid
       WHERE doctor_id = d.doctor_id AND patient_id = u.id;

      UPDATE public.accounting
         SET patient_id = v_dp_pid::text, patient_source = 'manual'
       WHERE doctor_id = d.doctor_id AND patient_id = u.id::text;

      UPDATE public.conversations c
         SET patient_name = (SELECT patient_name FROM public.doctor_patients WHERE patient_id = v_dp_pid),
             is_closed = true,
             updated_at = now()
       WHERE c.patient_id = u.id AND c.doctor_id = d.doctor_id;
    END LOOP;

    UPDATE public.documents SET user_id = NULL WHERE user_id = u.id;

    -- patient_medical_records: fork to every (creator + confirmed) doctor.
    FOR pmr IN
      SELECT * FROM public.patient_medical_records WHERE patient_id = u.id
    LOOP
      FOR doctor_uuid IN
        SELECT DISTINCT did FROM (
          SELECT pmr.created_by_doctor_id AS did WHERE pmr.created_by_doctor_id IS NOT NULL
          UNION
          SELECT unnest(pmr.confirmed_by_doctor_ids) AS did
        ) ds
        WHERE did IS NOT NULL
      LOOP
        SELECT patient_id INTO v_dp_pid
          FROM public.doctor_patients
         WHERE prior_user_id = u.id AND doctor_id = doctor_uuid
         LIMIT 1;
        IF v_dp_pid IS NULL THEN CONTINUE; END IF;

        BEGIN
          INSERT INTO public.patient_medical_records
            (patient_id, manual_id, master_id, source, is_confirmed,
             severity, start_date, end_date, notes_en, notes_ar,
             confirmed_by_doctor_ids, created_by_doctor_id)
          VALUES
            (NULL, v_dp_pid, pmr.master_id, pmr.source, pmr.is_confirmed,
             pmr.severity, pmr.start_date, pmr.end_date, pmr.notes_en, pmr.notes_ar,
             ARRAY[doctor_uuid]::uuid[], doctor_uuid);
        EXCEPTION WHEN unique_violation THEN
          UPDATE public.patient_medical_records
             SET confirmed_by_doctor_ids =
                   (SELECT array(SELECT DISTINCT unnest(confirmed_by_doctor_ids || ARRAY[doctor_uuid]::uuid[])))
           WHERE manual_id = v_dp_pid AND master_id = pmr.master_id;
        END;
      END LOOP;
    END LOOP;
    DELETE FROM public.patient_medical_records WHERE patient_id = u.id;

    -- patient_memo_notes: fork each note to every manual_patient row
    -- belonging to a doctor in the same center. Result: any clinic
    -- staff member who could read the note before can still read it
    -- after, on whichever manual record they open in Pro.
    v_memo_forks := 0;
    v_memo_drops := 0;
    FOR memo IN
      SELECT * FROM public.patient_memo_notes
       WHERE patient_type = 'user' AND patient_ref_id = u.id
    LOOP
      -- Distinct manual_patient_ids in this center for this user.
      FOR fork_pid IN
        SELECT DISTINCT dp.patient_id
          FROM public.doctor_patients dp
          JOIN public.center_members cm
            ON cm.doctor_id = dp.doctor_id
           AND cm.is_active = true
         WHERE dp.prior_user_id = u.id
           AND cm.center_id = memo.center_id
      LOOP
        INSERT INTO public.patient_memo_notes
          (patient_type, patient_ref_id, title_enc, body_enc, color,
           is_pinned, created_by, last_edited_by, created_at, updated_at,
           deleted_at, center_id)
        VALUES
          ('manual', fork_pid, memo.title_enc, memo.body_enc, memo.color,
           memo.is_pinned, memo.created_by, memo.last_edited_by,
           memo.created_at, memo.updated_at, memo.deleted_at, memo.center_id);
        v_memo_forks := v_memo_forks + 1;
      END LOOP;

      -- Did the memo end up forked anywhere?
      IF NOT EXISTS (
        SELECT 1 FROM public.doctor_patients dp
          JOIN public.center_members cm
            ON cm.doctor_id = dp.doctor_id AND cm.is_active = true
         WHERE dp.prior_user_id = u.id AND cm.center_id = memo.center_id
      ) THEN
        v_memo_drops := v_memo_drops + 1;
      END IF;
    END LOOP;
    DELETE FROM public.patient_memo_notes
     WHERE patient_type = 'user' AND patient_ref_id = u.id;

    IF v_memo_forks > 0 OR v_memo_drops > 0 THEN
      RAISE NOTICE 'fn_cron_account_deletion_finalize: memos for % — forked %, dropped %',
        u.id, v_memo_forks, v_memo_drops;
    END IF;

    -- Drop doctor-side user-type links + auxiliary metadata.
    DELETE FROM public.doctor_account_patients
     WHERE patient_type = 'user' AND patient_ref_id = u.id;
    DELETE FROM public.doctor_patient_links
     WHERE patient_type = 'user' AND patient_ref_id = u.id;
    DELETE FROM public.doctor_patient_blocks WHERE patient_id = u.id;
    DELETE FROM public.doctor_patient_booking_blocks WHERE patient_id = u.id;
    DELETE FROM public.doctor_promotion_claims WHERE patient_id = u.id;
    DELETE FROM public.doctor_insight_skips WHERE patient_id = u.id;

    -- Strictly patient-side data.
    DELETE FROM public.patient_health_profile WHERE user_id = u.id;
    DELETE FROM public.user_devices WHERE user_id = u.id;
    DELETE FROM public.notifications WHERE user_id = u.id;
    DELETE FROM public.notification_preferences WHERE user_id = u.id;
    DELETE FROM public.notification_quiet_hours WHERE user_id = u.id;
    DELETE FROM public.relatives WHERE user_id = u.id;
    DELETE FROM public.points_history WHERE user_id = u.id;
    DELETE FROM public.vouchers WHERE user_id = u.id;
    DELETE FROM public.user_legal_consents WHERE user_id = u.id;
    DELETE FROM public.user_security WHERE user_id = u.id;
    DELETE FROM public.user_storage_quotas WHERE user_id = u.id;
    DELETE FROM public.referral_flags WHERE user_id = u.id;
    DELETE FROM public.notes WHERE user_id = u.id;
    DELETE FROM public.patient_gift_sends WHERE patient_id = u.id;

    -- Pseudonymize public.users tombstone.
    UPDATE public.users
       SET first_name                = 'Deleted',
           last_name                 = 'User',
           email                     = NULL,
           phone_number              = NULL,
           gender                    = NULL,
           date_of_birth             = NULL,
           deletion_pseudonymized_at = now(),
           is_active                 = false,
           trusted_devices           = '{}'
     WHERE id = u.id;

    BEGIN
      DELETE FROM auth.users WHERE id = u.id;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'fn_cron_account_deletion_finalize: auth.users delete for % failed: %', u.id, SQLERRM;
    END;

    -- Post-condition guard: scan for orphans.
    v_orphan_total := 0;
    FOR v_audit IN
      SELECT c.table_name, c.column_name
        FROM information_schema.columns c
       WHERE c.table_schema = 'public'
         AND c.column_name IN ('user_id', 'patient_id')
         AND c.data_type = 'uuid'
         AND c.table_name NOT IN (
           'users','doctor_patients','doctor_account_patients','doctor_patient_links',
           'patient_memo_notes'
         )
    LOOP
      EXECUTE format(
        'SELECT count(*) FROM public.%I WHERE %I = $1',
        v_audit.table_name, v_audit.column_name
      ) USING u.id INTO STRICT v_orphan_total;
      IF v_orphan_total > 0 THEN
        RAISE NOTICE 'fn_cron_account_deletion_finalize: ORPHAN — %.% has % rows still referencing user %',
          v_audit.table_name, v_audit.column_name, v_orphan_total, u.id;
      END IF;
    END LOOP;

    v_processed := v_processed + 1;
  END LOOP;

  IF v_processed > 0 THEN
    RAISE NOTICE 'fn_cron_account_deletion_finalize: processed % users', v_processed;
  END IF;
  RETURN v_processed;
END $$;
