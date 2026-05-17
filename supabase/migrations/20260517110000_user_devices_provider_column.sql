-- Smart routing for push notifications: each device registers with one provider.
--
-- Before: user_devices stored Pushy tokens implicitly. Fanout chose provider
-- via the global USE_FCM env var.
--
-- After: each row carries which provider issued the token. Fanout routes
-- per-device based on this column:
--   provider='pushy' → token sent to api.pushy.me
--   provider='fcm'   → token sent to fcm.googleapis.com
--
-- All existing rows default to 'pushy' (which is what they currently are
-- — every existing token was issued by Pushy). The default ensures
-- backward compatibility: if any code path inserts a row without
-- specifying provider, it lands as a Pushy registration. Apps must be
-- updated (in Stage 3 client work) to send the provider field explicitly.
--
-- Why no index on provider: the column has cardinality 2 (pushy/fcm),
-- which is too low for a useful btree index. Fanout already queries by
-- (user_id, app) which have proper indexes; provider filtering happens
-- in-memory on the small per-user result set. Adding an index here
-- would only help analytics queries like "count(*) by provider", which
-- can do a sequential scan happily for table sizes <100k rows.

ALTER TABLE public.user_devices
  ADD COLUMN provider text NOT NULL DEFAULT 'pushy'
  CHECK (provider IN ('pushy', 'fcm'));

COMMENT ON COLUMN public.user_devices.provider IS
  'Push provider that issued this token. Routes fanout: pushy → api.pushy.me, fcm → fcm.googleapis.com. Set by client during device registration.';
