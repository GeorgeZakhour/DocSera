-- Fix: add the missing DELETE RLS policy on user_devices.
--
-- Discovery: the table has INSERT/SELECT/UPDATE policies (all
-- "uid() = user_id"-scoped) but NO DELETE policy. PostgreSQL RLS
-- denies any operation that doesn't have a matching policy, so every
-- DELETE from an authenticated client silently fails (PostgREST
-- returns 200 OK with empty body — no error raised). This has been
-- a latent bug since the table was created; it only surfaced now
-- because the Stage 3 FCM migration started generating new tokens
-- (different from the existing Pushy tokens), which exposed the
-- broken cleanup paths:
--
--   1. NotificationService._saveDeviceTokenToSupabase()'s orphan-defense
--      delete (drops rows belonging to other users that share THIS
--      token after a previous user signed out without cleanup)
--
--   2. NotificationService._saveDeviceTokenToSupabase()'s same-device
--      dedup (drops the stale Pushy row when a device upgrades to FCM,
--      using device_fingerprint to identify "this physical device")
--
--   3. NotificationService.deleteToken() (called from sign-out flows
--      to drop THIS device's row)
--
-- Without the DELETE policy, all three quietly returned without
-- actually deleting anything. The 90-day prune cron (which runs as a
-- service-role function and bypasses RLS) was masking the impact —
-- stale rows eventually got cleaned, but only after up to 90 days
-- of lingering Pushy slots consumed for no reason.
--
-- The fingerprint-collision symptom (Stage 3 Gate 4b.3 on real iPhone):
--   1. NEW Pro app installs over the OLD one
--   2. Cleanup tries to delete the stale iOS Pushy row → silently no-op
--   3. Upsert tries to insert the new FCM row with the same
--      (user_id, app, device_fingerprint) → violates the partial
--      unique index idx_user_devices_user_app_fingerprint
--   4. Whole upsert errors out → device ends up with NO row in
--      user_devices → no notifications until next migration cycle
--
-- The fix is one CREATE POLICY. Pattern matches the existing INSERT/
-- SELECT/UPDATE policies for consistency (uid() = user_id scope).
-- Affects both apps (patient + pro) since they share this table.

CREATE POLICY "Users can delete their own devices"
  ON public.user_devices
  FOR DELETE
  USING (uid() = user_id);

COMMENT ON POLICY "Users can delete their own devices" ON public.user_devices IS
  'Lets an authenticated user delete their own user_devices rows. '
  'Required by the NotificationService cleanup paths (orphan defense, '
  'same-device dedup, deleteToken). Added 2026-05-18 after the FCM '
  'migration surfaced that the table had no DELETE policy and all '
  'client-side cleanup was silently failing.';
