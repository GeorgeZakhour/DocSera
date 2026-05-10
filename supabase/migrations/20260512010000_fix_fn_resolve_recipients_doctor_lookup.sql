-- Fix: the original fn_resolve_recipients subquery
--   (SELECT user_id FROM center_members WHERE center_id=X AND doctor_id=Y LIMIT 1)
-- returned whichever center_members row had matching doctor_id —
-- often the secretary's, not the doctor's, because both rows reference
-- the same doctor_id (the doctor's own row has doctor_id = himself,
-- the secretary's row has doctor_id = the doctor she serves). The
-- effect was that the doctor never matched and the secretary failed
-- the role check, so the resolver returned an empty set.
--
-- Fix: filter directly on (doctor_id, role membership). For the
-- secretary branch, treat empty assigned_doctor_ids as "covers all
-- doctors in the center" — this matches the data shape today, where
-- most multi-staff clinics haven't bothered to set scoping yet.

CREATE OR REPLACE FUNCTION public.fn_resolve_recipients(
  p_event_code text,
  p_ctx        jsonb
)
RETURNS setof uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_center_id     uuid := (p_ctx->>'center_id')::uuid;
  v_doctor_id     uuid := (p_ctx->>'doctor_id')::uuid;
  v_actor_user_id uuid := (p_ctx->>'actor_user_id')::uuid;
  v_required_perm text;
BEGIN
  IF p_event_code IS NULL OR length(trim(p_event_code)) = 0 THEN
    RAISE EXCEPTION 'INVALID_EVENT_CODE';
  END IF;

  IF p_event_code LIKE 'pro.appointment.%' THEN
    v_required_perm := 'manageAppointments';
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND (
           -- the doctor themselves (matches owner/doctor/specialist
           -- whose own doctor_id equals v_doctor_id)
           (cm.doctor_id = v_doctor_id
            AND (cm.roles && ARRAY['owner','doctor','specialist']::member_role[]))
           OR
           -- a secretary explicitly assigned to this doctor,
           -- OR (fallback for un-scoped teams) a secretary in the
           -- center with no assigned_doctor_ids set yet
           (cm.roles && ARRAY['secretary']::member_role[]
            AND (
              v_doctor_id = ANY (cm.assigned_doctor_ids)
              OR cm.assigned_doctor_ids = '{}'::uuid[]
            )
            AND (cm.permissions ? v_required_perm
                 OR cm.permissions = '{}'::jsonb))
         );
    RETURN;
  END IF;

  IF p_event_code LIKE 'pro.message.%' THEN
    v_required_perm := 'viewMessages';
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND (
           (cm.doctor_id = v_doctor_id
            AND (cm.roles && ARRAY['owner','doctor','specialist']::member_role[]))
           OR
           (cm.roles && ARRAY['secretary']::member_role[]
            AND (
              v_doctor_id = ANY (cm.assigned_doctor_ids)
              OR cm.assigned_doctor_ids = '{}'::uuid[]
            )
            AND (cm.permissions ? v_required_perm
                 OR cm.permissions = '{}'::jsonb))
         );
    RETURN;
  END IF;

  IF p_event_code LIKE 'pro.subscription.%' OR p_event_code LIKE 'pro.storage.%' THEN
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND (cm.roles && ARRAY['owner','admin']::member_role[]);
    RETURN;
  END IF;

  IF p_event_code LIKE 'pro.verification.%' THEN
    IF v_doctor_id IS NOT NULL THEN
      RETURN QUERY
        SELECT DISTINCT cm.user_id
          FROM public.center_members cm
         WHERE cm.doctor_id = v_doctor_id
           AND (cm.roles && ARRAY['owner','doctor','specialist']::member_role[])
           AND cm.is_active = true
           AND cm.removed_at IS NULL
         LIMIT 1;
    END IF;
    RETURN;
  END IF;

  IF p_event_code LIKE 'pro.team.%' THEN
    -- Default: owner + admins. Specific events (invitation_received,
    -- member_removed) pass user_ids directly via the handler — they
    -- don't call this branch.
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND (cm.roles && ARRAY['owner','admin']::member_role[]);
    RETURN;
  END IF;

  RETURN;
END $$;
