# DocSera Notifications Platform — Design

**Status:** Draft (brainstormed 2026-05-06)
**Scope:** DocSera (patient app) — Phase 1 of a platform that will later extend to DocSera-Pro and an admin panel.
**Author:** Brainstormed with Claude.

---

## 1. Goals

1. Make every patient-facing notification **survive offline** (push fire-and-forget loses messages today).
2. Give the patient **a bell-icon inbox** that is the source of truth for "did I miss anything."
3. Make notification copy, audience, and scheduling **editable from a future admin panel** without code deploys.
4. Make the system ready for **marketing campaigns** (bulk scheduled sends with audience filters) using the same pipeline as transactional notifications.
5. Add **time-sensitive appointment reminders** (T-24h, T-30m) — the highest-leverage missing trigger.
6. Stay on **Pushy** (mandatory: managed providers underperform in Syria).
7. Keep the **shared Supabase backend with DocSera-Pro** — schema and engine must be neutral to which app delivers the row.

## 2. Non-goals (deferred or rejected)

- ❌ Medication dose reminders, missed-dose alerts, refill reminders — the medication data model is a free-text passive log (`name + start_date + dosage`), not structured frequency. Not applicable.
- ❌ Vaccination booster windows / pediatric calendar — same passive-log structure.
- ❌ Vitals out-of-range alerts, weekly vital summaries — vitals are a viewer, no targets.
- ❌ Post-visit feedback / doctor ratings — no rating system in the app.
- ❌ "Doctor running late" — would need a new feature in DocSera-Pro first.
- ❌ Waitlist / "slot opened earlier" / last-minute offer — no waitlist data model.
- ❌ OneSignal / Knock / managed providers.
- ❌ Email and SMS channels — architecture is ready for them but not delivered in Phase 1.
- ❌ DocSera-Pro UI work — same backend will serve Pro, but the Pro bell-panel is a follow-on phase.

## 3. The core insight driving the architecture

> A "comprehensive notifications system" is not a longer list of triggers. It is **one row per notification, persisted, with a fan-out engine** that delivers to push / inbox / (later) email from the same row.

Without persistence, the bell icon is a second source of truth that drifts from push, the admin panel has nothing to read, marketing campaigns need a parallel pipeline, and quiet-hours / preferences have to be enforced twice. Every "comprehensive" feature collapses into the same primitive.

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                       INPUTS (event sources)                         │
│  DB webhooks (existing)   Cron (scheduled / campaigns)   Admin API   │
└────────────┬─────────────────────┬─────────────────────────┬────────┘
             │                     │                         │
             └─────────────────────┴─────────────────────────┘
                                  │
                                  ▼
                  ┌────────────────────────────────┐
                  │  notify() Edge Function         │
                  │  (single dispatcher, modular)   │
                  │                                 │
                  │  routers/  → normalize event   │
                  │  handlers/ → who-gets-what     │
                  │  engine/   → render + insert   │
                  └────────────────┬────────────────┘
                                  │ INSERT
                                  ▼
                  ┌────────────────────────────────┐
                  │   notifications  (per-user)    │
                  │   the inbox of record          │
                  └────────────────┬────────────────┘
                                  │ AFTER INSERT trigger
                                  ▼
              ┌───────────────┬───────────────┬───────────────┐
              ▼               ▼               ▼               ▼
            Pushy         In-app          Email           Analytics
                       (realtime)      (Phase 4)       (events log)
```

### 4.1 The single dispatcher pattern

Replace the current `push_notifications` Edge Function with a refactored `notify` function organized as:

```
supabase/functions/notify/
├── index.ts                  # entry: routes by source
├── routers/
│   ├── from_db_webhook.ts    # current path — table+type → event_code
│   ├── from_cron.ts          # scheduled appointment reminders, campaigns
│   └── from_admin.ts         # future: direct admin-panel send
├── handlers/
│   ├── appointments.ts       # all appointment events
│   ├── messages.ts           # message events (preserves current decryption)
│   ├── documents.ts
│   ├── loyalty.ts
│   ├── security.ts
│   ├── marketing.ts          # campaigns + banners
│   └── pro_todos.ts          # DocSera-Pro todo_tasks (kept here for now)
└── engine/
    ├── render.ts             # template lookup + placeholder rendering + locale
    ├── prefs.ts              # check user prefs + quiet hours + rate limits
    └── send.ts               # insert notifications row → fan-out via DB trigger
