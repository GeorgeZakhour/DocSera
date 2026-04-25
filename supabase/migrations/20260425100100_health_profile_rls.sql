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

-- Doctor: read-only when the patient is linked to any doctor in the clinic account
-- AND the requester is an active member of that account. Mirrors the team-scoped
-- pathway used by other patient data in the doctor app.
create policy patient_health_profile_doctor_read
on public.patient_health_profile
for select using (
  exists (
    select 1
    from public.doctor_members dm
    join public.doctors d on d.doctor_account_id = dm.doctor_account_id
    join public.doctor_patient_links dpl on dpl.doctor_id = d.id
    where dm.user_id = auth.uid()
      and dm.is_active = true
      and dpl.patient_type = 'user'
      and dpl.patient_ref_id = patient_health_profile.user_id
  )
);
