-- =============================================================================
-- fn_resolve_recipients — honor explicit `false` in permissions JSON.
-- =============================================================================
-- Previous gate used `cm.permissions ? key` which returns true if the
-- key EXISTS in the JSON, regardless of value. So a secretary with
-- `{"viewMessages": false}` still passed the check and received message
-- notifications.
--
-- Fix: evaluate the value (`permissions->>key)::boolean IS TRUE`. Keep
-- the legacy "permissive when blank" fallback (NULL or `{}`) so
-- secretaries whose permissions JSON hasn't been seeded yet aren't
-- silently muted.
--
-- Also: change the pro.appointment.% gate from `manageAppointments`
-- (a permission key the Pro UI does not actually write — only the
-- enum is named that way client-side) to `viewCalendar`. `viewCalendar`
-- is the permission the team-permissions editor writes today, so the
-- gate matches the data.

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_resolve_recipients(
  p_event_code text,
  p_ctx        jsonb
)
RETURNS SETOF uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
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
    -- viewCalendar is what the Pro team-permissions editor actually
    -- writes; manageAppointments only exists as a client-side enum.
    v_required_perm := 'viewCalendar';
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
            AND (
              cm.permissions IS NULL
              OR cm.permissions = '{}'::jsonb
              OR (cm.permissions->>v_required_perm)::boolean IS TRUE
            ))
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
            AND (
              cm.permissions IS NULL
              OR cm.permissions = '{}'::jsonb
              OR (cm.permissions->>v_required_perm)::boolean IS TRUE
            ))
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

COMMIT;