```

**Why one function, not many:** each Edge Function is a separate deployment unit with its own cold-start, its own Pushy key fetch, its own logging. Splitting by domain duplicates infrastructure code. Splitting by app (DocSera vs Pro) duplicates the engine. The router/handler/engine split keeps domain logic isolated *inside* one deployable unit.

**Migration of existing logic:** the message decryption block and the appointment status-transition logic in the current `push_notifications/index.ts` move verbatim into `handlers/messages.ts` and `handlers/appointments.ts`. Behavior is preserved bit-for-bit in Phase 1.

### 4.2 Fan-out via database trigger, not in the Edge Function

When `notifications.INSERT` fires:

1. A `pg_net` HTTP call (or a second small Edge Function `dispatch_channels`) reads the row.
2. Looks up `user_devices` for the `target_user_id` + `target_app`.
3. Sends to Pushy.
4. Writes a `notification_events` row (`delivered` / `failed`).

Why pull fan-out out of `notify()`: it lets **any** insert into `notifications` (cron, admin panel, manual SQL) automatically deliver. The `notify()` function becomes a pure "compute the row" service.

## 5. Database schema

Six new tables. All RLS-enforced.

### 5.1 `notifications` — the inbox of record

```sql
create table public.notifications (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  app             text not null check (app in ('docsera','docsera_pro')),

  event_code      text not null,        -- e.g. 'appointment.reminder.t30m'
  category        text not null,        -- 'appointments' | 'messages' | 'documents'
                                        -- | 'loyalty' | 'security' | 'marketing' | 'system'
  importance      text not null default 'informational'
                  check (importance in ('critical','important','informational')),

  title           text not null,        -- pre-rendered, locale-correct, ready to display
  body            text not null,
  subject_label   text,                 -- e.g. "for Layan" — for relative-tagged rows
  payload         text,                 -- existing 'conversation:<id>' / 'report:<id>:<rel>:<name>' etc.
  icon_hint       text,                 -- 'message' | 'appointment' | 'gift' | 'security' ...

  -- relational hints (nullable, used by bell UI for swipe actions and grouping)
  related_appointment_id  uuid,
  related_conversation_id uuid,
  related_relative_id     uuid,
  related_doctor_id       uuid,
  related_campaign_id     uuid,

  -- lifecycle
  scheduled_for   timestamptz,          -- non-null = not yet delivered (future-dated)
  delivered_at    timestamptz,
  read_at         timestamptz,
  clicked_at      timestamptz,
  dismissed_at    timestamptz,

  created_at      timestamptz not null default now()
);

create index ix_notif_user_unread       on notifications (user_id, app, read_at) where read_at is null;
create index ix_notif_user_recent       on notifications (user_id, app, created_at desc);
create index ix_notif_scheduled_pending on notifications (scheduled_for) where delivered_at is null and scheduled_for is not null;

-- dedup: same user, same template, same context within 60s
create unique index ux_notif_dedup
  on notifications (user_id, event_code, coalesce(payload,''))
  where created_at > now() - interval '60 seconds';
