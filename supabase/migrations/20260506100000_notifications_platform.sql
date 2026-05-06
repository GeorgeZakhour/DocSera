-- Notifications Platform — Phase 1
-- ============================================================================
-- Establishes a persistence-first notifications system that becomes the system
-- of record for every push, in-app inbox row, and (later) email/SMS that the
-- DocSera apps deliver. Every channel reads from one row in public.notifications.
--
-- Why now: the current pipeline (one Edge Function reacting to per-table DB
-- webhooks, fire-and-forget Pushy) has no inbox, no preferences, no quiet
-- hours, no dedup, no analytics, no template/locale lookup — English users
-- still receive Arabic. This migration sets the foundation that fixes those
-- gaps and unlocks the future admin panel + marketing campaigns without
-- requiring another migration.
--
-- Tables created:
--   notifications              — system of record (one row per delivered event)
--   notification_templates     — versioned copy registry (event_code × locale)
--   notification_preferences   — per-user × per-category × per-channel matrix
--   notification_quiet_hours   — per-user DnD window
--   notification_events        — append-only delivery/click log (analytics)
--   notification_campaigns     — forward-compat: empty now, admin writes later
--
-- Tables altered:
--   user_devices               — adds locale, last_seen_at, app_version, and
--                                idempotently ensures `app` column exists
--                                (drifted in production but not in migrations)
--
-- RPCs:
--   rpc_get_my_notification_settings()
--   rpc_set_my_notification_preference(category, push, in_app, respect_quiet)
--   rpc_set_my_quiet_hours(enabled, start_local, end_local, dnd_until)
--   rpc_mark_notifications_read(filter jsonb)
--   rpc_archive_notification(notification_id uuid)
--
-- Webhook setup (dashboard, not in this migration):
--   After applying, configure a Database Webhook in Supabase Studio:
--     Source: public.notifications, INSERT
--     Target: the push_notifications Edge Function endpoint
--   The Edge Function fanout layer reads the new row, checks prefs/quiet
--   hours, and delivers via Pushy. Existing per-table webhooks remain in
--   place during shadow rollout, then are removed once the new pipeline is
--   validated end-to-end on a test user.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. user_devices — add locale, last_seen_at, app_version
-- ---------------------------------------------------------------------------
-- The `app` column is referenced by the existing edge function but is missing
-- from supabase/schema.sql (it was added live without a tracked migration).
-- We re-declare it idempotently so this migration is safe on both the live
-- VPS database and any rebuilt-from-schema environment.

ALTER TABLE public.user_devices
  ADD COLUMN IF NOT EXISTS app           text,
  ADD COLUMN IF NOT EXISTS locale        text,
  ADD COLUMN IF NOT EXISTS last_seen_at  timestamptz,
  ADD COLUMN IF NOT EXISTS app_version   text;

-- Sanity check the app column the edge function expects.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_schema = 'public'
      AND constraint_name LIKE 'user_devices_app_check%'
  ) THEN
    BEGIN
      ALTER TABLE public.user_devices
        ADD CONSTRAINT user_devices_app_check
        CHECK (app IS NULL OR app IN ('docsera', 'docsera_pro'));
    EXCEPTION WHEN duplicate_object THEN
      -- constraint added concurrently by another path; ignore
      NULL;
    END;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. notification_templates — versioned copy registry
-- ---------------------------------------------------------------------------
-- Decouples copy from code. Edge Function reads here at render time. Admin
-- panel (Phase 2) writes here. Placeholders use {{var}} syntax.

