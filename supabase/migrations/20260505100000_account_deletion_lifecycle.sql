-- =============================================================================
-- Account deletion lifecycle — three-tier model
-- =============================================================================
-- Tier 1: Deactivation (existing rpc_deactivate_my_account) — recoverable.
-- Tier 2: Permanent-deletion request — sets deletion_requested_at; user has
--         a 30-day window to cancel.
-- Tier 3: Pseudonymization at day 30 — personal-identifying fields scrubbed
--         from users, relatives, appointments, conversations. Medical content
--         (messages, documents, clinical notes, appointment metadata) is
--         retained pseudonymized so doctors retain their clinical files.
-- Tier 4: Hard purge at year 7 — full cascade-delete of the user row and all
--         remaining medical records associated with the now-anonymous account.
--
-- Two cron jobs run these tiers daily on the VPS (installed separately).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Schema: track deletion lifecycle on the users row
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS deletion_requested_at  timestamptz,
  ADD COLUMN IF NOT EXISTS deletion_pseudonymized_at timestamptz,
  ADD COLUMN IF NOT EXISTS deletion_cancellable_until timestamptz;

CREATE INDEX IF NOT EXISTS idx_users_deletion_requested_at
  ON public.users (deletion_requested_at)
  WHERE deletion_requested_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_pseudonymized_at
  ON public.users (deletion_pseudonymized_at)
  WHERE deletion_pseudonymized_at IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. User-callable RPCs: request deletion, cancel deletion
-- ---------------------------------------------------------------------------

-- Request permanent deletion. Sets deletion_requested_at and a 30-day
-- cancellation window. Also deactivates the account immediately so the user
-- can't keep using it during the 30-day window.
CREATE OR REPLACE FUNCTION public.rpc_request_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_until timestamptz := now() + interval '30 days';
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- Idempotent: if already requested, return the existing window.
  IF EXISTS (SELECT 1 FROM public.users
              WHERE id = v_user_id AND deletion_requested_at IS NOT NULL
                AND deletion_pseudonymized_at IS NULL) THEN
    RETURN (SELECT jsonb_build_object(
      'status', 'already_requested',
      'cancellable_until', deletion_cancellable_until)
      FROM public.users WHERE id = v_user_id);
  END IF;

  UPDATE public.users
     SET is_active                  = false,
         deactivated_at             = v_now,
         deactivated_by_user_id     = v_user_id,
         deactivated_by_role        = 'self_pending_deletion',
         deletion_requested_at      = v_now,
         deletion_cancellable_until = v_until,
         updated_at                 = v_now
   WHERE id = v_user_id;

  -- Cancel future appointments (same as deactivation flow)
  UPDATE public.appointments
     SET status = 'cancelled'
   WHERE user_id = v_user_id
     AND timestamp > v_now
     AND COALESCE(status, '') NOT IN ('done', 'cancelled');

  -- Close active conversations
  UPDATE public.conversations
     SET is_closed = true, updated_at = v_now
   WHERE patient_id = v_user_id AND is_closed = false;

  RETURN jsonb_build_object(
    'status', 'requested',
    'cancellable_until', v_until
  );
END $$;

REVOKE ALL ON FUNCTION public.rpc_request_account_deletion() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_request_account_deletion() TO authenticated;

-- Cancel a pending deletion (within the 30-day window).
CREATE OR REPLACE FUNCTION public.rpc_cancel_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = v_user_id FOR UPDATE;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;
  IF v_user.deletion_requested_at IS NULL THEN
    RETURN jsonb_build_object('status', 'no_pending_deletion');
  END IF;
  IF v_user.deletion_pseudonymized_at IS NOT NULL THEN
    RAISE EXCEPTION 'DELETION_ALREADY_PROCESSED';
  END IF;
  IF v_user.deletion_cancellable_until IS NOT NULL
     AND v_user.deletion_cancellable_until < now() THEN
    RAISE EXCEPTION 'CANCELLATION_WINDOW_EXPIRED';
  END IF;

  UPDATE public.users
     SET is_active                  = true,
         deactivated_at             = NULL,
         deactivated_by_user_id     = NULL,
         deactivated_by_role        = NULL,
         deletion_requested_at      = NULL,
         deletion_cancellable_until = NULL,
         updated_at                 = now()
   WHERE id = v_user_id;

  RETURN jsonb_build_object('status', 'cancelled');
END $$;

REVOKE ALL ON FUNCTION public.rpc_cancel_account_deletion() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_account_deletion() TO authenticated;

-- Read-only: status query for the UI to render the right state.
CREATE OR REPLACE FUNCTION public.rpc_get_account_deletion_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user record;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;
  SELECT deletion_requested_at, deletion_cancellable_until,
         deletion_pseudonymized_at, is_active
    INTO v_user FROM public.users WHERE id = v_user_id;
  RETURN jsonb_build_object(
    'is_active', v_user.is_active,
    'deletion_requested_at', v_user.deletion_requested_at,
    'cancellable_until', v_user.deletion_cancellable_until,
    'pseudonymized_at', v_user.deletion_pseudonymized_at
  );
END $$;

