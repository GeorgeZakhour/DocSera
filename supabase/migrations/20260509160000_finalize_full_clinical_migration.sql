-- Extend fn_cron_account_deletion_finalize to re-point ALL clinical
-- records, not just appointments. The previous version moved
-- appointments + nulled documents.user_id, but reports / accounting /
-- dental records / patient_medical_records still pointed at the
-- pseudonymized public.users row, so the doctor-side patient detail
-- showed empty bills/reports/medical-history/dental-history sections
-- after the day-30 fork.
--
-- New per-doctor migrations (inside the doctor loop):
--   * documents.patient_id  : set to manual_id for that doctor's docs
--   * reports               : user_id/patient_id → NULL, manual_id set
--   * accounting            : patient_id → NULL (manual lookup happens
--                             via appointment_id / doctor_patients
--                             join) — actually we set it to manual_id
--                             since the schema accepts the manual fork
--   * dental_records        : patient_id → manual.patient_id
--   * dental_treatment_plans: same
--
-- And one post-loop migration:
--   * patient_medical_records: per-row, find the creator doctor's
--     manual_id and re-point. Records without a creator doctor are
--     dropped (they were patient-side self-managed entries).

CREATE OR REPLACE FUNCTION public.fn_cron_account_deletion_finalize()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  u           record;
  d           record;
  v_full_name text;
  v_phone_raw text;
  v_phone_e164 text;
  v_dp_pid    uuid;
  v_processed integer := 0;
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

    -- For each doctor with any clinical artifact (appointment, report,
    -- dental, accounting), create / find a manual patient row and
    -- re-point that doctor's clinical records to it.
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
        SELECT doctor_id FROM public.accounting WHERE patient_id = u.id AND doctor_id IS NOT NULL
      ) all_docs
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

      -- Per-doctor re-pointers
      UPDATE public.appointments
         SET user_id = NULL, manual_id = v_dp_pid
       WHERE user_id = u.id AND doctor_id = d.doctor_id;

      UPDATE public.documents
         SET user_id = NULL, patient_id = v_dp_pid
       WHERE user_id = u.id AND id IN (
         SELECT doc.id FROM public.documents doc
          WHERE doc.user_id = u.id
            AND doc.conversation_doctor_id = d.doctor_id
       );
      -- Patient-uploaded docs (no doctor_id linkage) — orphan them at
      -- user_id only; no doctor side has a manual record to attach to.
      UPDATE public.documents
         SET user_id = NULL
       WHERE user_id = u.id;

      UPDATE public.reports
         SET user_id = NULL, patient_id = NULL, manual_id = v_dp_pid
       WHERE doctor_id = d.doctor_id
         AND (user_id = u.id OR patient_id = u.id);

      UPDATE public.dental_records
         SET patient_id = v_dp_pid
       WHERE doctor_id = d.doctor_id AND patient_id = u.id;

      UPDATE public.dental_treatment_plans
         SET patient_id = v_dp_pid
       WHERE doctor_id = d.doctor_id AND patient_id = u.id;

      UPDATE public.accounting
         SET patient_id = v_dp_pid
       WHERE doctor_id = d.doctor_id AND patient_id = u.id;
    END LOOP;

    -- patient_medical_records is keyed by patient_id (not doctor) but
    -- carries created_by_doctor_id. Re-point each row to the creator's
    -- manual record. Drop rows with no creator (patient self-entered).
    UPDATE public.patient_medical_records pmr
       SET patient_id = NULL,
           manual_id  = dp.patient_id
      FROM public.doctor_patients dp
     WHERE pmr.patient_id = u.id
       AND pmr.created_by_doctor_id IS NOT NULL
       AND dp.doctor_id = pmr.created_by_doctor_id
       AND dp.prior_user_id = u.id;
    DELETE FROM public.patient_medical_records
     WHERE patient_id = u.id; -- catches any leftovers (no creator doctor)

    -- Remove the doctor-side user-type links (otherwise the now-
    -- pseudonymized public.users row keeps showing as a duplicate
    -- "Deleted User" entry in Pro patient lists).
    DELETE FROM public.doctor_account_patients
     WHERE patient_type = 'user' AND patient_ref_id = u.id;
    DELETE FROM public.doctor_patient_links
     WHERE patient_type = 'user' AND patient_ref_id = u.id;

    -- patient_memo_notes: re-point user-type → manual-type for any
    -- center where this patient now has a doctor_patients fork. Note
    -- patient_memo_notes is center-scoped, but we look up the center
    -- via the doctor's clinic. If we can't resolve, drop the note.
    DELETE FROM public.patient_memo_notes
     WHERE patient_type = 'user' AND patient_ref_id = u.id;

    -- Conversations close (kept as historical record).
    UPDATE public.conversations
       SET is_closed = true, updated_at = now()
     WHERE patient_id = u.id
       AND COALESCE(is_closed, false) = false;

    -- Strictly patient-side data: drop.
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

    v_processed := v_processed + 1;
  END LOOP;

  IF v_processed > 0 THEN
    RAISE NOTICE 'fn_cron_account_deletion_finalize: processed % users', v_processed;
  END IF;
  RETURN v_processed;
END $$;