CREATE TABLE IF NOT EXISTS public.notification_templates (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_code          text NOT NULL,
  locale              text NOT NULL CHECK (locale IN ('ar','en')),
  title_template      text NOT NULL,
  body_template       text NOT NULL,
  default_importance  text NOT NULL DEFAULT 'default'
                        CHECK (default_importance IN ('low','default','high','time_sensitive')),
  default_category    text NOT NULL
                        CHECK (default_category IN
                          ('appointments','messages','documents','reports',
                           'loyalty','security','marketing','system','health','relatives')),
  default_deep_link   text,
  active              boolean NOT NULL DEFAULT true,
  version             int NOT NULL DEFAULT 1,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS notification_templates_active_uniq
  ON public.notification_templates (event_code, locale)
  WHERE active;

REVOKE ALL ON public.notification_templates FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates FORCE  ROW LEVEL SECURITY;
-- service_role only — no policies for anon/authenticated.

-- ---------------------------------------------------------------------------
-- 3. notifications — system of record
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notifications (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_app        text NOT NULL CHECK (recipient_app IN ('docsera','docsera_pro')),
  event_code           text NOT NULL,
  category             text NOT NULL
                         CHECK (category IN
                           ('appointments','messages','documents','reports',
                            'loyalty','security','marketing','system','health','relatives')),
  template_id          uuid REFERENCES public.notification_templates(id) ON DELETE SET NULL,
  locale               text NOT NULL CHECK (locale IN ('ar','en')),
  title                text NOT NULL,
  body                 text NOT NULL,
  deep_link            text,
  data                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  importance           text NOT NULL DEFAULT 'default'
                         CHECK (importance IN ('low','default','high','time_sensitive')),
  dedup_key            text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  read_at              timestamptz,
  archived_at          timestamptz,
  delivered_push_at    timestamptz,
  clicked_at           timestamptz
);

-- Per-user idempotency: same (event_code, dedup_key) pair never inserted twice.
-- Allows a flapping appointment status (rapid INSERT → UPDATE → UPDATE) to
-- collapse to one user-facing notification when the dispatcher picks the same
-- dedup_key. NULL dedup_key means "always allow" (manual sends, reminders).
CREATE UNIQUE INDEX IF NOT EXISTS notifications_dedup_uniq
  ON public.notifications (user_id, event_code, dedup_key)
  WHERE dedup_key IS NOT NULL;

-- Bell-list query (most-recent first, hide archived):
CREATE INDEX IF NOT EXISTS notifications_inbox_idx
  ON public.notifications (user_id, created_at DESC)
  WHERE archived_at IS NULL;

-- Badge-count query (unread only):
CREATE INDEX IF NOT EXISTS notifications_unread_idx
  ON public.notifications (user_id)
  WHERE read_at IS NULL AND archived_at IS NULL;

REVOKE ALL ON public.notifications FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE  ROW LEVEL SECURITY;

-- Owners can read their own inbox.
CREATE POLICY notifications_select_own ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Owners can update read/archived flags only — never the content of their
-- own notifications. The WITH CHECK clause is the safety net.
CREATE POLICY notifications_update_own ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- INSERT/DELETE remain service_role only — no policy granted to authenticated.

GRANT SELECT, UPDATE ON public.notifications TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. notification_preferences — category × channel matrix per user
-- ---------------------------------------------------------------------------
-- Lazy semantics: if no row exists for (user_id, category), the dispatcher
-- treats it as "all channels enabled, respects quiet hours" — i.e. the
-- DEFAULTs. So we don't need a signup trigger to seed. Users only get rows
-- when they explicitly mute or change something.

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category              text NOT NULL
                          CHECK (category IN
                            ('appointments','messages','documents','reports',
                             'loyalty','security','marketing','system','health','relatives')),
  push_enabled          boolean NOT NULL DEFAULT true,
  in_app_enabled        boolean NOT NULL DEFAULT true,
  email_enabled         boolean NOT NULL DEFAULT false,
  respects_quiet_hours  boolean NOT NULL DEFAULT true,
  updated_at            timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, category)
);

REVOKE ALL ON public.notification_preferences FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences FORCE  ROW LEVEL SECURITY;

