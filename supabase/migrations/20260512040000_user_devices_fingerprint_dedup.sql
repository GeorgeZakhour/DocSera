-- Reinstalling a mobile app generates a brand-new Pushy token. iOS
-- ignores the old APNs subscription, but our user_devices row for
-- the old token lingers (the orphan-defense only catches cross-user
-- collisions on the same token, not same-user-fresh-install). The
-- 90-day prune cron eventually sweeps it, but in the meantime the
-- fanout sends pushes to BOTH the stale and fresh tokens — and on
-- iOS the stale token can still route to the device for a brief
-- window after reinstall, producing a duplicate notification.
--
-- Fix: identify rows by the physical device's stable fingerprint, not
-- by the per-install Pushy token. Reinstalls then UPDATE the existing
-- row's token instead of inserting a new one. Stale rows can't exist
-- because every (user_id, app, device_fingerprint) tuple maps to at
-- most one row.
--
-- Device fingerprint source (set by the client):
--   iOS:     UIDevice.current.identifierForVendor.uuidString
--            — stable across reinstalls for the same vendor/team
--   Android: Settings.Secure.ANDROID_ID
--            — stable until factory reset
--
-- Both are already in use in the trusted_devices flow, so the same
-- value flows through here naturally.

ALTER TABLE public.user_devices
  ADD COLUMN IF NOT EXISTS device_fingerprint text;

-- Partial unique index — only enforces uniqueness when fingerprint is
-- present. Legacy rows with NULL fingerprint coexist until pruned.
-- New installs will set fingerprint and dedup against each other.
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_user_app_fingerprint
  ON public.user_devices (user_id, app, device_fingerprint)
  WHERE device_fingerprint IS NOT NULL;

COMMENT ON COLUMN public.user_devices.device_fingerprint IS
  'Stable per-device identifier (iOS identifierForVendor, Android '
  'Settings.Secure.ANDROID_ID). Used to dedup user_devices rows '
  'across app reinstalls — the same physical device upserts a '
  'single row, updating its Pushy token in place rather than '
  'leaving stale rows behind.';
