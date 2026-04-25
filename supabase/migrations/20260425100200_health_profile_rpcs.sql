-- 20260425100200_health_profile_rpcs.sql
-- RPCs that back the patient health-profile wizard.
-- A3: complete_health_profile()  — idempotent +15 points award on first reach
-- A4: upsert_health_profile_vitals_lifestyle(...)  — partial save between steps (added later)

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