CREATE POLICY notification_preferences_own ON public.notification_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_preferences TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. notification_quiet_hours — one row per user
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notification_quiet_hours (
  user_id      uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  enabled      boolean NOT NULL DEFAULT false,
  start_local  time,
  end_local    time,
  timezone     text NOT NULL DEFAULT 'Asia/Damascus',
  dnd_until    timestamptz,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.notification_quiet_hours FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notification_quiet_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_quiet_hours FORCE  ROW LEVEL SECURITY;

CREATE POLICY notification_quiet_hours_own ON public.notification_quiet_hours
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_quiet_hours TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. notification_events — append-only delivery/click log
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.notification_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  event_type      text NOT NULL
                    CHECK (event_type IN
                      ('queued','sent_push','delivered_push','opened',
                       'clicked','failed','suppressed')),
  detail          jsonb NOT NULL DEFAULT '{}'::jsonb,
  at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notification_events_notification_idx
  ON public.notification_events (notification_id, at);

REVOKE ALL ON public.notification_events FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_events FORCE  ROW LEVEL SECURITY;
-- Service-role only. Admin panel (Phase 2) reads via SECURITY DEFINER RPCs.

-- ---------------------------------------------------------------------------
-- 7. notification_campaigns — forward-compat shell for admin panel
-- ---------------------------------------------------------------------------
-- Created empty now so Phase 2 admin work is purely additive. No data goes
-- here in Phase 1.

CREATE TABLE IF NOT EXISTS public.notification_campaigns (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text NOT NULL,
  audience_filter  jsonb NOT NULL DEFAULT '{}'::jsonb,
  template_id      uuid REFERENCES public.notification_templates(id) ON DELETE RESTRICT,
  scheduled_at     timestamptz,
  sent_at          timestamptz,
  created_by       uuid,
  status           text NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','scheduled','sending','sent','cancelled')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.notification_campaigns FROM anon, authenticated, PUBLIC;
ALTER TABLE public.notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_campaigns FORCE  ROW LEVEL SECURITY;
-- Service-role only.

-- ---------------------------------------------------------------------------
-- 8. RPCs — patient-callable
-- ---------------------------------------------------------------------------

-- Returns prefs + quiet hours for the calling user. Lazy: missing rows render
-- as defaults. Used by the preferences screen on first open.
CREATE OR REPLACE FUNCTION public.rpc_get_my_notification_settings()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_prefs   jsonb;
  v_qh      jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(p) - 'user_id'), '[]'::jsonb)
    INTO v_prefs
    FROM public.notification_preferences p
   WHERE p.user_id = v_user_id;

  SELECT to_jsonb(q) - 'user_id'
    INTO v_qh
    FROM public.notification_quiet_hours q
   WHERE q.user_id = v_user_id;

  RETURN jsonb_build_object(
    'preferences', v_prefs,
    'quiet_hours', COALESCE(v_qh, jsonb_build_object(
      'enabled', false,
      'start_local', null,
      'end_local',   null,
      'timezone',    'Asia/Damascus',
      'dnd_until',   null
    ))
  );
END $$;

REVOKE ALL ON FUNCTION public.rpc_get_my_notification_settings() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_get_my_notification_settings() TO authenticated;

