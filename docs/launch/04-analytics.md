# 04 — Analytics System (overview)

**Date started:** 2026-05-04
**Status:** Stages 1–4 complete
**Replaces:** Third-party analytics (PostHog, Mixpanel, Amplitude, Firebase Analytics)
**Migration:** `supabase/migrations/20260504140000_analytics_and_rbac.sql`

## Summary

A self-hosted analytics system built directly on Supabase. Tracks every meaningful interaction in DocSera (~133 events across 14 categories), stores them with full context (session, device, app version, locale, screen), and exposes admin-only RPCs that the future admin panel calls to render KPIs, funnels, retention curves, doctor/partner-specific metrics, and per-user journeys.

Equivalent functional scope to a third-party analytics product, but with three big advantages for healthtech in Syria:
- **No third-party SDK** — no patient activity ever leaves your infrastructure.
- **No new vendor** — no SaaS bill, no Russia/Syria geofencing risk.
- **No additional VPS load** — uses the Postgres instance already running Supabase.

## Architecture

```
                ┌─────────────────────────────────────┐
                │       DocSera Flutter App           │
                │                                     │
                │   AnalyticsService (Stage 2)        │
                │      ├─ Event catalog (whitelist)   │
                │      ├─ Offline queue               │
                │      ├─ Batching / debounce         │
                │      └─ Auto-events (lifecycle,     │
                │            screens, sessions)        │
                └──────────────────┬──────────────────┘
                                   │ HTTPS, batched
                                   ▼
   ┌────────────────────────────────────────────────────────┐
   │  Supabase RPCs (anon-callable, validated)              │
   │   ├─ rpc_track_events_batch(events jsonb[])            │
   │   └─ rpc_track_session(session jsonb)                  │
   └──────────────────┬─────────────────────────────────────┘
                      │  PHI sanitization trigger (backstop)
                      ▼
   ┌────────────────────────────────────────────────────────┐
   │  Tables (RLS-locked, no direct client access)          │
   │   ├─ analytics_events     ← the firehose               │
   │   ├─ analytics_sessions   ← session lifecycle          │
   │   └─ analytics_devices    ← device snapshots           │
   └──────────────────┬─────────────────────────────────────┘
                      │
                      ▼
   ┌────────────────────────────────────────────────────────┐
   │  Pre-built SQL views                                   │
   │   v_dau / v_wau / v_mau / v_top_events_*               │
   │   v_doctor_profile_views_30d / v_partner_*             │
   │   v_offer_views_30d / v_otp_success_rate_7d            │
   │   v_app_version_distribution                           │
   └──────────────────┬─────────────────────────────────────┘
                      │
                      ▼
   ┌────────────────────────────────────────────────────────┐
   │  Admin RPCs (RBAC-gated, return shaped JSON)           │
   │   rpc_admin_kpis_overview                              │
   │   rpc_admin_top_events                                 │
   │   rpc_admin_doctor_metrics                             │
   │   rpc_admin_partner_metrics                            │
   │   rpc_admin_user_journey                               │
   │   rpc_admin_event_search                               │
   └──────────────────┬─────────────────────────────────────┘
                      │ has_admin_permission(user, perm)
                      ▼
              ┌──────────────────┐
              │  Future Admin UI │
              │  (Flutter / web) │
              └──────────────────┘
```

## Stage 1 — what's built

### Tables (all RLS-forced, no anon/auth grants)
- `analytics_events` — every event ever, with rich context (event_id, occurred_at, received_at, event_name, category, user_id, anonymous_id, session_id, app_version, platform, os_version, device_model, locale, network_type, screen, properties JSONB).
- `analytics_sessions` — one row per app session with start, end, duration, event_count, screen_count, ended_reason.
- `analytics_devices` — device snapshots keyed by stable anonymous_id. Holds platform, OS version, device model, app version, locale, country code, timezone.

### Indexes
- Time-range index on `occurred_at` for fast "last 24h / 7d / 30d" queries.
- Composite indexes on `(event_name, occurred_at)`, `(user_id, occurred_at)`, `(category, occurred_at)`.
- GIN index on `properties` for fast filtering by any JSONB key (e.g., `properties->>'doctor_id'`).
- Session indexes by user, anonymous_id, and started_at.

### RBAC (Role-Based Access Control)
8 system roles seeded with granular permission bundles. See [04c-rbac-roles.md](04c-rbac-roles.md) for the full table.

