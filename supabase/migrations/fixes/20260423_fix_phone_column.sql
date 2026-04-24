CREATE OR REPLACE FUNCTION rpc_get_my_shared_reports(
  p_user_id UUID,
  p_relative_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT jsonb_build_object(
      'id', r.id,
      'appointment_id', r.appointment_id,
      'doctor_id', r.doctor_id,
      'user_id', r.user_id,
      'relative_id', r.relative_id,
      'patient_name', r.patient_name,
      'share_mode', r.share_mode,
      'patient_visible_sections', r.patient_visible_sections,
      'sections', fn_strip_heavy_sections(r.sections),
      'created_at', r.created_at,
      'updated_at', r.updated_at,
      -- Denormalized doctor info
      'doctor_name', COALESCE(d.first_name, '') || ' ' || COALESCE(d.last_name, ''),
      'doctor_specialty', d.specialty,
      'doctor_clinic', d.clinic,
      'doctor_image', d.doctor_image,
      'doctor_gender', d.gender,
      'doctor_title', d.title,
      'doctor_phone', d.contact_phones,
      'doctor_mobile', d.contact_mobile,
      'doctor_email', d.contact_email,
      'doctor_website', d.contact_website,
      -- Patient info from linked user/relative
      'patient_gender', COALESCE(
        (SELECT u.gender FROM public.users u WHERE u.id = r.user_id),
        (SELECT rel.gender FROM public.relatives rel WHERE rel.id = r.relative_id)
      ),
      'patient_dob', COALESCE(
        (SELECT u.date_of_birth FROM public.users u WHERE u.id = r.user_id),
        (SELECT rel.date_of_birth FROM public.relatives rel WHERE rel.id = r.relative_id)
      ),
      'patient_phone', (SELECT u.phone_number FROM public.users u WHERE u.id = r.user_id)
    ) AS row_data,
    r.created_at
    FROM public.reports r
    LEFT JOIN public.doctors d ON d.id = r.doctor_id
    WHERE r.shared_with_patient = true
      AND (
        (p_relative_id IS NOT NULL AND r.relative_id = p_relative_id)
        OR (p_relative_id IS NULL AND r.user_id = p_user_id)
      )
  ) sub;

  RETURN v_result;
END;
$$;
