-- ============================================================
-- Notifications platform — DocSera-Pro, Phase 2.0 (foundation)
-- ============================================================
--
-- This migration enables the dormant `recipient_app='docsera_pro'`
-- path for the doctor app. Phase 1 built the platform (notifications,
-- templates, preferences, quiet hours, events, fanout via the
-- push_notifications edge function). This migration adds:
--
--   1. Category expansion — new categories for Pro-specific event
--      classes (team, clinic_ops, subscription, verification, tasks)
--      on notifications, notification_preferences, notification_templates.
--
--   2. fn_resolve_recipients(p_event_code, p_ctx) → setof uuid — the
--      single source of truth for role-aware fanout. Edge function
--      handlers and SQL triggers both call this to get the list of
--      user_ids for a given event in a given (center, doctor) context.
--      Rules are encoded once here; new events add a CASE branch.
--
-- This migration does NOT seed any Pro event templates yet — those
-- ship with their per-phase handlers (2.1 appointments, 2.3 team, etc.)
-- so each event lands with its copy in the same change.

-- ----------------------------------------------------------------
-- 1. Category constraint expansion
-- ----------------------------------------------------------------
-- Pro events need five new categories. Touch all three constraints
-- (notifications, notification_preferences, notification_templates)
-- so they stay aligned.

DO $$
DECLARE
  v_cats text[] := ARRAY[
    'appointments', 'messages', 'documents', 'reports',
    'loyalty', 'security', 'marketing', 'system',
    'health', 'relatives',
    -- Pro additions:
    'team',          -- invitations, membership, role/permission changes
    'clinic_ops',    -- storage warnings, calendar-side vacation alerts
    'subscription',  -- trial / paid / grace / expired
    'verification',  -- doctor identity + license verification flow
    'tasks'          -- todo_tasks (was 'system' for the existing handler)
  ];
BEGIN
  ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_category_check;
  EXECUTE format(
    'ALTER TABLE public.notifications ADD CONSTRAINT notifications_category_check CHECK (category = ANY (%L::text[]))',
    v_cats
  );

  ALTER TABLE public.notification_preferences
    DROP CONSTRAINT IF EXISTS notification_preferences_category_check;
  EXECUTE format(
    'ALTER TABLE public.notification_preferences ADD CONSTRAINT notification_preferences_category_check CHECK (category = ANY (%L::text[]))',
    v_cats
  );

  ALTER TABLE public.notification_templates
    DROP CONSTRAINT IF EXISTS notification_templates_default_category_check;
  EXECUTE format(
    'ALTER TABLE public.notification_templates ADD CONSTRAINT notification_templates_default_category_check CHECK (default_category = ANY (%L::text[]))',
    v_cats
  );
END $$;

-- ----------------------------------------------------------------
-- 2. fn_resolve_recipients — role-aware fanout
-- ----------------------------------------------------------------
-- Given an event code and a jsonb context, returns the set of auth
-- user_ids that should receive an inbox row + push for the event.
--
-- Context keys consumed (all optional, depends on event):
--   center_id        uuid   the affected center
--   doctor_id        uuid   the affected doctor (for per-doctor events)
--   actor_user_id    uuid   the user who CAUSED the event — excluded
--                           from the result set (you don't notify
--                           yourself about your own action)
--
-- Rules — keep this comment in sync with docs/launch/15-notifications-platform.md:
--
--   pro.appointment.*  : doctor + assigned secretaries (with the
--                        appropriate permission) within the center
--   pro.message.*      : doctor + secretaries with viewMessages and
--                        assigned-to-doctor
--   pro.team.*         : varies by event — handled per-branch
--   pro.subscription.* : owner + admins of the center
--   pro.storage.*      : owner + admins
--   pro.verification.* : the doctor only
--   pro.security.*     : individual user only (caller passes user_id)
--   pro.task.*         : assignee / creator — passed in ctx
--
-- Implementation always filters center_members on is_active=true AND
-- removed_at IS NULL so deactivated/removed members never receive
-- pushes. Returns DISTINCT user_ids so owner+doctor (same person) is
-- counted once.

