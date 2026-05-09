-- Surface was_docsera_user / docsera_account_deleted_at / prior_user_id
-- through the patient list pipeline so the Pro patient detail can render
-- the "Former DocSera user" badge for forked manual patients.
--
-- Path of the data:
--   doctor_patients.was_docsera_user (set by fn_cron_account_deletion_finalize)
--     → v_clinic_patients_searchable (view, this migration adds the cols)
--       → rpc_search_clinic_patients (RPC, this migration extends RETURNS)
--         → Pro patient list/detail (already reads patient['was_docsera_user'])

BEGIN;

CREATE OR REPLACE VIEW public.v_clinic_patients_searchable AS
SELECT dap.doctor_account_id,
       CASE WHEN dap.patient_type = 'user'::text THEN dap.patient_ref_id ELSE NULL::uuid END AS user_id,
       CASE WHEN dap.patient_type = 'relative'::text THEN dap.patient_ref_id ELSE NULL::uuid END AS relative_id,
       CASE WHEN dap.patient_type = 'manual'::text THEN dap.patient_ref_id ELSE NULL::uuid END AS manual_id,
       dap.patient_type,
       dap.patient_ref_id,
       COALESCE(u.first_name, r.first_name, dp.first_name) AS first_name,
       COALESCE(u.last_name, r.last_name, dp.last_name) AS last_name,
       COALESCE((u.first_name || ' '::text) || u.last_name,
                (r.first_name || ' '::text) || r.last_name,
                dp.patient_name) AS patient_name,
       COALESCE(u.gender, r.gender, dp.gender) AS gender,
       COALESCE(u.gender, r.gender, dp.gender) AS user_gender,
       COALESCE(u.date_of_birth, r.date_of_birth, dp.date_of_birth) AS date_of_birth,
       CASE
         WHEN u.date_of_birth IS NOT NULL THEN date_part('year'::text, age(u.date_of_birth::timestamp with time zone))
         WHEN r.date_of_birth IS NOT NULL THEN date_part('year'::text, age(r.date_of_birth::timestamp with time zone))
         WHEN dp.date_of_birth IS NOT NULL THEN date_part('year'::text, age(dp.date_of_birth::timestamp with time zone))
         ELSE NULL::double precision
       END::integer AS user_age,
       COALESCE(u.email, r.email, dp.email) AS email,
       COALESCE(u.phone_number, r.phone_number, dp.phone_number) AS phone_number,
       dap.patient_type = 'manual'::text AS is_manual_patient,
       dap.patient_type <> 'manual'::text AS is_docsera_user,
       dap.patient_type AS source,
       CASE WHEN dap.patient_type = 'relative'::text THEN (u.first_name || ' '::text) || u.last_name ELSE NULL::text END AS account_name,
       dap.first_seen_at,
       dap.last_seen_at,
       -- NEW: ex-DocSera-user flags (only meaningful for manual patients)
       COALESCE(dp.was_docsera_user, false) AS was_docsera_user,
       dp.docsera_account_deleted_at,
       dp.prior_user_id
FROM doctor_account_patients dap
LEFT JOIN users u ON dap.patient_type = 'user'::text AND u.id = dap.patient_ref_id
LEFT JOIN relatives r ON dap.patient_type = 'relative'::text AND r.id = dap.patient_ref_id
LEFT JOIN doctor_patients dp ON dap.patient_type = 'manual'::text AND dp.patient_id = dap.patient_ref_id;

-- ---------------------------------------------------------------------------
-- Update RPC to surface the new columns.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_search_clinic_patients(uuid, text, integer);

CREATE FUNCTION public.rpc_search_clinic_patients(
  p_account_id uuid,
  p_query text DEFAULT NULL,
  p_limit integer DEFAULT 20
)
RETURNS TABLE(
  patient_type text,
  patient_ref_id uuid,
  first_name text,
  last_name text,
  patient_name text,
  user_gender text,
  date_of_birth date,
  user_age integer,
  phone_number text,
  email text,
  is_manual_patient boolean,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  source text,
  user_id uuid,
  relative_id uuid,
  manual_id uuid,
  was_docsera_user boolean,
  docsera_account_deleted_at timestamptz,
  prior_user_id uuid
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    v.patient_type,
    v.patient_ref_id,
    v.first_name,
    v.last_name,
    v.patient_name,
    v.gender AS user_gender,
    v.date_of_birth,
    CASE
      WHEN v.date_of_birth IS NOT NULL
      THEN date_part('year', age(current_date, v.date_of_birth))::int
      ELSE NULL
    END AS user_age,
    v.phone_number,
    v.email,
    v.is_manual_patient,
    v.first_seen_at,
    v.last_seen_at,
    v.source,
    v.user_id,
    v.relative_id,
    v.manual_id,
    v.was_docsera_user,
    v.docsera_account_deleted_at,
    v.prior_user_id
  FROM public.v_clinic_patients_searchable v
  WHERE
    v.doctor_account_id = p_account_id
    AND (
      public.is_clinic_member_of_account(p_account_id)
      OR public.fn_secretary_can_view_patients_of_account(p_account_id)
    )
    AND (
      p_query IS NULL
      OR p_query = ''
      OR v.patient_name ILIKE '%' || p_query || '%'
      OR v.phone_number ILIKE '%' || p_query || '%'
      OR v.email ILIKE '%' || p_query || '%'
    )
  ORDER BY v.last_seen_at DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 50));
$$;

COMMIT;
