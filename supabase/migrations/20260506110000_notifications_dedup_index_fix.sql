-- Fix: drop the partial unique index that broke ON CONFLICT in the edge
-- function. Postgres won't accept a partial index (WHERE predicate) as a
-- conflict target unless the predicate is restated in the ON CONFLICT
-- clause — which the Supabase JS client's .upsert() doesn't support.
--
-- Replace it with a non-partial unique index. NULL semantics are
-- equivalent: PG already lets multiple rows with NULL in the index
-- columns coexist because NULL = NULL is NULL (not TRUE), so the unique
-- check never fires for NULL dedup_key rows. End behavior is identical
-- to the partial index, but ON CONFLICT works.
--
-- Symptom this fixes: edge function logs every push attempt with
--   "there is no unique or exclusion constraint matching the ON CONFLICT
--    specification" (code 42P10),
-- which made persistNotifications return 0 rows, which (correctly) made
-- the dispatcher skip Pushy fanout — so neither inbox rows nor pushes
-- were delivered.

BEGIN;

DROP INDEX IF EXISTS public.notifications_dedup_uniq;

CREATE UNIQUE INDEX notifications_dedup_uniq
  ON public.notifications (user_id, event_code, dedup_key);

COMMIT;

-- Verify after applying:
--   \d public.notifications     -- should show the non-partial index