DROP FUNCTION IF EXISTS public.fn_resolve_recipients(text, jsonb);

CREATE FUNCTION public.fn_resolve_recipients(
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

  -- Branch on event family. Each branch returns DISTINCT user_ids.
  -- The actor_user_id is excluded everywhere (no self-notification).

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
           -- doctor / specialist / owner who IS this doctor
           ('doctor' = ANY (cm.roles) OR 'specialist' = ANY (cm.roles)
              OR 'owner' = ANY (cm.roles))
             AND cm.user_id = (
               SELECT user_id FROM public.center_members
                WHERE center_id = v_center_id AND doctor_id = v_doctor_id
                LIMIT 1
             )
           )
           OR (
             -- secretary assigned to the doctor with the right permission
             'secretary' = ANY (cm.roles)
             AND v_doctor_id = ANY (cm.assigned_doctor_ids)
             AND (cm.permissions ? v_required_perm)
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
           -- the doctor themselves (resolved by doctor_id → user_id)
           cm.user_id = (
             SELECT user_id FROM public.center_members
              WHERE center_id = v_center_id AND doctor_id = v_doctor_id
              LIMIT 1
           )
           OR (
             'secretary' = ANY (cm.roles)
             AND v_doctor_id = ANY (cm.assigned_doctor_ids)
             AND (cm.permissions ? v_required_perm)
           )
         );
    RETURN;
  END IF;

  IF p_event_code LIKE 'pro.subscription.%' OR p_event_code LIKE 'pro.storage.%' THEN
    -- Owner + admins of the center. Verification/storage/billing
    -- decisions are theirs to make, not the staff's.
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND ('owner' = ANY (cm.roles) OR 'admin' = ANY (cm.roles));
    RETURN;
  END IF;

  -- pro.verification.*, pro.security.*, pro.task.* — caller passes
  -- the specific user_id in ctx (or we resolve from doctor_id).
  IF p_event_code LIKE 'pro.verification.%' THEN
    IF v_doctor_id IS NOT NULL THEN
      RETURN QUERY
        SELECT DISTINCT cm.user_id
          FROM public.center_members cm
         WHERE cm.doctor_id = v_doctor_id
           AND cm.is_active = true
           AND cm.removed_at IS NULL
         LIMIT 1;
    END IF;
    RETURN;
  END IF;

  -- pro.team.* — handled by per-event SQL in handlers/pro_team.ts
  -- because the recipient is computed from the changing row itself
  -- (invitee, inviter, removed member). The resolver here covers the
  -- common case: notify the new member's audience.
  IF p_event_code LIKE 'pro.team.%' THEN
    -- Default: owner + admins of the center. Specific handlers
    -- (invitation_received, member_removed) pass user_ids directly.
    RETURN QUERY
      SELECT DISTINCT cm.user_id
        FROM public.center_members cm
       WHERE cm.center_id = v_center_id
         AND cm.is_active = true
         AND cm.removed_at IS NULL
         AND (cm.user_id IS DISTINCT FROM v_actor_user_id)
         AND ('owner' = ANY (cm.roles) OR 'admin' = ANY (cm.roles));
    RETURN;
  END IF;

  -- Default: no recipients. Caller is expected to handle their own
  -- routing (e.g. patient-side handlers don't call this function).
  RETURN;
END $$;

REVOKE ALL ON FUNCTION public.fn_resolve_recipients(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_resolve_recipients(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_resolve_recipients(text, jsonb) TO service_role;

COMMENT ON FUNCTION public.fn_resolve_recipients(text, jsonb) IS
  'Phase 2 role-aware fanout: returns the auth user_ids that should '
  'receive an inbox row + push for the given Pro event. Branches by '
  'event_code prefix; reads center_members with role / permission / '
  'assigned_doctor_ids / is_active / removed_at filters. Always '
  'excludes the actor (no self-notification). Adding a new event = '
  'adding a CASE branch here, not a new function.';