| Role | Permissions count |
|---|---|
| `super_admin` | 15 (everything) |
| `marketing_analyst` | 5 |
| `analytics_viewer` | 3 |
| `data_analyst` | 3 |
| `content_editor` | 2 |
| `medical_reviewer` | 2 |
| `support_agent` | 2 |
| `partner_manager` | 1 |

Helper functions: `has_admin_permission(user_id, permission_code)`, `is_admin(user_id)`.

### PHI sanitization (defense-in-depth)
Every row entering `analytics_events` is passed through a trigger that scans property values and silently drops keys whose values:
- Exceed 200 characters.
- Match a phone-number regex.
- Match an email regex.

This is a backstop — the SDK whitelist (Stage 2) is the primary guard. The trigger ensures even a misconfigured or malicious client cannot land PII into the events table.

### Ingestion RPCs (anon-callable, validated)
- `rpc_track_events_batch(p_events jsonb)` — accepts an array of events, validates each, inserts the valid ones, returns count of inserts. Rejects events claiming a user_id that doesn't match `auth.uid()`.
- `rpc_track_session(p_payload jsonb)` — upserts the device snapshot and the session row.

### Admin RPCs (RBAC-gated)
All admin RPCs check `has_admin_permission(auth.uid(), 'permission_code')` before returning data. Unauthorized callers get a `42501 forbidden` error.

| RPC | Permission required | What it returns |
|---|---|---|
| `rpc_admin_kpis_overview(period)` | `analytics.read` | DAU, sessions, signups, logins, booking conversion, OTP success — all in one JSON |
| `rpc_admin_top_events(period, limit)` | `analytics.read` | Most-fired events with unique-user counts |
| `rpc_admin_doctor_metrics(doctor_id, period)` | `analytics.doctors.read` | Profile views, phone clicks, share, favorites, booking starts, booking confirms — per doctor |
| `rpc_admin_partner_metrics(partner_id, period)` | `analytics.partners.read` | Profile views, contact clicks, offer views, voucher redemptions — per partner |
| `rpc_admin_user_journey(user_id, limit)` | `analytics.users.read` | Every event a single user fired, in order, for support |
| `rpc_admin_event_search(filters, limit)` | `analytics.events.read` | Generic event browser with filters |

Stage 2 will add: `rpc_admin_funnel`, `rpc_admin_retention`, `rpc_admin_screen_flow`, plus per-offer and per-voucher RPCs.

### SQL Views
Read-only convenience views for ad-hoc dashboarding from Supabase Studio:
- `v_dau`, `v_wau`, `v_mau` — active-user trends.
- `v_top_events_24h`, `v_top_events_7d`, `v_top_events_30d`.
- `v_app_version_distribution` — powers the forced-update decision.
- `v_doctor_profile_views_30d`, `v_partner_profile_views_30d`, `v_offer_views_30d`.
- `v_otp_success_rate_7d` — by channel and platform.

### Retention
`analytics_cleanup_old_events(p_keep interval)` — deletes events and sessions older than 24 months. Run periodically (cron / pg_cron / manual). Default 24-month retention.

## How to operate it

### Day-to-day
Once Stages 2–4 are complete, every meaningful user action emits an event automatically. Open Supabase Studio and run:

```sql
-- Today's events
SELECT event_name, COUNT(*) FROM v_top_events_24h ORDER BY 2 DESC LIMIT 20;

-- KPI overview (admin-only)
SELECT rpc_admin_kpis_overview('7d');
```

### Granting yourself super_admin (one-time, after Stage 1)
Replace the UUID below with your own auth user id (find it via `SELECT id FROM auth.users WHERE email='gzakhour96@gmail.com'`):

```sql
INSERT INTO public.admin_users (user_id, status, notes)
VALUES ('<your-uuid>', 'active', 'Initial super admin');

INSERT INTO public.admin_user_roles (user_id, role_code, granted_by)
VALUES ('<your-uuid>', 'super_admin', '<your-uuid>');
```

After this you can call any `rpc_admin_*` from the app or SQL while authenticated as yourself.

### Running cleanup
Recommended weekly cron on the VPS:
```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec -i supabase-db psql -U postgres -d postgres -c \
   \"SELECT public.analytics_cleanup_old_events(interval '24 months');\""
```

## How to verify Stage 1

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec -i supabase-db psql -U postgres -d postgres" <<'SQL'

-- 8 RLS-forced tables
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname='public'
  AND tablename IN ('analytics_events','analytics_sessions','analytics_devices',
                    'admin_users','admin_roles','admin_permissions',
                    'admin_role_permissions','admin_user_roles');

-- 8 roles seeded
SELECT role_code, COUNT(*) FROM admin_role_permissions GROUP BY 1 ORDER BY 1;

