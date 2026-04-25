-- 20260425_health_profile_table.sql
-- Creates the patient_health_profile table for vitals + lifestyle answers.

create table public.patient_health_profile (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  height_cm numeric null,
  weight_kg numeric null,
  sport_frequency text null
    check (sport_frequency is null or sport_frequency in
           ('never','less_than_weekly','1_2','3_4','5_plus')),
  smoking_status text null
    check (smoking_status is null or smoking_status in
           ('never','former','occasional','daily')),
  alcohol_frequency text null
    check (alcohol_frequency is null or alcohol_frequency in
           ('never','less_than_weekly','1_2','3_4','5_plus')),
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint patient_health_profile_pkey primary key (id),
  constraint patient_health_profile_user_id_unique unique (user_id),
  constraint patient_health_profile_user_id_fkey
    foreign key (user_id) references public.users(id) on delete cascade
);

alter table public.patient_health_profile enable row level security;

create or replace function public.set_updated_at_health_profile()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_health_profile_updated_at
before update on public.patient_health_profile
for each row execute function public.set_updated_at_health_profile();

alter table public.users
  add column if not exists health_profile_completed_at timestamptz null;

comment on table public.patient_health_profile is
  'Self-reported vitals + lifestyle answers from the health profile wizard.';
comment on column public.users.health_profile_completed_at is
  'Mirror of patient_health_profile.completed_at for cheap banner queries.';
