-- =============================================================================
-- Reschedule lineage: link the new row to the old one it replaced.
-- =============================================================================
-- The reschedule_appointment_by_patient RPC currently INSERTs a new
-- appointment + DELETEs the old one. From the doctor's side that
-- looks like a fresh booking — the Pro notification handler emits
-- pro.appointment.booked_pending with no hint that this is actually
-- the patient moving an existing slot.
--
-- Fix: persist a small marker on the new row pointing at the old id
-- + the old timestamp, so the Pro handler can classify it as a
-- reschedule and surface the right copy to the doctor.

BEGIN;

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS rescheduled_from_id uuid,
  ADD COLUMN IF NOT EXISTS rescheduled_from_timestamp timestamptz;

COMMENT ON COLUMN public.appointments.rescheduled_from_id IS
  'When this row was created via reschedule_appointment_by_patient, '
  'this holds the id of the appointment row that was deleted. Used '
  'by the Pro notification handler to detect "reschedule" vs '
  '"fresh booking".';

COMMENT ON COLUMN public.appointments.rescheduled_from_timestamp IS
  'The old appointment timestamp (the slot the patient moved away '
  'from). Embedded in the doctor''s notification copy so they see '
  '"rescheduled from <old> to <new>" rather than just the new time.';

-- Patch the RPC. We keep the existing DELETE-then-INSERT shape
-- (changing it to a soft-cancel would ripple through every other
-- caller that reads the table) and just thread the lineage onto the
-- new row.
CREATE OR REPLACE FUNCTION public.reschedule_appointment_by_patient(
  p_old_appointment_id uuid,
  p_new_timestamp timestamp with time zone
)
RETURNS TABLE(appointment_id uuid, is_confirmed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
declare
  v_old appointments;
  v_deadline int;
  v_requires_confirmation boolean;
  v_new_id uuid;
  v_is_confirmed boolean;
begin
  select * into v_old
  from appointments
  where id = p_old_appointment_id;

  if not found then
    raise exception 'appointment_not_found';
  end if;

  if v_old.user_id != auth.uid() then
    raise exception 'not_owner';
  end if;

  select
    cancellation_deadline_hours,
    require_confirmation
  into
    v_deadline,
    v_requires_confirmation
  from doctors
  where id = v_old.doctor_id;

  if not found then
    raise exception 'doctor_not_found';
  end if;

  if now() > (v_old.timestamp - make_interval(hours => v_deadline)) then
    raise exception 'too_late';
  end if;

  v_is_confirmed := not v_requires_confirmation;

  insert into appointments (
    user_id,
    doctor_id,
    doctor_account_id,
    timestamp,
    booked,
    patient_name,
    user_gender,
    user_age,
    new_patient,
    reason_id,
    reason,
    clinic_address,
    location,
    doctor_title,
    doctor_image,
    doctor_specialty,
    doctor_name,
    doctor_gender,
    clinic,
    booking_timestamp,
    is_docsera_user,
    booked_via,
    is_confirmed,
    relative_id,
    status,
    -- NEW: reschedule lineage
    rescheduled_from_id,
    rescheduled_from_timestamp
  )
  values (
    v_old.user_id,
    v_old.doctor_id,
    v_old.doctor_account_id,
    p_new_timestamp,
    true,
    v_old.patient_name,
    v_old.user_gender,
    v_old.user_age,
    v_old.new_patient,
    v_old.reason_id,
    v_old.reason,
    v_old.clinic_address,
    v_old.location,
    v_old.doctor_title,
    v_old.doctor_image,
    v_old.doctor_specialty,
    v_old.doctor_name,
    v_old.doctor_gender,
    v_old.clinic,
    now() at time zone 'utc',
    true,
    'DocSera',
    v_is_confirmed,
    v_old.relative_id,
    'not_arrived',
    -- NEW values
    v_old.id,
    v_old.timestamp
  )
  returning id into v_new_id;

  delete from appointments
  where id = p_old_appointment_id;

  appointment_id := v_new_id;
  is_confirmed := v_is_confirmed;
  return next;
end;
$$;

COMMIT;