```

**RLS:**
- `select` allowed where `user_id = auth.uid()`
- `update read_at / clicked_at / dismissed_at` allowed where `user_id = auth.uid()` (but no other column updates)
- `insert` — denied for everyone except `service_role` (engine writes only)
- `delete` — denied; rows hard-deleted after 90 days by a maintenance job

### 5.2 `notification_templates` — versioned, localized, admin-editable

```sql
create table public.notification_templates (
  event_code      text not null,
  locale          text not null check (locale in ('ar','en')),
  version         int  not null default 1,

  category        text not null,
  importance      text not null default 'informational',
  default_channels text[] not null default array['push','in_app'],
  icon_hint       text,

  title_template  text not null,        -- "موعدك خلال {{minutes}} دقيقة"
  body_template   text not null,
  payload_template text,                -- "conversation:{{conversation_id}}"

  -- behavioral knobs editable by admin
  respect_quiet_hours boolean not null default true,
  rate_limit_per_hour int,              -- null = no cap
  group_key_template  text,             -- for grouping: "conv:{{conversation_id}}"

  active          boolean not null default true,
  updated_at      timestamptz not null default now(),
  primary key (event_code, locale, version)
);
```

**Resolution at render-time:** look up the row where `(event_code, user_locale, active=true)` and `version = max(version)`. Fall back to `ar` if user_locale row missing. Render with `{{ }}` placeholders from the engine's context.

**Why versioned:** admin edits create a new version row, never mutate the previous one. Notifications already sent retain their rendered text in the `notifications` row, so old copy never silently changes for already-sent items.

### 5.3 `notification_preferences` — per-user matrix

```sql
create table public.notification_preferences (
  user_id         uuid not null references public.users(id) on delete cascade,
  category        text not null,        -- matches notifications.category
  channel         text not null,        -- 'push' | 'in_app' | 'email'
  enabled         boolean not null default true,
  primary key (user_id, category, channel)
);

create table public.notification_quiet_hours (
  user_id         uuid primary key references public.users(id) on delete cascade,
  enabled         boolean not null default false,
  start_local_time time not null default '22:00',
  end_local_time   time not null default '07:00',
  timezone        text not null default 'Asia/Damascus'
);
```

**Defaults seeded on user creation:** all categories enabled on `push` and `in_app`, except `marketing` (defaults to `in_app=true`, `push=false`). Quiet hours disabled by default.

**Override semantics enforced at engine level:**
- `importance='critical'` always delivered — ignores prefs and quiet hours. Used for: security alerts, account-deletion countdowns, scheduled-maintenance heads-up.
- `importance='important'` respects category prefs but ignores quiet hours. Used for: appointment reminders T-30m, doctor cancellations.
- `importance='informational'` respects everything. Used for: messages, gifts, document uploads, marketing.

### 5.4 `notification_campaigns` — admin-driven scheduled sends

```sql
create table public.notification_campaigns (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,        -- internal label
  template_event  text not null,        -- references notification_templates.event_code
  audience_id     uuid references public.notification_audiences(id),
  scheduled_for   timestamptz not null,
  status          text not null default 'scheduled'
                  check (status in ('scheduled','running','done','cancelled','failed')),
  context         jsonb not null default '{}'::jsonb,  -- placeholder values
  created_by      uuid references public.users(id),
  created_at      timestamptz not null default now(),
  started_at      timestamptz,
  finished_at     timestamptz,
  total_targets   int,
  total_delivered int default 0
);

create table public.notification_audiences (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  description     text,
  filter_sql      text not null,        -- saved as a parameterized SQL fragment
  estimated_size  int,
  created_at      timestamptz not null default now()
);
```

A cron-triggered Edge Function picks campaigns where `scheduled_for <= now() and status = 'scheduled'`, resolves the audience SQL into user IDs, calls `notify()` for each batch, and updates status. Same delivery pipeline as transactional sends.

### 5.5 `notification_events` — append-only analytics log

```sql
create table public.notification_events (
  id              bigserial primary key,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  event           text not null check (event in ('queued','delivered','failed','opened','clicked','dismissed')),
  detail          jsonb,
  occurred_at     timestamptz not null default now()
);