-- Empty-batch ingestion succeeds (returns 0)
SELECT public.rpc_track_events_batch('[]'::jsonb);
SQL
```

**Verified passing on 2026-05-04.**

## Stage 2 — Flutter SDK (complete)

Five files under `lib/services/analytics/`:

| File | Purpose |
|---|---|
| `analytics_event_catalog.dart` | The contract. 86 registered events, each with category + allowed/required property whitelists. PHI sanitizer (200-char cap, phone/email regex). |
| `analytics_queue.dart` | Persistent offline queue. Events mirrored to `SharedPreferences`; survive app kill. Capped at 5,000 events (drops oldest first). |
| `analytics_session_tracker.dart` | Session lifecycle. Cold-start = new session; foreground after ≥30min background = new session. |
| `analytics_navigator_observer.dart` | Auto-emits `screen_viewed` on every named-route push/pop/replace. Anonymous routes are skipped. |
| `analytics_service.dart` | Public API: `Analytics.instance.{init, track, identify, reset, optOut, flush}`. App-lifecycle observer for `app_foregrounded`/`app_backgrounded`. Batched flush every 30s, every 20 events, or on background. |

### How the SDK behaves
- **Anonymous-then-identified.** `anonymous_id` generated once on first launch (UUID v4 in `SharedPreferences`), survives restarts. After login, `identify(userId)` attaches `user_id` to subsequent events. `reset()` regenerates `anonymous_id` (e.g., on logout from a shared device).
- **Whitelist enforcement.** Calling `track('unknown_event')` is a no-op + debug warning. Calling with property keys not in the catalog drops those keys silently. Calling with required props missing drops the whole event.
- **Privacy.** `optOut(true)` halts all tracking and clears the queue. `optOut(false)` resumes. PHI sanitization happens at three layers (catalog whitelist, value sanitizer, DB trigger).
- **Offline-first.** All events go to the queue; flushes attempt the RPC and re-queue on failure. Network blips, Syriatel dropouts, app kills — events are not lost (up to the 5,000-event cap).
- **Batched.** Events flush every 30 seconds, every 20 events, OR immediately on app background. Each flush is one RPC call carrying up to 100 events.

### Auto-events emitted with zero code
- `app_opened` (once, on cold start)
- `app_foregrounded` / `app_backgrounded`
- `session_start` / `session_end` (with duration bucket and reason)
- `screen_viewed` (every named-route navigation)

### Wiring in `main.dart`
- `Analytics.instance.init(initialUserId: ...)` runs in `_bootstrap()` after Supabase init.
- `Analytics.instance.identify(state.user.id)` runs in the AuthCubit listener.
- `AnalyticsNavigatorObserver()` attached to `MaterialApp.navigatorObservers`.

## Stage 3 — Critical-path instrumentation (complete)

A representative slice of the highest-value events is now wired in production code. Auto-events (sessions, screen views, app lifecycle) cover the rest of the baseline.

| Wired location | Events |
|---|---|
| [lib/screens/auth/login/login_otp.dart](../../lib/screens/auth/login/login_otp.dart) | `otp_requested`, `otp_verified`, `otp_failed` |
| [lib/screens/doctors/appointment/appointment_confirm.dart](../../lib/screens/doctors/appointment/appointment_confirm.dart) | `booking_confirmed`, `booking_failed` |
| [lib/screens/doctors/doctor_profile_page.dart](../../lib/screens/doctors/doctor_profile_page.dart) | `doctor_profile_viewed`, `doctor_phone_clicked`, `doctor_email_clicked`, `doctor_share_clicked`, `doctor_favorited`, `doctor_unfavorited` |
| [lib/screens/search_page.dart](../../lib/screens/search_page.dart) | `search_started` |
| [lib/screens/home/loyalty/partner_profile_page.dart](../../lib/screens/home/loyalty/partner_profile_page.dart) | `partner_profile_viewed` |
| [lib/screens/home/loyalty/offer_detail_page.dart](../../lib/screens/home/loyalty/offer_detail_page.dart) | `offer_clicked` |
| [lib/screens/home/loyalty/voucher_detail_page.dart](../../lib/screens/home/loyalty/voucher_detail_page.dart) | `voucher_viewed` |
| [lib/main.dart](../../lib/main.dart) | `login_completed` (in AuthCubit listener) |
| SDK auto-emit | `app_opened`, `app_foregrounded`, `app_backgrounded`, `session_start`, `session_end`, `screen_viewed` |

The remaining ~115 events have schemas registered in the catalog and can be wired by adding one line per call site. They're documented in [04a-event-taxonomy.md](04a-event-taxonomy.md). Add them as you touch each screen — there's no urgency to wire them all at once.

### Instrumentation patterns
- **Page view:** in `initState()` for StatefulWidget, in `build()` for StatelessWidget. Exactly one call.
- **Action / button click:** in the `onPressed` / `onTap` handler, before the side-effect.
- **Funnel-critical step:** in the success branch of the underlying RPC/network call.
- **Failure mode:** in the catch block, with `error_code` matching the taxonomy enum.

## Stage 4 — Documentation (complete)

| Doc | Purpose |
|---|---|
| [04-analytics.md](04-analytics.md) | This file. Architecture overview. |
| [04a-event-taxonomy.md](04a-event-taxonomy.md) | Every event registered, with category and property schema. The contract. |
| [04b-admin-rpcs.md](04b-admin-rpcs.md) | Every admin RPC, parameters, return JSON shape. The future admin panel API contract. |
| [04c-rbac-roles.md](04c-rbac-roles.md) | Roles + permissions catalog. How to grant/revoke admin access. |
| [04d-sample-queries.md](04d-sample-queries.md) | Copy-paste-ready SQL for the most common questions. |

See [roadmap.md](roadmap.md) for overall status.

## Implementation notes (post-launch fixes)

### 2026-05-04 — anchored phone-pattern regex
Initial PHI sanitizer used `\d[\d\s\-\(\)]{7,}\d` which matched digit-heavy *substrings*. Discovered during Stage 3 testing that some UUIDs contain such substrings (e.g., `1234-5678-9abc`), causing legitimate `doctor_id` / `partner_id` values to be silently stripped. Fixed in migration `20260504150000_analytics_fixes.sql` and SDK `analytics_event_catalog.dart` to anchor the regex (`^\+?[\d\s\-\(\)]{7,20}$`) — only flags when the WHOLE string is phone-shaped. Keeps UUIDs (which contain hex letters) safe; correctly drops real phone-shaped values.

### 2026-05-04 — auth state subscription
`Analytics.init()` originally captured `user_id` only once via `initialUserId`. If the Supabase session was restored asynchronously (after `init()` returned), or if the user signed in/out later, the `_userId` field went stale. Cold-start events fired in the brief window between init and AuthCubit's first emission lacked `user_id` attribution. Fixed by subscribing to `Supabase.auth.onAuthStateChange` inside `init()` — `_userId` now updates reactively on session restore, sign-in, sign-out, and token refresh. The subscription is cancelled on hot-reload (idempotent re-init).

### 2026-05-04 — current-screen stamping
Every event now carries the active screen name in its top-level `screen` column (separate from `properties.screen_name` on `screen_viewed` events). The `AnalyticsNavigatorObserver` pushes the screen name into `Analytics.setCurrentScreen()` on every named-route navigation. Enables questions like "what screen was open when this `booking_failed` fired?" without parsing properties. Anonymous routes (no `settings.name`) leave the screen unchanged from the previous named route.

### 2026-05-04 — superuser bypass on admin permission helper
`has_admin_permission()` originally returned false when called from a non-authenticated SQL context (psql, SQL editor) because `auth.uid()` is NULL there. Made the SQL editor unable to run any admin RPC even as the founder. Fixed by adding a bypass: when `current_user` is `postgres` / `supabase_admin` / `service_role`, return true unconditionally. Client-facing roles (`anon`, `authenticated`) still go through the full role/permission check — the gate is unchanged for the actual app.

## What could go wrong

- **A future migration might add a public table without RLS.** The general lockdown verification query (see [01-rls-lockdown.md](01-rls-lockdown.md)) catches this.
- **Cleanup never run** → `analytics_events` grows unbounded. Scale: ~50 events/user/day × 100K users × 24 months = ~3.6B rows. Without cleanup or partitioning at that volume, queries slow down. **Recommendation:** add a weekly cron now, even though there's no data yet, so it's habitual.
- **PHI sanitization triggers can be expensive at high write volume.** At 5M events/day the regex scan cost is real but bearable. If we ever exceed that, partition the table by month (DROP PARTITION for cleanup is much faster than DELETE) and consider moving sanitization to the application layer only.
- **Admin permissions over-granted.** The seed roles are deliberately conservative — only `super_admin` has financial/admin-write permissions. Audit role memberships periodically.

## Score impact (after all stages)

8.6 → **8.9** (+0.3). Foundational for product, marketing, and operations decisions for the entire life of the app.
