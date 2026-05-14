-- =============================================================================
-- Reschedule lineage for the 3-arg overload (with p_reason_id).
-- =============================================================================
-- The patient app calls the 3-arg variant of reschedule_appointment_by_patient
-- (the one that takes p_reason_id). The lineage migration I shipped earlier
-- only patched the 2-arg variant — so reschedules from the live patient app
-- still produced a "new booking" notification on the doctor side instead of
-- a "rescheduled from X to Y" notification.
--
-- Same fix as the 2-arg patch: thread rescheduled_from_id +
-- rescheduled_from_timestamp onto the new row so the Pro handler can
-- classify it as a reschedule.

BEGIN;

CREATE OR REPLACE FUNCTION public.reschedule_appointment_by_patient(
  p_old_appointment_id uuid,
  p_new_timestamp timestamp with time zone,
  p_reason_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
declare
  v_old appointments;
  v_deadline int;
  v_new_id uuid;
  v_requires_confirmation boolean;
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

  select cancellation_deadline_hours, require_confirmation
  into v_deadline, v_requires_confirmation
  from doctors
  where id = v_old.doctor_id;

  if now() > (v_old.timestamp - make_interval(hours => v_deadline)) then
    raise exception 'too_late';
  end if;

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
    p_reason_id,
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
    not v_requires_confirmation,
    v_old.relative_id,
    -- NEW values
    v_old.id,
    v_old.timestamp
  )
  returning id into v_new_id;

  delete from appointments where id = p_old_appointment_id;

  return v_new_id;
end;
$$;

COMMIT;
