-- The Pro patient detail loads via rpc_get_full_manual_profile (a
-- different code path than rpc_search_clinic_patients which feeds the
-- list). The RPC body was a hand-written jsonb_build_object with only
-- 7 fields; was_docsera_user / docsera_account_deleted_at /
-- prior_user_id were never surfaced, so the "Former DocSera user"
-- badge never rendered.
--
-- Adding the three flags. Pro reads patient['was_docsera_user'] and
-- the badge conditional in patient_info_section.dart now evaluates
-- correctly.

CREATE OR REPLACE FUNCTION public.rpc_get_full_manual_profile(
  p_manual_id uuid,
  p_account_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'source', 'manual',
    'manual_id', dp.patient_id,
    'patient_name', dp.patient_name,
    'first_name', dp.first_name,
    'last_name', dp.last_name,
    'gender', dp.gender,
    'date_of_birth', dp.date_of_birth,
    'email', dp.email,
    'phone_number', dp.phone_number,
    'was_docsera_user', COALESCE(dp.was_docsera_user, false),
    'docsera_account_deleted_at', dp.docsera_account_deleted_at,
    'prior_user_id', dp.prior_user_id
  )
  FROM doctor_patients dp
  JOIN doctors d ON d.id = dp.doctor_id
  WHERE dp.patient_id = p_manual_id
    AND public.is_clinic_member_of_account(d.doctor_account_id)
    AND d.doctor_account_id = p_account_id;
$$;