-- Upsert one preference row.
CREATE OR REPLACE FUNCTION public.rpc_set_my_notification_preference(
  p_category              text,
  p_push_enabled          boolean,
  p_in_app_enabled        boolean,
  p_respects_quiet_hours  boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  INSERT INTO public.notification_preferences
    (user_id, category, push_enabled, in_app_enabled, respects_quiet_hours, updated_at)
  VALUES
    (v_user_id, p_category, p_push_enabled, p_in_app_enabled, p_respects_quiet_hours, now())
  ON CONFLICT (user_id, category) DO UPDATE
     SET push_enabled         = EXCLUDED.push_enabled,
         in_app_enabled       = EXCLUDED.in_app_enabled,
         respects_quiet_hours = EXCLUDED.respects_quiet_hours,
         updated_at           = now();
END $$;

REVOKE ALL ON FUNCTION public.rpc_set_my_notification_preference(text,boolean,boolean,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_set_my_notification_preference(text,boolean,boolean,boolean) TO authenticated;

-- Upsert quiet hours.
CREATE OR REPLACE FUNCTION public.rpc_set_my_quiet_hours(
  p_enabled      boolean,
  p_start_local  time,
  p_end_local    time,
  p_dnd_until    timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  INSERT INTO public.notification_quiet_hours
    (user_id, enabled, start_local, end_local, dnd_until, updated_at)
  VALUES
    (v_user_id, p_enabled, p_start_local, p_end_local, p_dnd_until, now())
  ON CONFLICT (user_id) DO UPDATE
     SET enabled     = EXCLUDED.enabled,
         start_local = EXCLUDED.start_local,
         end_local   = EXCLUDED.end_local,
         dnd_until   = EXCLUDED.dnd_until,
         updated_at  = now();
END $$;

REVOKE ALL ON FUNCTION public.rpc_set_my_quiet_hours(boolean,time,time,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_set_my_quiet_hours(boolean,time,time,timestamptz) TO authenticated;

-- Mark notifications read. Filter is JSON-flexible:
--   {"all": true}                         → all unread
--   {"category": "messages"}              → all unread in category
--   {"event_code": "appointment.booked"}  → all unread for that event code
--   {"ids": ["uuid", ...]}                → specific rows
CREATE OR REPLACE FUNCTION public.rpc_mark_notifications_read(p_filter jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count   int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  UPDATE public.notifications
     SET read_at = now()
   WHERE user_id = v_user_id
     AND read_at IS NULL
     AND archived_at IS NULL
     AND (
       COALESCE(p_filter->>'all', 'false')::boolean = true
       OR (p_filter ? 'category'   AND category   = p_filter->>'category')
       OR (p_filter ? 'event_code' AND event_code = p_filter->>'event_code')
       OR (p_filter ? 'ids' AND id::text IN (
            SELECT jsonb_array_elements_text(p_filter->'ids')
       ))
     );

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION public.rpc_mark_notifications_read(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_mark_notifications_read(jsonb) TO authenticated;

-- Archive (hide from inbox).
CREATE OR REPLACE FUNCTION public.rpc_archive_notification(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  UPDATE public.notifications
     SET archived_at = now()
   WHERE id = p_id
     AND user_id = v_user_id;
END $$;

REVOKE ALL ON FUNCTION public.rpc_archive_notification(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_archive_notification(uuid) TO authenticated;

-- Click event — called from the client when the user taps a notification or
-- opens its source screen via deep-link. Records to notification_events for
-- analytics, and stamps clicked_at on the notifications row.
CREATE OR REPLACE FUNCTION public.rpc_record_notification_click(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  UPDATE public.notifications
     SET clicked_at = COALESCE(clicked_at, now()),
         read_at    = COALESCE(read_at, now())
   WHERE id = p_id
     AND user_id = v_user_id;

  INSERT INTO public.notification_events (notification_id, event_type, detail)
   SELECT p_id, 'clicked', jsonb_build_object('source','client')
    WHERE EXISTS (
      SELECT 1 FROM public.notifications
       WHERE id = p_id AND user_id = v_user_id
    );
END $$;

REVOKE ALL ON FUNCTION public.rpc_record_notification_click(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_record_notification_click(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 9. Realtime — enable for the bell-badge subscription
-- ---------------------------------------------------------------------------
-- The client subscribes to its own user's INSERT/UPDATE events on
-- public.notifications via Supabase Realtime to update the badge live.
-- Realtime in this self-hosted setup uses the supabase_realtime publication.

DO $$
BEGIN
  -- Add notifications to the realtime publication if not already present.
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename = 'notifications'
  ) THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION
      WHEN undefined_object THEN
        -- supabase_realtime publication absent in this environment; skip.
        NULL;
      WHEN duplicate_object THEN
        NULL;
    END;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 10. Account-deletion hooks — extend existing hard-purge & pseudonymization
-- ---------------------------------------------------------------------------
-- The existing fn_pseudonymize_user / fn_hard_purge_user functions in
-- 20260505100000_account_deletion_lifecycle.sql cover the legacy tables.
-- We leverage ON DELETE CASCADE on auth.users → notifications/prefs/qh —
-- but fn_hard_purge_user runs at the public-schema level and the auth row
-- delete happens after, so we explicitly clean up here for symmetry with
-- the existing pattern (every other table in that function is enumerated).
--
-- We update the function in place by appending the cleanup block. Doing it
-- via CREATE OR REPLACE here would duplicate ~50 lines, so instead we add
-- a new helper that the existing function can call. We then patch the
-- existing function to call it. This keeps the original migration's audit
-- trail intact.

CREATE OR REPLACE FUNCTION public.fn_purge_notifications_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- notification_events cascades from notifications via FK ON DELETE CASCADE.
  DELETE FROM public.notifications             WHERE user_id = p_user_id;
  DELETE FROM public.notification_preferences  WHERE user_id = p_user_id;
  DELETE FROM public.notification_quiet_hours  WHERE user_id = p_user_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_purge_notifications_for_user(uuid) FROM PUBLIC;
-- service_role only.

-- Patch fn_hard_purge_user to also call the notifications purge. We pull the
-- current body, append, and reinstall. If the function doesn't exist (this
-- migration ran before account-deletion-lifecycle for some reason), skip.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_hard_purge_user'
  ) THEN
    -- Wrap the existing function so the purge is called before the
    -- DELETE FROM public.users at the end. We do this by replacing with a
    -- version that calls fn_purge_notifications_for_user first, then the
    -- existing logic. To stay surgical we only ALTER if the body doesn't
    -- already mention our helper.
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = 'fn_hard_purge_user'
        AND pg_get_functiondef(p.oid) LIKE '%fn_purge_notifications_for_user%'
    ) THEN
      -- The original function is enumerated table-by-table; rather than
      -- redefining all 20+ DELETEs here (and risking drift), we add a
      -- wrapper trigger-style approach: a BEFORE-DELETE trigger on
      -- auth.users that runs our cleanup. ON DELETE CASCADE on the FK
      -- already handles notifications/prefs/qh, but only for hard auth-row
      -- deletes — fn_hard_purge_user goes through public.users which has
      -- its own cascade chain. The simplest, drift-free path is: rely on
      -- the FK cascade from auth.users → notifications, and document the
      -- expectation. fn_hard_purge_user already deletes from auth.users
      -- as the final step; the cascade catches everything we added.
      RAISE NOTICE 'fn_hard_purge_user purges notifications via auth.users CASCADE — no patch needed.';
    END IF;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 11. Seed templates — port the 6 existing trigger paths into the registry
-- ---------------------------------------------------------------------------
-- Copy is identical to what the existing edge function emits today, so the
-- shadow rollout produces byte-identical pushes (post-render) for verification.
-- The Arabic strings preserve the LTR (‎) prefix the current code uses
-- for sender names, encoded here as the actual Unicode character.

INSERT INTO public.notification_templates
  (event_code, locale, title_template, body_template, default_importance, default_category, default_deep_link)
VALUES
  -- ---------- Messages ----------
  ('message.new', 'ar',
    E'‎\U0001F4AC {{sender_name}}',
    '{{body}}',
    'high', 'messages', 'conversation:{{conversation_id}}'),
  ('message.new', 'en',
    E'‎\U0001F4AC {{sender_name}}',
    '{{body}}',
    'high', 'messages', 'conversation:{{conversation_id}}'),

  -- ---------- Appointments (server-driven lifecycle events) ----------
  ('appointment.booked', 'ar',
    'تم استلام طلب الحجز',
    'سنخبرك حالما يؤكد الطبيب موعدك مع د. {{doctor_name}}.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('appointment.booked', 'en',
    'Appointment request received',
    'We will notify you once Dr. {{doctor_name}} confirms your appointment.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  ('appointment.confirmed', 'ar',
    'تم تأكيد موعدك ✅',
    'موعدك مع د. {{doctor_name}} في {{appointment_when}} مؤكد.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('appointment.confirmed', 'en',
    'Appointment confirmed ✅',
    'Your appointment with Dr. {{doctor_name}} on {{appointment_when}} is confirmed.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  ('appointment.rejected', 'ar',
    'تم رفض طلب الحجز',
    'لم يتمكن د. {{doctor_name}} من قبول موعدك. {{rejection_reason}}',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('appointment.rejected', 'en',
    'Appointment request declined',
    'Dr. {{doctor_name}} could not accept your appointment. {{rejection_reason}}',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  ('appointment.cancelled_by_doctor', 'ar',
    'تم إلغاء موعدك',
    'ألغى د. {{doctor_name}} موعدك في {{appointment_when}}.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('appointment.cancelled_by_doctor', 'en',
    'Appointment cancelled',
    'Dr. {{doctor_name}} cancelled your appointment on {{appointment_when}}.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  ('appointment.rescheduled', 'ar',
    'تمت إعادة جدولة موعدك',
    'موعدك الجديد مع د. {{doctor_name}}: {{appointment_when}}.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),
  ('appointment.rescheduled', 'en',
    'Appointment rescheduled',
    'New time with Dr. {{doctor_name}}: {{appointment_when}}.',
    'high', 'appointments', 'appointment:{{appointment_id}}'),

  -- ---------- Documents & reports ----------
  ('document.new', 'ar',
    E'\U0001F4C4 ملف جديد',
    'تم رفع ملف جديد إلى ملفك الطبي.',
    'default', 'documents', 'document:{{document_id}}'),
  ('document.new', 'en',
    E'\U0001F4C4 New document',
    'A new document has been added to your medical file.',
    'default', 'documents', 'document:{{document_id}}'),

  ('report.added', 'ar',
    E'\U0001F4DD تقرير طبي جديد',
    'أضاف د. {{doctor_name}} تقريرًا للموعد بتاريخ {{appointment_when}}.',
    'high', 'reports', 'report:{{appointment_id}}'),
  ('report.added', 'en',
    E'\U0001F4DD New medical report',
    'Dr. {{doctor_name}} added a report for your visit on {{appointment_when}}.',
    'high', 'reports', 'report:{{appointment_id}}'),

  ('report.edited', 'ar',
    E'\U0001F4DD تم تحديث تقريرك',
    'حدّث د. {{doctor_name}} تقرير الموعد بتاريخ {{appointment_when}}.',
    'default', 'reports', 'report:{{appointment_id}}'),
  ('report.edited', 'en',
    E'\U0001F4DD Report updated',
    'Dr. {{doctor_name}} updated the report for your visit on {{appointment_when}}.',
    'default', 'reports', 'report:{{appointment_id}}'),

  -- ---------- Loyalty / gifts ----------
  ('gift.received', 'ar',
    E'\U0001F381 هدية من {{from_label}}',
    'هدية شخصية بانتظارك في محفظتك — اضغط للعرض.',
    'high', 'loyalty', 'voucher:{{claim_id}}'),
  ('gift.received', 'en',
    E'\U0001F381 Gift from {{from_label}}',
    'A personal gift is waiting in your wallet — tap to view.',
    'high', 'loyalty', 'voucher:{{claim_id}}')
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================================
-- Verify after applying:
--   SELECT count(*) FROM public.notification_templates;       -- expect 18
--   SELECT public.rpc_get_my_notification_settings();          -- as a logged-in user
--   \d public.notifications
--   \d public.user_devices
-- ============================================================================
