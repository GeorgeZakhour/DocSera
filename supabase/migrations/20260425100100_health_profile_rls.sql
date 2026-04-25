-- 20260425100100_health_profile_rls.sql
-- RLS policies for patient_health_profile.
-- Patient: full r/w on own row.
-- Doctor:  read-only for patients in their care, joined via doctor_patient_links + doctor_members.

-- Patient: full access to own row
create policy patient_health_profile_owner_select
on public.patient_health_profile
for select using (user_id = auth.uid());

create policy patient_health_profile_owner_insert
on public.patient_health_profile
for insert with check (user_id = auth.uid());

create policy patient_health_profile_owner_update
on public.patient_health_profile
for update using (user_id = auth.uid())
with check (user_id = auth.uid());

-- Doctor: read-only when the doctor has the patient linked AND is an active member.
-- This mirrors the patient-discovery pathway used elsewhere in the doctor app
-- (doctor_patient_links is the canonical join; doctor_members maps auth.uid() -> doctor_id).
create policy patient_health_profile_doctor_read
on public.patient_health_profile
for select using (
  exists (
    select 1
    from public.doctor_patient_links dpl
    join public.doctor_members dm
      on dm.doctor_id = dpl.doctor_id
     and dm.is_active = true
    where dpl.patient_type = 'user'
      and dpl.patient_ref_id = patient_health_profile.user_id
      and dm.user_id = auth.uid()
  )
);
