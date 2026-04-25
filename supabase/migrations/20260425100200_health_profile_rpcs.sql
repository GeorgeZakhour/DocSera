-- 20260425100200_health_profile_rpcs.sql
-- RPCs that back the patient health-profile wizard.
-- A3: complete_health_profile()  — idempotent +15 points award on first reach
-- A4: upsert_health_profile_vitals_lifestyle(...)  — partial save between steps

create or replace function public.complete_health_profile()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing timestamptz;
  v_new_balance int;
begin
  if v_user_id is null then
    raise exception 'auth required';
  end if;

  select health_profile_completed_at, points
    into v_existing, v_new_balance
    from public.users
    where id = v_user_id
    for update;

  if v_existing is not null then
    return jsonb_build_object(
      'already_awarded', true,
      'new_balance', v_new_balance,
      'completed_at', v_existing
    );
  end if;

  -- Ensure the patient_health_profile row exists (the wizard's vitals/lifestyle
  -- setter may not have run if the user skipped every input step).
  insert into public.patient_health_profile (user_id, completed_at)
    values (v_user_id, now())
    on conflict (user_id) do update set completed_at = excluded.completed_at;

  update public.users
    set health_profile_completed_at = now(),
        points = points + 15
    where id = v_user_id
    returning points into v_new_balance;

  insert into public.points_history (user_id, points, description, metadata, processed)
    values (v_user_id, 15, 'Health profile completed',
            jsonb_build_object('source', 'health_profile'), true);

  return jsonb_build_object(
    'already_awarded', false,
    'new_balance', v_new_balance,
    'completed_at', now()
  );
end;
$$;

grant execute on function public.complete_health_profile() to authenticated;

create or replace function public.upsert_health_profile_vitals_lifestyle(
  p_height_cm numeric default null,
  p_weight_kg numeric default null,
  p_sport_frequency text default null,
  p_smoking_status text default null,
  p_alcohol_frequency text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'auth required';
  end if;

  insert into public.patient_health_profile as p (
    user_id, height_cm, weight_kg, sport_frequency, smoking_status, alcohol_frequency
  ) values (
    v_user_id, p_height_cm, p_weight_kg, p_sport_frequency, p_smoking_status, p_alcohol_frequency
  )
  on conflict (user_id) do update set
    height_cm = coalesce(excluded.height_cm, p.height_cm),
    weight_kg = coalesce(excluded.weight_kg, p.weight_kg),
    sport_frequency = coalesce(excluded.sport_frequency, p.sport_frequency),
    smoking_status = coalesce(excluded.smoking_status, p.smoking_status),
    alcohol_frequency = coalesce(excluded.alcohol_frequency, p.alcohol_frequency);
end;
$$;

grant execute on function public.upsert_health_profile_vitals_lifestyle(
  numeric, numeric, text, text, text
) to authenticated;