create index ix_notif_events_notif on notification_events (notification_id);
create index ix_notif_events_event on notification_events (event, occurred_at desc);
```

Powers the admin panel's delivery-health dashboard. Cleaned up after 180 days.

## 6. Trigger catalogue (DocSera patient — what the platform delivers)

Mapped to event codes and importance.

| Event code | Cat. | Imp. | Trigger source | Notes |
|---|---|---|---|---|
| `appointment.booked` | appointments | important | DB INSERT | Existing |
| `appointment.confirmed` | appointments | important | DB UPDATE | Existing |
| `appointment.rejected` | appointments | important | DB UPDATE | Existing; render `rejection_reason` |
| `appointment.cancelled_by_doctor` | appointments | important | DB UPDATE | Existing |
| `appointment.rescheduled` | appointments | important | DB UPDATE | Existing; CTA "View new time" |
| `appointment.reminder.t24h` | appointments | important | Cron + local | **NEW — Phase 1** |
| `appointment.reminder.t30m` | appointments | important | Cron + local | **NEW — Phase 1, time-sensitive** |
| `appointment.report_added` | appointments | important | DB UPDATE | Existing; add snippet preview |
| `appointment.report_edited` | appointments | informational | DB UPDATE | Existing |
| `appointment.doctor_vacation_overlap` | appointments | important | DB INSERT on `doctor_vacations` | NEW — Phase 2 |
| `message.received.text` | messages | informational | DB INSERT | Existing |
| `message.received.voice` | messages | informational | DB INSERT | Upgrade copy: "أرسل تسجيلًا صوتيًا (0:27)" |
| `message.received.attachment` | messages | informational | DB INSERT | Existing |
| `message.conversation_closed` | messages | informational | DB UPDATE | NEW — Phase 2 |
| `message.long_unread` | messages | informational | Cron 48h | NEW — Phase 3 |
| `document.added` | documents | informational | DB INSERT | Existing |
| `document.deleted_by_doctor` | documents | informational | DB DELETE | NEW — Phase 2 |
| `loyalty.gift_received` | loyalty | informational | DB INSERT | Existing |
| `loyalty.points_expiring` | loyalty | informational | Cron | NEW — Phase 3, only if expiry tracked |
| `loyalty.voucher_expiring` | loyalty | informational | Cron | NEW — Phase 3 |
| `loyalty.tier_reached` | loyalty | informational | DB UPDATE | NEW — Phase 3 |
| `loyalty.birthday_gift` | loyalty | informational | Cron | NEW — Phase 3 |
| `relative.added_to_profile` | security | important | DB INSERT | NEW — Phase 2 |
| `security.new_device_login` | security | critical | DB INSERT on `user_devices` | NEW — Phase 2 |
| `security.password_changed` | security | critical | DB UPDATE | NEW — Phase 2 |
| `security.email_or_phone_changed` | security | critical | DB UPDATE | NEW — Phase 2 |
| `security.biometrics_changed` | security | important | client | NEW — Phase 2 |
| `security.suspicious_activity` | security | critical | server-side rate-limit | NEW — Phase 2 |
| `account.deletion_scheduled` | security | critical | DB INSERT | NEW — Phase 2 |
| `account.deletion_t7d` / `_t1d` / `_cancelled` | security | critical | Cron | NEW — Phase 2 |
| `legal.consent_required` | system | critical | admin | NEW — Phase 2 |
| `marketing.banner_published` | marketing | informational | DB INSERT on `banners` | NEW — Phase 4 |
| `marketing.campaign` | marketing | informational | Admin/cron | NEW — Phase 4 |
| `system.maintenance_scheduled` | system | important | Admin | NEW — Phase 4 |
| `system.force_update_required` | system | critical | Server config | NEW — Phase 4 |

## 7. Bell-icon UX (DocSera patient — minimal version)

Goal: simple, fast, offline-resilient. Pro gets the glass-panel treatment; DocSera gets a clean reliable list.

- **Bell icon** top-right of the home tab. Badge shows `count(notifications) where read_at is null and user_id = me`.
- **Tap → bottom sheet** with:
  - Header: "Notifications" + "Mark all as read" link.
  - Section: **PINNED** (only when `delivered_at is null` for future scheduled, OR `importance='important'` and `read_at is null`).
  - Sections: **Today** / **Yesterday** / **Earlier** (chronological).
  - Each row: icon (`icon_hint`) · title · body · subject_label (if any) · relative time · unread dot.
- **Tap row →** existing deep-link logic (reused). Sets `clicked_at`. Auto-marks read.
- **Empty state** illustrated.
- **Pull-to-refresh** triggers re-sync.
- **Realtime** via Supabase channel on `notifications WHERE user_id=me`.

**No swipe actions, no filters, no grouping** in DocSera Phase 1. Add only if user feedback demands it. Pro will get those features.

**Local cache:** the inbox keeps the last 90 days locally (already-decrypted text, no PII risk beyond what the user can see in-app) so the bell renders instantly on cold start, even offline. Rehydrates from server on next online tick.

## 8. Preferences screen (replaces the existing menu row)

Behind the existing "Notifications" entry in `account/preferences.dart`.

```
┌───────────────────────────────────────────────────────┐
│  Notifications                                         │
│                                                        │
│  Do Not Disturb        [○ off]                         │
│  Quiet hours           22:00 — 07:00      [Edit]       │
│                                                        │
│  ── CATEGORIES ───────────────────────────────────────│
│  Appointment reminders    Push ●   In-app ●           │
│  Appointment changes      Push ●   In-app ●           │
│  Messages                 Push ●   In-app ●           │
│  Reports & documents      Push ●   In-app ●           │
│  Loyalty & gifts          Push ●   In-app ●           │
│  Security alerts          Push ●   In-app ●  (always on)│
│  Marketing & banners      Push ○   In-app ●           │
│  System & maintenance     Push ●   In-app ●           │
└───────────────────────────────────────────────────────┘
```

- Security alerts row is read-only (cannot be muted — user safety).
- Toggling a row writes to `notification_preferences`.
- Quiet hours stored in `notification_quiet_hours`.

## 9. Localization & template authoring

- All strings live in `notification_templates`, keyed by `(event_code, locale, version)`.
- Locale = user's app locale (`users.preferred_locale`), not device locale.
- Placeholders in `{{ }}` rendered server-side at insert time. The `notifications` row stores the **final pre-rendered string** so changes to templates never retroactively edit sent rows.
- Engine fails open: if template missing, falls back to Arabic, then to a hardcoded "DocSera notification" generic string. Never crashes a webhook.
- Admin panel later writes new versions; never mutates past versions.

## 10. Importance tiers — what they actually drive

| Tier | Pushy interruption | Quiet hours | Bell pinning | Examples |
|---|---|---|---|---|
| `critical` | iOS time-sensitive + Android FULL_SCREEN_INTENT (where allowed) | Override | Pinned | Security, account deletion, force-update |
| `important` | iOS time-sensitive | Override | Pinned if unread | Appointment reminder T-30m, doctor cancellation |
| `informational` | Standard | Respect | Chronological | Messages, gifts, documents, marketing |

**Apple Critical Alerts entitlement:** out of scope for Phase 1. The platform will *support* it (column already there), but we won't pursue the entitlement until the system is operational and we have real user data on missed-delivery rates.

## 11. Scheduled appointment reminders — dual-track delivery

The "better" addition: reminders fire from **both** server cron and client-local schedule, deduped by `notification_id`.

**Why dual-track:**
- Local-only fails if the user reinstalls, switches device, or revokes notification permission then re-grants.
- Server-only fails if the device is offline at fire time and Pushy can't deliver.
- Dual-track gives belt-and-suspenders for the most safety-critical category.

**How:**
1. When an appointment is booked or confirmed, a row is **pre-inserted** into `notifications` with `scheduled_for = appointment_time - 24h` (and another for `-30m`), `delivered_at = null`.
2. A cron job (every 5 min) picks rows where `scheduled_for <= now() and delivered_at is null`, marks `delivered_at = now()`, and triggers fan-out.
3. The client also receives the row via realtime when it's inserted, schedules a **local** `flutter_local_notifications.zonedSchedule()` with `notification_id` as the dedup key.
4. When push or local fires, the handler checks `notifications.delivered_at` — if already set, suppress. First one wins.
5. Cancelled/rescheduled appointments → server deletes the corresponding pending rows, client cancels the local schedule via realtime DELETE event.

This gives correct behavior across all combinations of online/offline, app installed/uninstalled, permission states.

## 12. Phase plan

### Phase 1 — Foundation + visible win (week 1–2.5)

**Backend:**
- Migrations: 6 new tables + RLS + indexes + seed templates for the 6 existing triggers.
- Refactor `push_notifications` → `notify` with router/handler/engine split. Behavior preserved.
- DB trigger on `notifications.INSERT` → fan-out to Pushy.
- Cron job for scheduled reminders (every 5 min, picks pending rows).
- Pre-insertion of T-24h and T-30m rows when an appointment is booked or confirmed.
- Cleanup of pending rows when appointment is cancelled or rescheduled.

**Client:**
- Bell icon on home tab + bottom-sheet inbox.
- Realtime subscription + 90-day local cache (sqflite or similar — to be decided in plan).
- App-icon badge synced to unread count.
- Preferences screen replacing the menu-row stub.
- Local scheduling for T-24h and T-30m as the second track of dual-delivery.
- Importance-tier-aware interruption levels in `showLocal()`.

**Visible wins shipped:**
- Bell icon shows existing 6 trigger types (instant value — users see "we have an inbox now").
- T-24h and T-30m appointment reminders (the most-requested healthcare notification globally).
- Real preferences screen replacing the dead menu row.

**Zero behavior change for existing 6 triggers** beyond now-being-persisted.

### Phase 2 — Patient lifecycle & security (week 3–4)

- Doctor-vacation-overlap, conversation-closed, document-deleted.
- Security alerts (login, password, email, biometrics, suspicious).
- Account deletion lifecycle.
- Privacy/legal consent gate on next open.
- Voice message duration in copy.

### Phase 3 — Loyalty & engagement (week 5)

- Points expiring, voucher expiring, tier reached, birthday gift.
- Long-unread message reminder (cron 48h).
- Relative-added-to-profile.

### Phase 4 — Admin readiness & marketing (week 6–7)

- Admin-API writes to `notify` (`from_admin` router).
- Campaigns + audiences tables wired to a campaign-runner cron.
- Banner-published trigger.
- System maintenance / force-update events.
- Optional: email channel for security + report categories (requires picking an SMTP relay; defer if unblocked).

### Phase 5 — DocSera-Pro extension (separate engagement)

- Glass panel inbox in Pro.
- Pro handlers: assigned tasks, messages-from-patients, doctor-running-late (after the feature ships in Pro), schedule changes, etc.
- All built on the same engine. No backend rework.

## 13. Admin panel readiness — what's pre-wired now

Every Phase 1 table is shaped for admin panel CRUD without modification:
- `notification_templates` — admin edits create new versions.
- `notification_audiences` — admin defines reusable filters.
- `notification_campaigns` — admin schedules sends.
- `notification_events` — read-only delivery dashboard.
- `notifications` — read-only "what was sent to whom" search.

When the admin panel arrives, the only work is the front-end — the backend already serves it. RLS policies for admin role are added then.

## 14. Migration / rollout safety

- Phase 1 migration is **additive**: 6 new tables, no destructive changes to existing tables.
- The existing `push_notifications` Edge Function is **left in place** during the cutover. The new `notify` function runs in parallel; webhooks switch to it via Supabase config one trigger at a time, verified in production before flipping the next.
- A dedup guard in the new function checks if the legacy function already delivered (by `event_code + payload + last 60s`).
- Rollback: a single config change reverts each webhook to the old function.

## 15. Open questions deferred to writing-plans

- Local-cache library: `sqflite` (already in repo if present), `hive`, or Supabase's offline cache plugin? Plan should pick one based on existing repo conventions.
- Cron infrastructure: pg_cron extension on the self-hosted Supabase instance, or a separate scheduled function via a third-party (e.g. Cloudflare Cron Trigger calling the Edge Function)?
- iOS time-sensitive entitlement: requires Info.plist key + interruptionLevel — coordinate with the Privacy Manifest TODO already noted in CLAUDE.md.
- App-icon badge on Android: API limits this to launchers that support it; need to confirm Pushy supports `badge` field on Android.
- Marketing audience SQL: parameterization vs free-form (security risk) — needs a sandboxed query builder, not raw SQL. Plan should define the safe subset.

---

## Appendix A — Why the existing message-decryption logic is preserved as-is

The current Edge Function decrypts ENC: messages server-side using `rpc_get_encryption_key_service()` and AES-CBC. This is required because the patient's device may not be online when the push fires, so we render a readable preview server-side rather than ship encrypted bytes to Pushy.

The refactor moves this code from `push_notifications/index.ts` into `handlers/messages.ts` byte-for-byte. No changes to the encryption pattern. Pre-rendered text still lands in `notifications.body`, which is RLS-scoped to the user — same trust boundary as a delivered chat message in the app.
