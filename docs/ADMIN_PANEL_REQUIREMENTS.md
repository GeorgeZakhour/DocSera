# Admin Panel — Feature Requirements
# ==================================
# This document tracks features that need to be built into the
# DocSera Admin Panel when it is created in the future.
#
# Last updated: 2026-04-23


## 1. Medical Master Item Review Panel
### Priority: HIGH
### Context
The health records system uses a `medical_master` table with predefined items
(allergies, chronic diseases, medications, surgeries, vaccines, family conditions).

A "manual entry" feature was added (2026-04-23) that allows both patients and
doctors to create custom master items when they can't find what they need in the
predefined list. These custom entries are stored with:
- `is_verified = false`
- `source = 'patient'` or `source = 'doctor'`
- `created_by = <user_uuid>`

### Required Admin Features
1. **View all unverified items**
   - Table: `medical_master` WHERE `is_verified = false`
   - Show: name_en, name_ar, category, source, created_by, created_at
   - Sort by: most recent first

2. **Review & Verify**
   - Admin can edit name_en / name_ar / description_en / description_ar
   - Admin can set `is_verified = true` to promote to official list
   - Admin can reject (delete) invalid entries

3. **Merge Duplicates**
   - Detect potential duplicates (fuzzy matching on name_en/name_ar)
   - Allow merging: reassign all `patient_medical_records` pointing to the
     duplicate master_id → to the canonical master_id, then delete the duplicate

4. **Add Missing Translation**
   - Many custom entries will only have one language filled in
   - Admin can add the missing Arabic or English translation

5. **Analytics Dashboard**
   - Show count of unverified items per category
   - Show trending custom entries (most frequently added by users)
   - These trending items should be prioritized for verification

### Database Columns (already added)
```sql
medical_master.is_verified  BOOLEAN DEFAULT true
medical_master.source       TEXT DEFAULT 'system'   -- 'system', 'patient', 'doctor'
medical_master.created_by   UUID REFERENCES auth.users(id)
```

### Notes on Patient vs Doctor Entries
- **Patient entries** (`source = 'patient'`): Lower reliability, may contain
  typos or non-standard terminology. Should be reviewed more carefully.
- **Doctor entries** (`source = 'doctor'`): Higher reliability, likely to use
  correct medical terminology. Can potentially be auto-verified or fast-tracked.
- Future enhancement: Consider a separate reliability score or confidence level.


## 2. Analytics Dashboard (added 2026-05-04)
### Priority: HIGH
### Context

A full PostHog/Mixpanel-grade analytics system is now live in the patient app.
Every meaningful interaction (133 events across 14 categories) is tracked and
stored in `analytics_events` with full context. The data layer is ready —
all that's missing is the UI on top of it.

See `docs/launch/04-analytics.md` for the architecture and `docs/launch/04b-admin-rpcs.md`
for the RPC contract this admin section calls.

### Required Admin Panel Sections

#### 2.1 Home / KPI Overview
- One screen, 8 cards: active users, sessions, avg session duration, signups,
  logins, bookings started, bookings confirmed, OTP success rate.
- Period selector: 24h / 7d / 30d / 90d.
- Backend: `rpc_admin_kpis_overview(period)`.
- Permission: `analytics.read`.

#### 2.2 Event Explorer
- Filterable table of raw events. Filter by event_name, category, user_id,
  platform, time range.
- Backend: `rpc_admin_event_search(filters jsonb, limit int)`.
- Permission: `analytics.events.read`.

#### 2.3 Funnels
- Pre-defined: signup, booking, loyalty redemption.
- Step bar chart with conversion % at each transition.
- Backend: `rpc_admin_funnel(funnel_name, period)` (Stage 5+ — not yet built).
- Permission: `analytics.read`.

#### 2.4 Retention Cohorts
- Day-1, day-7, day-30 retention by signup week.
- The classic retention triangle visualization.
- Backend: `rpc_admin_retention(cohort_period)` (Stage 5+ — not yet built).
- Permission: `analytics.read`.

#### 2.5 Doctor Performance
- List view: most-viewed doctors with views, phone clicks, booking conversion.
- Detail view: per-doctor metrics card pack (8 metrics).
- Backend: `v_doctor_profile_views_30d` view, `rpc_admin_doctor_metrics(doctor_id, period)`.
- Permission: `analytics.doctors.read`.

#### 2.6 Partner Performance
- List view: most-viewed partners with profile views, contact clicks, offer
  views, voucher redemptions.
- Detail view: per-partner metrics card pack (7 metrics).
- Per-offer view counts and redemption rates.
- Backend: `v_partner_profile_views_30d`, `v_offer_views_30d`,
  `rpc_admin_partner_metrics(partner_id, period)`.
- Permission: `analytics.partners.read`.

#### 2.7 User Journey Viewer (Support tool)
- Search by user_id or email; show the user's recent event timeline (up to 200
  events, reverse chronological).
- Color-coded by category. Expandable rows for properties.
- Backend: `rpc_admin_user_journey(user_id, limit)`.
- Permission: `analytics.users.read`.

### Admin Authentication & RBAC

The admin panel must enforce the RBAC system already in the database. See
`docs/launch/04c-rbac-roles.md` for the full design.

8 pre-seeded roles, 15 granular permissions. Every admin RPC the panel calls
gates on `has_admin_permission(auth.uid(), 'permission.code')`. The panel itself
should:

1. After login, call a "what can I do" RPC (to be added) to learn the user's
   permissions and hide nav items they can't access.
2. On any RPC error with code `42501`, redirect to a "you don't have access" page.
3. For role management: add a UI for `admin.users.write` permission holders to
   grant/revoke roles. Backed by inserts/deletes on `admin_user_roles`.

### App-level Configuration (force-update, banners, etc.)

#### 2.8 Force-Update Control
- UI to set `min_supported_version_ios` / `min_supported_version_android`,
  store URLs, and force-update messages (EN/AR).
- Backed by direct UPDATE on `public.app_config` (single row, id=1).
- Permission: `admin.config.write`.
- Show a confirmation modal: "This will block all users on versions below X
  starting at their next app launch. Continue?"

#### 2.9 Banner & Popup Management
- CRUD for `popup_banners`, `banners`, `home_cards`.
- Permission: `admin.config.write`.

### Technical Notes

- Build target: Flutter web (separate build) OR a separate web admin app in
  Next.js / Remix / etc. Whatever ships fastest.
- Auth: Supabase auth, same instance as the patient app. Admin status is
  determined by presence in `admin_users` with `status = 'active'`.
- All data access via the admin RPCs documented in `docs/launch/04b-admin-rpcs.md`.
  The admin panel never writes raw SQL.
- Charts library suggestion: Recharts (web) or fl_chart (Flutter).

### Bootstrap

Before the panel is usable, the first super_admin must be granted via direct SQL.
See `docs/launch/04c-rbac-roles.md` → "Common operations → Grant a user super_admin".