REVOKE ALL ON FUNCTION public.rpc_get_account_deletion_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_account_deletion_status() TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Operator-callable: pseudonymize one user (called by the cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_pseudonymize_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_short text := substr(replace(p_user_id::text, '-', ''), 1, 8);
  v_pseudo_email text := 'deleted_' || v_short || '@deleted.docsera.app';
  v_pseudo_phone text := 'DELETED_' || v_short;
  v_pseudo_first text := 'مستخدم محذوف';
  v_pseudo_last  text := '';
BEGIN
  -- 1. users — scrub identifying columns; keep id + foreign-key viability
  UPDATE public.users
     SET first_name        = v_pseudo_first,
         last_name         = v_pseudo_last,
         email             = v_pseudo_email,
         phone_number      = v_pseudo_phone,
         date_of_birth     = NULL,
         gender            = NULL,
         address           = '{}'::jsonb,
         favorites         = '{}',
         doctors           = '{}',
         marketing_checked = false,
         referral_code     = NULL,
         email_verified    = false,
         phone_verified    = false,
         trusted_devices   = '{}',
         is_active         = false,
         deletion_pseudonymized_at = now(),
         updated_at        = now()
   WHERE id = p_user_id;

  -- 2. relatives — scrub all identifying fields
  UPDATE public.relatives
     SET first_name    = v_pseudo_first,
         last_name     = v_pseudo_last,
         email         = NULL,
         phone_number  = NULL,
         address       = '{}'::jsonb,
         date_of_birth = NULL,
         gender        = NULL,
         is_active     = false,
         deactivated_at= COALESCE(deactivated_at, now()),
         updated_at    = now()
   WHERE user_id = p_user_id;

  -- 3. appointments — scrub the denormalized patient snapshot, keep doctor & timing
  UPDATE public.appointments
     SET patient_name = v_pseudo_first,
         account_name = v_pseudo_first,
         user_age     = NULL,
         user_gender  = NULL
   WHERE user_id = p_user_id;

  -- 4. conversations — scrub the denormalized patient name
  UPDATE public.conversations
     SET patient_name        = v_pseudo_first,
         account_holder_name = v_pseudo_first,
         updated_at          = now()
   WHERE patient_id = p_user_id;

  -- 5. user_devices — purge push tokens (no point retaining them)
  DELETE FROM public.user_devices WHERE user_id = p_user_id;

  -- 6. analytics_events — break the user_id link (anonymous_id remains as-is)
  UPDATE public.analytics_events
     SET user_id = NULL
   WHERE user_id = p_user_id;

  -- 7. analytics_sessions — break the user_id link
  UPDATE public.analytics_sessions
     SET user_id = NULL
   WHERE user_id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_pseudonymize_user(uuid) FROM PUBLIC;
-- service_role only (cron / supabase_admin run this)

-- ---------------------------------------------------------------------------
-- 4. Operator-callable: hard-purge one user (called by 7-year cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_hard_purge_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Cascading deletes are configured per-table; here we cover what isn't.
  DELETE FROM public.relatives             WHERE user_id = p_user_id;
  DELETE FROM public.patient_health_profile WHERE user_id = p_user_id;
  DELETE FROM public.patient_medical_records WHERE user_id = p_user_id;
  DELETE FROM public.documents             WHERE user_id = p_user_id;
  DELETE FROM public.notes                 WHERE user_id = p_user_id;
  DELETE FROM public.points_history        WHERE user_id = p_user_id;
  DELETE FROM public.vouchers              WHERE user_id = p_user_id;
  DELETE FROM public.referrals             WHERE referrer_id = p_user_id OR referred_id = p_user_id;
  DELETE FROM public.appointments          WHERE user_id = p_user_id;
  DELETE FROM public.messages              WHERE sender_id = p_user_id OR conversation_id IN
    (SELECT id FROM public.conversations WHERE patient_id = p_user_id);
  DELETE FROM public.conversations         WHERE patient_id = p_user_id;

  -- Finally remove the auth.users row (the public.users row will cascade if FK is set,
  -- otherwise delete it explicitly).
  DELETE FROM public.users WHERE id = p_user_id;
  DELETE FROM auth.users   WHERE id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_hard_purge_user(uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 5. Operator-callable: process all users due for tier-3 / tier-4
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_process_account_deletions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user record;
  v_pseudonymized int := 0;
  v_purged int := 0;
BEGIN
  -- Tier 3: pseudonymize users whose 30-day window expired and not yet processed
  FOR v_user IN
    SELECT id FROM public.users
     WHERE deletion_requested_at IS NOT NULL
       AND deletion_pseudonymized_at IS NULL
       AND (deletion_cancellable_until IS NULL OR deletion_cancellable_until < now())
  LOOP
    PERFORM public.fn_pseudonymize_user(v_user.id);
    v_pseudonymized := v_pseudonymized + 1;
  END LOOP;

  -- Tier 4: hard-purge users pseudonymized 7+ years ago
  FOR v_user IN
    SELECT id FROM public.users
     WHERE deletion_pseudonymized_at IS NOT NULL
       AND deletion_pseudonymized_at < now() - interval '7 years'
  LOOP
    PERFORM public.fn_hard_purge_user(v_user.id);
    v_purged := v_purged + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'pseudonymized', v_pseudonymized,
    'purged', v_purged,
    'run_at', now()
  );
END $$;

REVOKE ALL ON FUNCTION public.fn_process_account_deletions() FROM PUBLIC;

COMMIT;
