-- =============================================================================
-- fn_user_display_name(uuid) — single source of truth for team member names.
-- =============================================================================
-- Pro user names live in two completely separate places:
--   - Clinicians (owner/doctor/specialist) → public.doctors.first_name/last_name
--   - Staff (secretary/admin) → public.team_profiles.first_name/last_name
--     joined via center_members.legacy_doctor_member_id
-- public.users.first_name is empty for almost every Pro member because the
-- onboarding wizards only populate the role-specific table. So previous code
-- that only queried public.users got "Someone" for every secretary action
-- (the "Someone reassigned a task" bug behind the 20-push storm on iPhone).
--
-- This function encodes the FULL lookup chain in one place. Every handler
-- + trigger that needs to print a member name should call this RPC.

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_user_display_name(p_user_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_name text;
  v_fallback text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 'Someone';
  END IF;

  -- 1. Clinician via center_members → doctors. Takes the FIRST active
  --    membership; a doctor is normally only in one center, but if they
  --    happen to be in multiple we don't care which name we pick.
  SELECT NULLIF(trim(
    coalesce(d.title, '') || ' ' ||
    coalesce(d.first_name, '') || ' ' ||
    coalesce(d.last_name, '')
  ), '')
    INTO v_name
    FROM public.center_members cm
    JOIN public.doctors d ON d.id = cm.doctor_id
   WHERE cm.user_id = p_user_id
     AND cm.is_active = true
     AND cm.removed_at IS NULL
   ORDER BY cm.joined_at ASC NULLS LAST
   LIMIT 1;
  IF v_name IS NOT NULL THEN
    RETURN v_name;
  END IF;

  -- 2. Staff via team_profiles (joined by legacy_doctor_member_id).
  SELECT NULLIF(trim(
    coalesce(tp.first_name, '') || ' ' ||
    coalesce(tp.last_name, '')
  ), '')
    INTO v_name
    FROM public.center_members cm
    JOIN public.team_profiles tp ON tp.doctor_member_id = cm.legacy_doctor_member_id
   WHERE cm.user_id = p_user_id
     AND cm.is_active = true
     AND cm.removed_at IS NULL
   ORDER BY cm.joined_at ASC NULLS LAST
   LIMIT 1;
  IF v_name IS NOT NULL THEN
    RETURN v_name;
  END IF;

  -- 3. public.users — patient app users (when a doctor is also a
  --    patient on the patient side, their name lives here).
  SELECT NULLIF(trim(
    coalesce(u.first_name, '') || ' ' ||
    coalesce(u.last_name, '')
  ), '')
    INTO v_name
    FROM public.users u
   WHERE u.id = p_user_id;
  IF v_name IS NOT NULL THEN
    RETURN v_name;
  END IF;

  -- 4. Phone / email fallback.
  SELECT COALESCE(NULLIF(u.phone_number, ''), NULLIF(u.email, ''))
    INTO v_fallback
    FROM public.users u
   WHERE u.id = p_user_id;
  IF v_fallback IS NOT NULL THEN
    RETURN v_fallback;
  END IF;

  RETURN 'Someone';
END $$;

REVOKE ALL ON FUNCTION public.fn_user_display_name(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_user_display_name(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_user_display_name(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_user_display_name(uuid) IS
  'Single source of truth for "what name should we print for this '
  'user?" across notification handlers. Walks: doctors → team_profiles '
  '→ users.first_name/last_name → phone_number → email → "Someone".';

COMMIT;
