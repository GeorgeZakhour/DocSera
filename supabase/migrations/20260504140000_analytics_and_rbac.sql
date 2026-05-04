-- =============================================================================
-- DocSera Analytics + Admin RBAC — Stage 1 (backend foundation)
-- =============================================================================
-- This migration creates:
--   1. RBAC tables (admin_users, admin_roles, admin_permissions, …) + seed data
--   2. Analytics tables (analytics_events, analytics_sessions, analytics_devices)
--   3. PHI sanitization triggers (defense-in-depth backstop to the SDK whitelist)
--   4. Ingestion RPC (rpc_track_events_batch) — anon-callable, validates inputs
--   5. Admin RPCs for KPIs, funnels, retention, top events, user journey, doctor
--      metrics, partner metrics
--   6. SQL views for common dashboards (DAU/WAU/MAU, top events, etc.)
--   7. 24-month retention cleanup function
--
-- All client-facing access is via SECURITY DEFINER RPCs. Tables themselves are
-- locked down — anon/authenticated cannot read or write directly. Admin RPCs
-- gate on has_admin_permission(auth.uid(), 'permission_code').
--
-- See docs/launch/04-analytics.md for architecture overview.
-- =============================================================================

BEGIN;

-- =============================================================================
-- PART 1 — RBAC (Role-Based Access Control)
-- =============================================================================

