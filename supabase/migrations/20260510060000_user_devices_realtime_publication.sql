-- The instant force-logout flow (rpc_clear_trusted_devices_except_current
-- DELETEs other user_devices rows; affected devices' Supabase realtime
-- listener fires and signs out) was silently broken in two ways:
--
-- 1. user_devices was not in the supabase_realtime publication, so
--    Postgres logical replication never emitted any events for it.
--    Realtime subscribers received nothing, ever.
-- 2. REPLICA IDENTITY was DEFAULT (primary key only). Even once the
--    publication was fixed, DELETE events would only include the row
--    id — not the token field the client uses to match "is this my
--    row?".
--
-- Fix both at once. After this migration:
--   * Inserts/updates/deletes on public.user_devices reach realtime.
--   * DELETE old_record contains the full row, so the patient app's
--     NotificationService can compare oldRow['token'] to its cached
--     Pushy token and sign out instantly when its row is deleted.

-- 1) Make sure the row image carries enough columns for DELETE old_record.
ALTER TABLE public.user_devices REPLICA IDENTITY FULL;

-- 2) Add to the realtime publication if missing. Wrapped because
--    re-adding raises in some PG versions.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'user_devices'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.user_devices';
  END IF;
END $$;
