-- Fix two column-mismatch bugs in fn_cron_account_deletion_finalize:
--   1. documents has source_doctor_id, NOT conversation_doctor_id
--   2. accounting.patient_id is text, not uuid — needs explicit cast

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

      UPDATE public.appointments
         SET user_id = NULL, manual_id = v_dp_pid
       WHERE user_id = u.id AND doctor_id = d.doctor_id;

      -- documents: re-point patient_id for this doctor's docs (column is
      -- source_doctor_id, not conversation_doctor_id). Patient self-
      -- uploads have no doctor link — handled by the user_id NULL pass
      -- after the loop.
      UPDATE public.documents
         SET user_id = NULL, patient_id = v_dp_pid
       WHERE user_id = u.id AND source_doctor_id = d.doctor_id;

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

      -- accounting.patient_id is text — cast user.id (uuid) for compare
      -- and store the manual_id as text.
      UPDATE public.accounting
         SET patient_id = v_dp_pid::text
       WHERE doctor_id = d.doctor_id AND patient_id = u.id::text;
    END LOOP;

    -- Patient self-upload docs (no doctor) — drop the user_id pointer.
    UPDATE public.documents SET user_id = NULL WHERE user_id = u.id;

    UPDATE public.patient_medical_records pmr
       SET patient_id = NULL,
           manual_id  = dp.patient_id
      FROM public.doctor_patients dp
     WHERE pmr.patient_id = u.id
       AND pmr.created_by_doctor_id IS NOT NULL
       AND dp.doctor_id = pmr.created_by_doctor_id
       AND dp.prior_user_id = u.id;
    DELETE FROM public.patient_medical_records WHERE patient_id = u.id;

    DELETE FROM public.doctor_account_patients
     WHERE patient_type = 'user' AND patient_ref_id = u.id;
    DELETE FROM public.doctor_patient_links
     WHERE patient_type = 'user' AND patient_ref_id = u.id;
    DELETE FROM public.patient_memo_notes
     WHERE patient_type = 'user' AND patient_ref_id = u.id;

    UPDATE public.conversations
       SET is_closed = true, updated_at = now()
     WHERE patient_id = u.id
       AND COALESCE(is_closed, false) = false;

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