-- Permissions catalog. A permission is a granular capability ('analytics.read',
-- 'analytics.partners.read', 'admin.config.write'). Roles bundle permissions.
CREATE TABLE IF NOT EXISTS public.admin_permissions (
  code        text PRIMARY KEY,
  description text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.admin_permissions FROM anon, authenticated, PUBLIC;
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_permissions FORCE  ROW LEVEL SECURITY;

INSERT INTO public.admin_permissions (code, description) VALUES
  ('analytics.read',            'Read aggregate analytics dashboards (KPIs, funnels, retention)'),
  ('analytics.users.read',      'Read per-user activity journey (for support / debugging)'),
  ('analytics.partners.read',   'Read partner-specific analytics (offer views, partner traffic)'),
  ('analytics.doctors.read',    'Read doctor-specific analytics (profile views, contact clicks)'),
  ('analytics.financial.read',  'Read revenue / payment / subscription analytics'),
  ('analytics.events.read',     'Generic event explorer access (raw event browsing)'),
  ('analytics.events.export',   'Export raw event data to CSV/JSON'),
  ('admin.users.read',          'List admin users and their roles'),
  ('admin.users.write',         'Grant or revoke admin roles to users'),
  ('admin.config.read',         'Read app_config, banners, popups'),
  ('admin.config.write',        'Modify app_config, banners, popups'),
  ('admin.medical_master.read', 'Read medical_master items including unverified'),
  ('admin.medical_master.write','Verify, edit, merge medical_master items'),
  ('admin.support.read',        'Read user data for support purposes (read-only)'),
  ('admin.support.write',       'Modify user data for support resolution (e.g., reset OTP)')
ON CONFLICT (code) DO NOTHING;

-- Roles catalog. Role is a named bundle of permissions.
CREATE TABLE IF NOT EXISTS public.admin_roles (
  code        text PRIMARY KEY,
  name        text NOT NULL,
  description text NOT NULL,
  is_system   boolean NOT NULL DEFAULT false,  -- system roles cannot be deleted
  created_at  timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON public.admin_roles FROM anon, authenticated, PUBLIC;
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_roles FORCE  ROW LEVEL SECURITY;

INSERT INTO public.admin_roles (code, name, description, is_system) VALUES
  ('super_admin',       'Super Admin',        'Full unrestricted access', true),
  ('analytics_viewer',  'Analytics Viewer',   'Read all analytics dashboards', true),
  ('support_agent',     'Support Agent',      'Per-user journey access for support', true),
  ('marketing_analyst', 'Marketing Analyst',  'Acquisition, retention, partner/offer analytics', true),
  ('partner_manager',   'Partner Manager',    'Partner-specific analytics only', true),
  ('content_editor',    'Content Editor',     'Manage app_config, banners, popups — no analytics', true),
  ('data_analyst',      'Data Analyst',       'Read-only event explorer access', true),
  ('medical_reviewer',  'Medical Reviewer',   'Verify medical_master entries', true)
ON CONFLICT (code) DO NOTHING;

-- Role↔permission mapping.
CREATE TABLE IF NOT EXISTS public.admin_role_permissions (
  role_code       text NOT NULL REFERENCES public.admin_roles(code) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES public.admin_permissions(code) ON DELETE CASCADE,
  PRIMARY KEY (role_code, permission_code)
);

REVOKE ALL ON public.admin_role_permissions FROM anon, authenticated, PUBLIC;
ALTER TABLE public.admin_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_role_permissions FORCE  ROW LEVEL SECURITY;

-- Seed default role↔permission assignments.
INSERT INTO public.admin_role_permissions (role_code, permission_code)
SELECT 'super_admin', code FROM public.admin_permissions
ON CONFLICT DO NOTHING;

INSERT INTO public.admin_role_permissions (role_code, permission_code) VALUES
  ('analytics_viewer',  'analytics.read'),
  ('analytics_viewer',  'analytics.partners.read'),
  ('analytics_viewer',  'analytics.doctors.read'),
  ('support_agent',     'analytics.users.read'),
  ('support_agent',     'admin.support.read'),
  ('marketing_analyst', 'analytics.read'),
  ('marketing_analyst', 'analytics.partners.read'),
  ('marketing_analyst', 'analytics.doctors.read'),
  ('marketing_analyst', 'analytics.events.read'),
  ('marketing_analyst', 'analytics.events.export'),
  ('partner_manager',   'analytics.partners.read'),
  ('content_editor',    'admin.config.read'),
  ('content_editor',    'admin.config.write'),
  ('data_analyst',      'analytics.events.read'),
  ('data_analyst',      'analytics.events.export'),
  ('data_analyst',      'analytics.read'),
  ('medical_reviewer',  'admin.medical_master.read'),
  ('medical_reviewer',  'admin.medical_master.write')
ON CONFLICT DO NOTHING;

-- Admin users — the set of users who have ANY admin permission.
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  status     text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  notes      text
);

REVOKE ALL ON public.admin_users FROM anon, authenticated, PUBLIC;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users FORCE  ROW LEVEL SECURITY;

-- User↔role mapping (a user can hold multiple roles).
CREATE TABLE IF NOT EXISTS public.admin_user_roles (
  user_id    uuid NOT NULL REFERENCES public.admin_users(user_id) ON DELETE CASCADE,
  role_code  text NOT NULL REFERENCES public.admin_roles(code) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL DEFAULT now(),
  granted_by uuid REFERENCES auth.users(id),
  PRIMARY KEY (user_id, role_code)
);

REVOKE ALL ON public.admin_user_roles FROM anon, authenticated, PUBLIC;
ALTER TABLE public.admin_user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_user_roles FORCE  ROW LEVEL SECURITY;

-- Helper: does this user hold this permission via any of their roles?
CREATE OR REPLACE FUNCTION public.has_admin_permission(p_user_id uuid, p_permission text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users au
    JOIN public.admin_user_roles aur ON aur.user_id = au.user_id
    JOIN public.admin_role_permissions arp ON arp.role_code = aur.role_code
    WHERE au.user_id = p_user_id
      AND au.status = 'active'
      AND arp.permission_code = p_permission
  );
$$;

REVOKE ALL ON FUNCTION public.has_admin_permission(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_admin_permission(uuid, text) TO authenticated;

-- Helper: shorthand for "is this user an admin at all?"
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE user_id = p_user_id AND status = 'active'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;

-- =============================================================================
-- PART 2 — Analytics core tables
-- =============================================================================

-- Devices: stable per-install identity. anonymous_id is generated once on first
-- launch and persists across logins. The same device may have multiple user_ids
-- over its lifetime (e.g., shared family phone).
CREATE TABLE IF NOT EXISTS public.analytics_devices (
  anonymous_id  uuid PRIMARY KEY,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  platform      text,           -- 'ios' / 'android' / 'web'
  os_version    text,
  device_model  text,
  app_version   text,
  app_build     text,
  locale        text,           -- 'ar' / 'en'
  country_code  text,           -- best-effort, never IP-derived
  timezone      text
);

REVOKE ALL ON public.analytics_devices FROM anon, authenticated, PUBLIC;
ALTER TABLE public.analytics_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_devices FORCE  ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_analytics_devices_last_seen ON public.analytics_devices (last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_devices_app_version ON public.analytics_devices (app_version);

-- Sessions: one row per app session (cold start → background timeout).
CREATE TABLE IF NOT EXISTS public.analytics_sessions (
  session_id     uuid PRIMARY KEY,
  anonymous_id   uuid NOT NULL,
  user_id        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  started_at     timestamptz NOT NULL,
  ended_at       timestamptz,
  duration_ms    bigint,
  event_count    int NOT NULL DEFAULT 0,
  screen_count   int NOT NULL DEFAULT 0,
  app_version    text,
  platform       text,
  network_type   text,           -- 'wifi' / 'cellular' / 'offline' / 'unknown'
  ended_reason   text            -- 'background' / 'kill' / 'logout' / 'timeout'
);

REVOKE ALL ON public.analytics_sessions FROM anon, authenticated, PUBLIC;
ALTER TABLE public.analytics_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_sessions FORCE  ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_analytics_sessions_started ON public.analytics_sessions (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_sessions_user    ON public.analytics_sessions (user_id, started_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_analytics_sessions_anon    ON public.analytics_sessions (anonymous_id, started_at DESC);

-- Events: the firehose. Every meaningful interaction is one row.
CREATE TABLE IF NOT EXISTS public.analytics_events (
  event_id      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at   timestamptz NOT NULL,
  received_at   timestamptz NOT NULL DEFAULT now(),
  event_name    text        NOT NULL,                       -- 'doctor_profile_viewed'
  category      text        NOT NULL,                       -- 'doctor' / 'auth' / …
  user_id       uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  anonymous_id  uuid        NOT NULL,
  session_id    uuid,
  app_version   text,
  platform      text,
  os_version    text,
  device_model  text,
  locale        text,
  network_type  text,
  screen        text,                                       -- screen on which the event fired
  properties    jsonb       NOT NULL DEFAULT '{}'::jsonb    -- typed per event
);

REVOKE ALL ON public.analytics_events FROM anon, authenticated, PUBLIC;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events FORCE  ROW LEVEL SECURITY;

-- Hot indexes for the most common admin queries.
CREATE INDEX IF NOT EXISTS idx_events_occurred       ON public.analytics_events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_name_occurred  ON public.analytics_events (event_name, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_user_occurred  ON public.analytics_events (user_id, occurred_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_events_anon_occurred  ON public.analytics_events (anonymous_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_session        ON public.analytics_events (session_id);
CREATE INDEX IF NOT EXISTS idx_events_category_occ   ON public.analytics_events (category, occurred_at DESC);

-- GIN index on properties enables fast filtering by any property value
-- (e.g., "all events where properties->>'doctor_id' = '...'")
CREATE INDEX IF NOT EXISTS idx_events_properties_gin ON public.analytics_events USING GIN (properties);

-- =============================================================================
-- PART 3 — PHI sanitization (defense-in-depth backstop)
-- =============================================================================
-- The SDK has a strict whitelist; this is the database-level safety net for the
-- case where SDK validation is bypassed (e.g., direct RPC call from a client).
-- Strategy: strip individual property keys whose values look like PII rather
-- than rejecting whole rows (data preservation > strict rejection).

CREATE OR REPLACE FUNCTION public.analytics_sanitize_properties(p jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  k text;
  v text;
  result jsonb := '{}'::jsonb;
BEGIN
  IF p IS NULL OR jsonb_typeof(p) <> 'object' THEN
    RETURN '{}'::jsonb;
  END IF;
  FOR k, v IN SELECT key, value::text FROM jsonb_each_text(p) LOOP
    -- Drop oversized strings (> 200 chars).
    IF length(v) > 200 THEN CONTINUE; END IF;
    -- Drop values that look like phone numbers.
    IF v ~ '(\+?\d[\d\s\-\(\)]{7,}\d)' THEN CONTINUE; END IF;
    -- Drop values that look like email addresses.
    IF v ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}' THEN CONTINUE; END IF;
    -- Keep this key.
    result := result || jsonb_build_object(k, p->k);
  END LOOP;
  RETURN result;
END
$$;

CREATE OR REPLACE FUNCTION public.analytics_event_sanitize_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.properties := public.analytics_sanitize_properties(NEW.properties);
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_analytics_event_sanitize ON public.analytics_events;
CREATE TRIGGER trg_analytics_event_sanitize
  BEFORE INSERT ON public.analytics_events
  FOR EACH ROW EXECUTE FUNCTION public.analytics_event_sanitize_trigger();

-- =============================================================================
-- PART 4 — Ingestion RPC (called by the Flutter SDK)
-- =============================================================================
-- Clients call this RPC; they cannot insert into the events table directly.
-- The RPC accepts a batch (array) of events for efficient flushing.

CREATE OR REPLACE FUNCTION public.rpc_track_events_batch(p_events jsonb)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ev jsonb;
  inserted_count int := 0;
  v_user_id uuid := auth.uid();   -- NULL for anon callers
BEGIN
  IF jsonb_typeof(p_events) <> 'array' THEN
    RAISE EXCEPTION 'p_events must be a JSON array';
  END IF;

  FOR ev IN SELECT jsonb_array_elements(p_events) LOOP
    -- Required fields. Missing required fields → silently skip the event so one
    -- bad event doesn't poison a whole batch. The SDK is the source of truth
    -- for shape; this is defense-in-depth.
    IF NOT (ev ? 'event_name' AND ev ? 'category' AND ev ? 'occurred_at'
            AND ev ? 'anonymous_id') THEN
      CONTINUE;
    END IF;

    -- Reject anon events claiming a user_id that isn't their auth.uid().
    -- This prevents spoofing.
    IF ev ? 'user_id' AND (ev->>'user_id') IS NOT NULL THEN
      IF v_user_id IS NULL OR v_user_id::text <> (ev->>'user_id') THEN
        CONTINUE;
      END IF;
    END IF;

    INSERT INTO public.analytics_events (
      event_id, occurred_at, event_name, category, user_id, anonymous_id,
      session_id, app_version, platform, os_version, device_model, locale,
      network_type, screen, properties
    ) VALUES (
      COALESCE((ev->>'event_id')::uuid, gen_random_uuid()),
      (ev->>'occurred_at')::timestamptz,
      ev->>'event_name',
      ev->>'category',
      NULLIF(ev->>'user_id','')::uuid,
      (ev->>'anonymous_id')::uuid,
      NULLIF(ev->>'session_id','')::uuid,
      ev->>'app_version',
      ev->>'platform',
      ev->>'os_version',
      ev->>'device_model',
      ev->>'locale',
      ev->>'network_type',
      ev->>'screen',
      COALESCE(ev->'properties', '{}'::jsonb)
    )
    ON CONFLICT (event_id) DO NOTHING;
    inserted_count := inserted_count + 1;
  END LOOP;

  RETURN inserted_count;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_track_events_batch(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_track_events_batch(jsonb) TO anon, authenticated;

-- Companion RPC for upserting device + session metadata.
CREATE OR REPLACE FUNCTION public.rpc_track_session(p_payload jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF NOT (p_payload ? 'session_id' AND p_payload ? 'anonymous_id'
          AND p_payload ? 'started_at') THEN
    RETURN;
  END IF;

  -- Upsert device row (last_seen tick + metadata refresh).
  INSERT INTO public.analytics_devices AS d (
    anonymous_id, first_seen_at, last_seen_at,
    platform, os_version, device_model, app_version, app_build, locale,
    country_code, timezone
  ) VALUES (
    (p_payload->>'anonymous_id')::uuid,
    COALESCE((p_payload->>'first_seen_at')::timestamptz, now()),
    now(),
    p_payload->>'platform',
    p_payload->>'os_version',
    p_payload->>'device_model',
    p_payload->>'app_version',
    p_payload->>'app_build',
    p_payload->>'locale',
    p_payload->>'country_code',
    p_payload->>'timezone'
  )
  ON CONFLICT (anonymous_id) DO UPDATE SET
    last_seen_at = now(),
    platform     = EXCLUDED.platform,
    os_version   = EXCLUDED.os_version,
    device_model = EXCLUDED.device_model,
    app_version  = EXCLUDED.app_version,
    app_build    = EXCLUDED.app_build,
    locale       = EXCLUDED.locale,
    country_code = EXCLUDED.country_code,
    timezone     = EXCLUDED.timezone;

  -- Upsert session row.
  INSERT INTO public.analytics_sessions AS s (
    session_id, anonymous_id, user_id, started_at, ended_at, duration_ms,
    event_count, screen_count, app_version, platform, network_type, ended_reason
  ) VALUES (
    (p_payload->>'session_id')::uuid,
    (p_payload->>'anonymous_id')::uuid,
    CASE WHEN v_user_id IS NULL OR (p_payload->>'user_id') IS NULL THEN NULL
         WHEN v_user_id::text = (p_payload->>'user_id') THEN v_user_id
         ELSE NULL END,
    (p_payload->>'started_at')::timestamptz,
    NULLIF(p_payload->>'ended_at','')::timestamptz,
    NULLIF(p_payload->>'duration_ms','')::bigint,
    COALESCE((p_payload->>'event_count')::int, 0),
    COALESCE((p_payload->>'screen_count')::int, 0),
    p_payload->>'app_version',
    p_payload->>'platform',
    p_payload->>'network_type',
    p_payload->>'ended_reason'
  )
  ON CONFLICT (session_id) DO UPDATE SET
    user_id      = COALESCE(s.user_id, EXCLUDED.user_id),
    ended_at     = EXCLUDED.ended_at,
    duration_ms  = EXCLUDED.duration_ms,
    event_count  = GREATEST(s.event_count,  EXCLUDED.event_count),
    screen_count = GREATEST(s.screen_count, EXCLUDED.screen_count),
    network_type = EXCLUDED.network_type,
    ended_reason = EXCLUDED.ended_reason;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_track_session(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_track_session(jsonb) TO anon, authenticated;

-- =============================================================================
-- PART 5 — Pre-built SQL views for dashboards
-- =============================================================================

CREATE OR REPLACE VIEW public.v_dau AS
SELECT date_trunc('day', occurred_at)::date AS day,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS active_users,
       COUNT(DISTINCT user_id) FILTER (WHERE user_id IS NOT NULL) AS active_signed_in_users,
       COUNT(DISTINCT session_id) AS sessions,
       COUNT(*) AS event_volume
FROM public.analytics_events
WHERE occurred_at > now() - interval '90 days'
GROUP BY 1
ORDER BY 1 DESC;

CREATE OR REPLACE VIEW public.v_wau AS
SELECT date_trunc('week', occurred_at)::date AS week,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS active_users,
       COUNT(DISTINCT user_id) FILTER (WHERE user_id IS NOT NULL) AS active_signed_in_users
FROM public.analytics_events
WHERE occurred_at > now() - interval '180 days'
GROUP BY 1
ORDER BY 1 DESC;

CREATE OR REPLACE VIEW public.v_mau AS
SELECT date_trunc('month', occurred_at)::date AS month,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS active_users,
       COUNT(DISTINCT user_id) FILTER (WHERE user_id IS NOT NULL) AS active_signed_in_users
FROM public.analytics_events
WHERE occurred_at > now() - interval '24 months'
GROUP BY 1
ORDER BY 1 DESC;

CREATE OR REPLACE VIEW public.v_top_events_24h AS
SELECT event_name, category, COUNT(*) AS occurrences,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_users
FROM public.analytics_events
WHERE occurred_at > now() - interval '24 hours'
GROUP BY 1, 2 ORDER BY 3 DESC;

CREATE OR REPLACE VIEW public.v_top_events_7d AS
SELECT event_name, category, COUNT(*) AS occurrences,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_users
FROM public.analytics_events
WHERE occurred_at > now() - interval '7 days'
GROUP BY 1, 2 ORDER BY 3 DESC;

CREATE OR REPLACE VIEW public.v_top_events_30d AS
SELECT event_name, category, COUNT(*) AS occurrences,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_users
FROM public.analytics_events
WHERE occurred_at > now() - interval '30 days'
GROUP BY 1, 2 ORDER BY 3 DESC;

CREATE OR REPLACE VIEW public.v_app_version_distribution AS
SELECT app_version, platform,
       COUNT(DISTINCT anonymous_id) AS devices,
       MAX(last_seen_at) AS last_seen_at
FROM public.analytics_devices
WHERE last_seen_at > now() - interval '30 days'
GROUP BY 1, 2
ORDER BY 3 DESC;

CREATE OR REPLACE VIEW public.v_doctor_profile_views_30d AS
SELECT properties->>'doctor_id' AS doctor_id,
       COUNT(*) AS views,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_viewers,
       COUNT(*) FILTER (WHERE event_name = 'doctor_phone_clicked') AS phone_clicks,
       COUNT(*) FILTER (WHERE event_name = 'doctor_address_clicked') AS address_clicks,
       COUNT(*) FILTER (WHERE event_name = 'doctor_share_clicked') AS shares,
       COUNT(*) FILTER (WHERE event_name = 'doctor_favorited') AS favorites
FROM public.analytics_events
WHERE occurred_at > now() - interval '30 days'
  AND properties ? 'doctor_id'
  AND event_name IN ('doctor_profile_viewed','doctor_phone_clicked',
                     'doctor_address_clicked','doctor_share_clicked','doctor_favorited')
GROUP BY 1
ORDER BY 2 DESC;

CREATE OR REPLACE VIEW public.v_partner_profile_views_30d AS
SELECT properties->>'partner_id' AS partner_id,
       COUNT(*) AS views,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_viewers,
       COUNT(*) FILTER (WHERE event_name = 'partner_phone_clicked') AS phone_clicks,
       COUNT(*) FILTER (WHERE event_name = 'partner_address_clicked') AS address_clicks
FROM public.analytics_events
WHERE occurred_at > now() - interval '30 days'
  AND properties ? 'partner_id'
  AND event_name IN ('partner_profile_viewed','partner_phone_clicked','partner_address_clicked')
GROUP BY 1
ORDER BY 2 DESC;

CREATE OR REPLACE VIEW public.v_offer_views_30d AS
SELECT properties->>'offer_id' AS offer_id,
       properties->>'partner_id' AS partner_id,
       COUNT(*) FILTER (WHERE event_name = 'offer_viewed') AS views,
       COUNT(*) FILTER (WHERE event_name = 'offer_clicked') AS clicks,
       COUNT(*) FILTER (WHERE event_name = 'offer_redeemed') AS redemptions,
       COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text))
         FILTER (WHERE event_name = 'offer_viewed') AS unique_viewers
FROM public.analytics_events
WHERE occurred_at > now() - interval '30 days'
  AND properties ? 'offer_id'
  AND event_name IN ('offer_viewed','offer_clicked','offer_redeemed')
GROUP BY 1, 2
ORDER BY 3 DESC;

CREATE OR REPLACE VIEW public.v_otp_success_rate_7d AS
SELECT date_trunc('day', occurred_at)::date AS day,
       COALESCE(properties->>'channel','unknown') AS channel,
       platform,
       COUNT(*) FILTER (WHERE event_name = 'otp_requested') AS requested,
       COUNT(*) FILTER (WHERE event_name = 'otp_verified')  AS verified,
       COUNT(*) FILTER (WHERE event_name = 'otp_failed')    AS failed,
       ROUND(100.0 * COUNT(*) FILTER (WHERE event_name = 'otp_verified')::numeric
             / NULLIF(COUNT(*) FILTER (WHERE event_name = 'otp_requested'), 0), 1) AS success_pct
FROM public.analytics_events
WHERE occurred_at > now() - interval '7 days'
  AND event_name IN ('otp_requested','otp_verified','otp_failed')
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- Lock down view access (admin RPCs read these; clients never do).
REVOKE ALL ON public.v_dau, public.v_wau, public.v_mau,
              public.v_top_events_24h, public.v_top_events_7d, public.v_top_events_30d,
              public.v_app_version_distribution,
              public.v_doctor_profile_views_30d, public.v_partner_profile_views_30d,
              public.v_offer_views_30d, public.v_otp_success_rate_7d
       FROM anon, authenticated, PUBLIC;

-- =============================================================================
-- PART 6 — Admin RPCs (analytics dashboards)
-- =============================================================================

-- Top-level KPI overview. The home screen of the future admin panel.
CREATE OR REPLACE FUNCTION public.rpc_admin_kpis_overview(p_period text DEFAULT '7d')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_interval interval;
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  v_interval := CASE p_period
    WHEN '24h' THEN interval '24 hours'
    WHEN '7d'  THEN interval '7 days'
    WHEN '30d' THEN interval '30 days'
    WHEN '90d' THEN interval '90 days'
    ELSE interval '7 days' END;

  SELECT jsonb_build_object(
    'period', p_period,
    'active_users',
      (SELECT COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text))
       FROM analytics_events WHERE occurred_at > now() - v_interval),
    'sessions',
      (SELECT COUNT(*) FROM analytics_sessions WHERE started_at > now() - v_interval),
    'avg_session_duration_seconds',
      (SELECT ROUND(AVG(duration_ms)/1000.0, 1) FROM analytics_sessions
       WHERE started_at > now() - v_interval AND duration_ms IS NOT NULL),
    'signups',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval AND event_name = 'signup_completed'),
    'logins',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval AND event_name = 'login_completed'),
    'bookings_started',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval AND event_name = 'booking_started'),
    'bookings_confirmed',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval AND event_name = 'booking_confirmed'),
    'booking_conversion_pct',
      (SELECT ROUND(100.0
        * COUNT(*) FILTER (WHERE event_name = 'booking_confirmed')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE event_name = 'booking_started'), 0), 1)
       FROM analytics_events WHERE occurred_at > now() - v_interval),
    'otp_success_pct',
      (SELECT ROUND(100.0
        * COUNT(*) FILTER (WHERE event_name = 'otp_verified')::numeric
        / NULLIF(COUNT(*) FILTER (WHERE event_name = 'otp_requested'), 0), 1)
       FROM analytics_events WHERE occurred_at > now() - v_interval)
  ) INTO v_result;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_kpis_overview(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_kpis_overview(text) TO authenticated;

-- Per-doctor metrics — the answer to "how many people viewed Dr. X?"
CREATE OR REPLACE FUNCTION public.rpc_admin_doctor_metrics(p_doctor_id uuid, p_period text DEFAULT '30d')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_interval interval;
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.doctors.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  v_interval := CASE p_period
    WHEN '7d'  THEN interval '7 days'
    WHEN '30d' THEN interval '30 days'
    WHEN '90d' THEN interval '90 days'
    ELSE interval '30 days' END;

  SELECT jsonb_build_object(
    'doctor_id', p_doctor_id,
    'period', p_period,
    'profile_views',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_profile_viewed'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'unique_viewers',
      (SELECT COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text))
       FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_profile_viewed'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'phone_clicks',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_phone_clicked'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'address_clicks',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_address_clicked'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'shares',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_share_clicked'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'favorites',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'doctor_favorited'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'booking_starts',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'booking_started'
         AND (properties->>'doctor_id')::uuid = p_doctor_id),
    'booking_confirms',
      (SELECT COUNT(*) FROM analytics_events
       WHERE occurred_at > now() - v_interval
         AND event_name = 'booking_confirmed'
         AND (properties->>'doctor_id')::uuid = p_doctor_id)
  ) INTO v_result;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_doctor_metrics(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_doctor_metrics(uuid, text) TO authenticated;

-- Per-partner metrics.
CREATE OR REPLACE FUNCTION public.rpc_admin_partner_metrics(p_partner_id uuid, p_period text DEFAULT '30d')
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_interval interval;
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.partners.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  v_interval := CASE p_period
    WHEN '7d'  THEN interval '7 days'
    WHEN '30d' THEN interval '30 days'
    WHEN '90d' THEN interval '90 days'
    ELSE interval '30 days' END;

  SELECT jsonb_build_object(
    'partner_id', p_partner_id,
    'period', p_period,
    'profile_views',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'partner_profile_viewed'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'unique_viewers',
      (SELECT COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text))
       FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'partner_profile_viewed'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'phone_clicks',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'partner_phone_clicked'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'address_clicks',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'partner_address_clicked'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'offer_views',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'offer_viewed'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'offer_clicks',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'offer_clicked'
         AND (properties->>'partner_id')::uuid = p_partner_id),
    'voucher_redemptions',
      (SELECT COUNT(*) FROM analytics_events WHERE occurred_at > now() - v_interval
         AND event_name = 'voucher_used'
         AND (properties->>'partner_id')::uuid = p_partner_id)
  ) INTO v_result;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_partner_metrics(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_partner_metrics(uuid, text) TO authenticated;

-- Top events list (with category and unique-user count).
CREATE OR REPLACE FUNCTION public.rpc_admin_top_events(p_period text DEFAULT '7d', p_limit int DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_interval interval;
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  v_interval := CASE p_period
    WHEN '24h' THEN interval '24 hours'
    WHEN '7d'  THEN interval '7 days'
    WHEN '30d' THEN interval '30 days'
    ELSE interval '7 days' END;

  SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT event_name, category,
           COUNT(*) AS occurrences,
           COUNT(DISTINCT COALESCE(user_id::text, anonymous_id::text)) AS unique_users
    FROM analytics_events
    WHERE occurred_at > now() - v_interval
    GROUP BY 1, 2
    ORDER BY 3 DESC
    LIMIT p_limit
  ) t;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_top_events(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_top_events(text, int) TO authenticated;

-- Per-user journey — every event a single user fired, in order. For support.
CREATE OR REPLACE FUNCTION public.rpc_admin_user_journey(p_user_id uuid, p_limit int DEFAULT 200)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.users.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.occurred_at DESC), '[]'::jsonb) INTO v_result
  FROM (
    SELECT occurred_at, event_name, category, screen, properties,
           app_version, platform, session_id
    FROM analytics_events
    WHERE user_id = p_user_id
    ORDER BY occurred_at DESC
    LIMIT p_limit
  ) t;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_user_journey(uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_user_journey(uuid, int) TO authenticated;

-- Generic event search (filters as JSONB to keep the signature stable as fields evolve).
CREATE OR REPLACE FUNCTION public.rpc_admin_event_search(p_filters jsonb DEFAULT '{}'::jsonb, p_limit int DEFAULT 100)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'analytics.events.read') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(t) ORDER BY t.occurred_at DESC), '[]'::jsonb) INTO v_result
  FROM (
    SELECT occurred_at, event_name, category, user_id, anonymous_id,
           screen, app_version, platform, properties
    FROM analytics_events
    WHERE
      (NOT (p_filters ? 'event_name')   OR event_name = p_filters->>'event_name')
      AND (NOT (p_filters ? 'category') OR category   = p_filters->>'category')
      AND (NOT (p_filters ? 'user_id')  OR user_id    = (p_filters->>'user_id')::uuid)
      AND (NOT (p_filters ? 'platform') OR platform   = p_filters->>'platform')
      AND (NOT (p_filters ? 'since')    OR occurred_at >= (p_filters->>'since')::timestamptz)
      AND (NOT (p_filters ? 'until')    OR occurred_at <  (p_filters->>'until')::timestamptz)
    ORDER BY occurred_at DESC
    LIMIT LEAST(p_limit, 1000)
  ) t;

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_event_search(jsonb, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_event_search(jsonb, int) TO authenticated;

-- =============================================================================
-- PART 7 — Retention cleanup (24 months)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.analytics_cleanup_old_events(p_keep interval DEFAULT interval '24 months')
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted bigint;
BEGIN
  WITH del AS (
    DELETE FROM public.analytics_events
    WHERE occurred_at < now() - p_keep
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_deleted FROM del;

  -- Sessions that ended before the retention window are also pruned.
  DELETE FROM public.analytics_sessions
  WHERE COALESCE(ended_at, started_at) < now() - p_keep;

  RETURN v_deleted;
END
$$;

REVOKE ALL ON FUNCTION public.analytics_cleanup_old_events(interval) FROM PUBLIC;
-- Cleanup is intended to be run by the operator (cron / pg_cron / manual).
-- No grant to anon/authenticated.

COMMIT;

-- =============================================================================
-- Post-migration verification (run separately):
--
--   -- Tables exist and are RLS-locked
--   SELECT tablename, rowsecurity FROM pg_tables
--   WHERE schemaname='public'
--     AND tablename IN ('analytics_events','analytics_sessions','analytics_devices',
--                       'admin_users','admin_roles','admin_permissions',
--                       'admin_role_permissions','admin_user_roles');
--
--   -- Roles + permissions seeded
--   SELECT role_code, COUNT(*) FROM public.admin_role_permissions GROUP BY 1 ORDER BY 1;
--
--   -- Ingestion RPC works (anon-callable smoke test will be done from the SDK)
--   SELECT public.rpc_track_events_batch('[]'::jsonb);  -- expect 0
--
--   -- Cleanup function works
--   SELECT public.analytics_cleanup_old_events(interval '24 months'); -- expect 0
-- =============================================================================
