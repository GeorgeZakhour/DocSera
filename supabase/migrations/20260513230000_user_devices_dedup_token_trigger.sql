-- Fix cross-account push leak: when User A logs out on a device but
-- their user_devices row survives (deleteToken short-circuited because
-- _pushyDeviceToken was null, OR signOut was invoked via one of the
-- direct supabase.auth.signOut() callsites that bypass AuthCubit),
-- User B's subsequent login on the same physical device leaves BOTH
-- rows in user_devices pointing at the same Pushy token. The push
-- fanout (functions/push_notifications/fanout.ts) queries by user_id,
-- finds A's row, and delivers A's notifications to B's device.
--
-- The May-10 client-side orphan-defense (a72b331) attempted to fix
-- this by deleting other-user rows for the same token during B's
-- upsert, but RLS scopes write authority to user_id = auth.uid() —
-- so the cross-account delete is a no-op.
--
-- This migration adds a SECURITY DEFINER AFTER INSERT trigger that
-- runs as the table owner and atomically removes any other
-- user_devices row sharing this (token, app) but a different user.
-- A new INSERT for B implicitly evicts the stale A row. Pushy tokens
-- are per-install, so this only fires for the legitimate same-device
-- collision — it does NOT touch rows for the same user on other
-- devices (different tokens) or for other users on other devices
-- (different tokens).
--
-- Interaction audit:
--   * No existing AFTER INSERT trigger on user_devices: the old
--     trg_notify_new_device_login was dropped in
--     20260510000000_new_device_login_after_trust.sql and re-routed
--     to a users-table UPDATE trigger.
--   * user_devices is in supabase_realtime publication with
--     REPLICA IDENTITY FULL (20260510060000), so the DELETE event
--     reaches subscribers. Force-logout watchers filter by user_id +
--     compare deletedToken to their cached Pushy token; A's evicted
--     row only matches if A is currently logged in on a device with
--     this exact token, which by definition means they are still on
--     this same physical install — a legitimate force-logout. Other
--     devices A is signed into use different tokens and ignore the
--     event.
--   * device_fingerprint unique index (20260512040000) is on
--     (user_id, app, device_fingerprint). Different user_id = no
--     index collision; INSERT succeeds, then the trigger cleans up.
--   * 90-day prune cron (20260510010000) remains useful for true
--     orphans (failed sessions, dropped writes). Belt-and-braces.
--   * RLS: trigger runs as owner, bypasses RLS for the cleanup.
--     Caller still needs RLS-bound write authority to INSERT their
--     own row — they cannot evict someone else's row without first
--     proving ownership of the inserting (user_id, token) pair.
--
-- Both DocSera (patient) and DocSera-Pro share this table, so this
-- single fix resolves the bug for both apps.

CREATE OR REPLACE FUNCTION public.fn_user_devices_dedup_token()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Evict any other user_devices row for the same physical install
  -- (same Pushy token + same app) belonging to a different user.
  -- IS DISTINCT FROM treats NULL user_id as a real value, so a
  -- legacy NULL-user_id orphan is also collapsed when a fresh
  -- signed-in row lands for the same token.
  DELETE FROM public.user_devices
   WHERE token = NEW.token
     AND app   = NEW.app
     AND user_id IS DISTINCT FROM NEW.user_id;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_user_devices_dedup_token() IS
  'AFTER INSERT trigger fn: evicts any user_devices row sharing the '
  'new row''s (token, app) but a different user_id. Runs as owner to '
  'bypass RLS — caller still must have RLS write authority to insert '
  'their own row. Fixes the cross-account push leak when a logged-out '
  'user''s device row survives and the next user signs in on the same '
  'physical install.';

DROP TRIGGER IF EXISTS trg_user_devices_dedup_token ON public.user_devices;

CREATE TRIGGER trg_user_devices_dedup_token
  AFTER INSERT ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_user_devices_dedup_token();

-- One-shot sweep of existing orphans. The trigger only fires for
-- future INSERTs; rows that survived a prior cross-account collision
-- would otherwise linger until the 90-day prune. For each (token, app)
-- pair shared by multiple user_ids, keep only the most recently
-- last_seen_at row (or, if last_seen_at is NULL on both, the most
-- recently created). This collapses the duplicate-token state that
-- pre-dates this migration.
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY token, app
           ORDER BY last_seen_at DESC NULLS LAST,
                    created_at  DESC NULLS LAST
         ) AS rn
    FROM public.user_devices
)
DELETE FROM public.user_devices ud
 USING ranked
 WHERE ud.id = ranked.id
   AND ranked.rn > 1;
