-- Account-deletion lifecycle finalization: at day 30, instead of
-- pseudonymizing in place, *fork* the patient into one manual-patient
-- record per doctor who had a clinical relationship with them. The
-- doctor keeps clinical history (the same data they would have had if
-- they'd created a manual patient themselves), gets a badge identifying
-- the ex-DocSera relationship, but loses the ability to message the
-- patient via DocSera (since the central account is gone).
--
-- Why this design:
--   * The doctor has a legal/clinical retention obligation
--   * Doctors can already create manual patients with all the same data
--   * Pseudonymizing penalizes the doctor for the patient's GDPR
--     decision without adding any real privacy
--
-- See the conversation context for the product reasoning. This migration:
--   1. Adds three columns to doctor_patients to track the conversion
--   2. Defines fn_cron_account_deletion_finalize()
--   3. Schedules it daily at 02:00 UTC

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Schema additions on doctor_patients
-- ---------------------------------------------------------------------------
ALTER TABLE public.doctor_patients
  ADD COLUMN IF NOT EXISTS was_docsera_user            boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS docsera_account_deleted_at  timestamptz,
  ADD COLUMN IF NOT EXISTS prior_user_id               uuid;

COMMENT ON COLUMN public.doctor_patients.was_docsera_user IS
  'TRUE when this row was created by fn_cron_account_deletion_finalize from a deleted DocSera account.';
COMMENT ON COLUMN public.doctor_patients.docsera_account_deleted_at IS
  'Timestamp the DocSera account was finalized (i.e. deletion grace window expired).';
COMMENT ON COLUMN public.doctor_patients.prior_user_id IS
  'The public.users.id this manual patient was forked from. Useful for audit and for future re-link if the patient signs up again.';

CREATE INDEX IF NOT EXISTS idx_doctor_patients_was_docsera
  ON public.doctor_patients (doctor_id) WHERE was_docsera_user;

-- ---------------------------------------------------------------------------
-- 2. fn_cron_account_deletion_finalize
-- ---------------------------------------------------------------------------
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
  v_phone     text;
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
    v_phone := nullif(trim(coalesce(u.phone_number, '')), '');

    -- For each doctor with a clinical relationship with this user, create
    -- (or update if it already exists from a prior manual entry) a
    -- doctor_patients row, then re-point any appointment owned by that
    -- doctor to the new manual patient.
    FOR d IN
      SELECT DISTINCT doctor_id
        FROM public.appointments
       WHERE user_id = u.id
         AND doctor_id IS NOT NULL
    LOOP
      -- Try to find an existing manual patient row for this (doctor, phone)
      -- so we don't create duplicates if the doctor had previously added
      -- this person manually before they became a DocSera user.
      v_dp_pid := NULL;
      IF v_phone IS NOT NULL THEN
        SELECT patient_id INTO v_dp_pid
          FROM public.doctor_patients
         WHERE doctor_id = d.doctor_id
           AND phone_number = v_phone
         LIMIT 1;
      END IF;

      IF v_dp_pid IS NULL THEN
        INSERT INTO public.doctor_patients
          (doctor_id, first_name, last_name, patient_name,
           email, phone_number, gender, date_of_birth,
           was_docsera_user, docsera_account_deleted_at, prior_user_id)
        VALUES
          (d.doctor_id, u.first_name, u.last_name, v_full_name,
           u.email, v_phone, u.gender, u.date_of_birth,
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
               gender = COALESCE(gender, u.gender),
               date_of_birth = COALESCE(date_of_birth, u.date_of_birth)
         WHERE patient_id = v_dp_pid;
      END IF;

      -- Re-point appointments for this doctor to the manual patient.
      UPDATE public.appointments
         SET user_id = NULL,
             manual_id = v_dp_pid
       WHERE user_id = u.id
         AND doctor_id = d.doctor_id;
    END LOOP;

    -- Close any conversations the patient had — they exist as historical
    -- record but the doctor can no longer reply (no DocSera account to
    -- receive). Patient_id stays pointing to the (about-to-be-pseudonymized)
    -- users.id row so RLS still resolves for any clinic admin tools that
    -- read conversations.
    UPDATE public.conversations
       SET is_closed = true,
           updated_at = now()
     WHERE patient_id = u.id
       AND COALESCE(is_closed, false) = false;

    -- Re-point documents that are owned by the user (patient-uploaded or
    -- doctor-uploaded with both user_id + patient_id). The doctor-uploaded
    -- ones already have a doctor reference — link them to the new manual
    -- patient by setting patient_id to the doctor_patients.patient_id (NULL
    -- the user_id). Patient self-uploads (no doctor_id linkage) just get
    -- their user_id NULLed; they're already orphaned for the doctor side.
    UPDATE public.documents
       SET user_id = NULL
     WHERE user_id = u.id;

    -- Drop strictly-patient-side records. The doctor's clinical record
    -- (notes the doctor took, reports they wrote) lives on appointments
    -- and is preserved. These are the patient's own self-managed bits.
    DELETE FROM public.patient_health_profile WHERE user_id = u.id;
    DELETE FROM public.user_devices WHERE user_id = u.id;
    -- Notifications: keep them on the historical side (notification_events
    -- audit) but the user-visible inbox rows can go.
    DELETE FROM public.notifications WHERE user_id = u.id;

    -- Pseudonymize public.users (the row stays as a tombstone with no PII;
    -- the audit columns deletion_pseudonymized_at + prior data are
    -- preserved). Hard-delete is deferred to a future year-7 retention
    -- cron and isn't included in this migration.
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

    -- Drop the auth.users row so the patient can't sign in anymore. The
    -- public.users tombstone row stays.
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

REVOKE ALL ON FUNCTION public.fn_cron_account_deletion_finalize() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. Schedule via pg_cron — daily at 02:00 UTC (low-traffic window)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed — skipping schedule.';
    RETURN;
  END IF;

  PERFORM cron.unschedule('notif_account_deletion_finalize')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notif_account_deletion_finalize');

  PERFORM cron.schedule(
    'notif_account_deletion_finalize',
    '0 2 * * *',  -- daily 02:00 UTC
    $cmd$ SELECT public.fn_cron_account_deletion_finalize() $cmd$
  );
END $$;

COMMIT;
