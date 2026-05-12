# DocSera Admin Panel — Comprehensive Requirements

> **Status:** Active spec, replacing the 2026-04-23 version which covered ~25% of intended scope. **Last updated: 2026-05-12.**
>
> **Audience:** Engineering teams implementing the admin panel and product/ops teams who will use it. Every domain is documented; every RPC contract listed; every role + permission enumerated.
>
> **Repo:** Standalone — `DocSera-Admin` (to be created), separate from `DocSera` (patient app) and `DocSera-Pro` (doctor app). Deploys to `admin.docsera.app`.

---

## 0. Executive summary

The admin panel is the back-office tool for DocSera staff to run every aspect of the product: doctors, patients, subscriptions, payments, marketing, monitoring, and analytics. It replaces the current "SSH + psql" workflow with a reliable, scalable, premium UI.

**Audience:** internal staff only. Currently: founder (super-admin) + 4 reps. Will scale to support, accounting, marketing, medical reviewers, analytics observers.

**Priority order:** **Performance and reliability > Premium design > Feature completeness.** A slow or buggy admin tool costs more than a feature-incomplete one.

**Tech stack:**
- **Flutter Web** — same framework as DocSera + DocSera-Pro, full premium glass design parity, shared design system primitives possible, no second language to maintain.
- **Supabase JS-equivalent (supabase_flutter)** — same client as the apps.
- **PostgreSQL admin RPCs** — single API surface; the panel never writes raw SQL.
- **Self-hosted on Syrian VPS** — same VPS that hosts Supabase. Static build served via nginx at `admin.docsera.app`.
- **Auth:** Supabase auth, gated by presence in `admin_users` with `status='active'`. RBAC enforced server-side via `has_admin_permission()` on every RPC.

**Design language:** Dark-first with selective glass accents. Reserved for modals, KPI cards, status toasts. Flat dark surfaces everywhere else for performance + information density. DocSera teal as the only accent color. See §4 for full design spec.

**Languages:** Arabic (primary, RTL) + English (secondary, LTR). ARB-based i18n identical to the consumer apps.

---

## 1. Build phases

### V0.1 — Lifeline (3 weeks target)
The minimum viable admin panel that **retires the SQL runbook in `docs/launch/17-subscription-v2.md`**. Build only this if launch is in <4 weeks.

- Auth + RBAC + design system
- Doctor search
- Subscription editor (activate plan, edit capacity, change paid_until, modules)
- Verification queue (license review → approve / reject)
- Comp gift flow (`grant_complimentary_presence`)
- Talk-to-us queue (`talk_to_us_intent_at` doctors)
- Suspended doctors list
- Audit log viewer

### V0.5 — Operational essentials (+2 weeks)
- Doctor CRUD (deactivate, edit profile, transfer)
- Patient list + detail
- Banner / popup CRUD
- Force-update control
- Trial cliff dashboard (doctors whose trial ends in 7d/14d)
- Rep performance basic dashboard (lead conversion, gift quota usage)

### V1.0 — Comprehensive (+3-4 weeks)
- Accounting (payment ledger, revenue reports, exports)
- Plan / module catalog editor (change prices, toggle visibility, promotional pricing flags)
- Marketing campaigns (push notification builder, gift campaigns)
- Support tools (view-as-user, password reset, account recovery)
- Medical master review (carry over from existing doc)
- Basic analytics views (KPI overview, subscription funnel, trial conversion)
- Admin user management UI (grant/revoke roles)

### V1.5 — Pro tier (+1 month)
- Full analytics suite (funnels, retention, doctor/partner performance — using the existing RPC contract in `docs/launch/04b-admin-rpcs.md`)
- System monitoring (edge function health, cron status, error rates, DB perf)
- Manual SQL console (IP-whitelisted, audit-logged, super_admin only)
- Multi-language content editor (translation management for ARB / DB content)
- Rep performance deep dive

### V2 — Comprehensive platform (future)
- Multi-tenancy (if expanding to other regions / white-label)
- Public API for partner integrations
- Billing webhook integration (when payment processor lands)
- Automated rep quota management
- Support ticket system

---

## 2. Tech stack and architecture

### Project structure (`DocSera-Admin/` repo)

```
DocSera-Admin/
├── lib/
│   ├── app/                  # Constants, themes, brand
│   ├── core/                  # Shared utilities, services
│   │   ├── services/         # Supabase clients, RPC wrappers
│   │   ├── utils/            # Router, formatters, validators
│   │   └── models/           # Shared models (DoctorRow, SubscriptionRow, etc.)
│   ├── features/             # Feature modules (one per admin domain)
│   │   ├── auth/             # Admin login, session, RBAC client
│   │   ├── doctors/          # Doctor list, detail, edit, verification queue
│   │   ├── patients/         # Patient management
│   │   ├── subscriptions/    # The big one — see §6
│   │   ├── catalogs/         # Plan and module catalog editors
│   │   ├── accounting/       # Payment ledger, revenue
│   │   ├── marketing/        # Banners, popups, campaigns
│   │   ├── monitoring/       # System health, errors
│   │   ├── analytics/        # KPI dashboards
│   │   ├── audit/            # Audit log viewer
│   │   ├── reps/             # Rep accounts and quotas
│   │   ├── support/          # View-as-user, recovery
│   │   ├── medical_master/   # Custom medical entry review (V1.0)
│   │   └── admin_users/      # Admin user/role management (V1.0)
│   ├── design_system/        # Glass primitives, tables, forms, layout
│   ├── widgets/              # Reusable presentational widgets
│   ├── l10n/                  # ARB sources
│   ├── gen_l10n/             # Generated (do not edit)
│   └── main.dart             # Entry point
├── web/
│   └── (Flutter web shell)
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── .github/workflows/        # CI/CD (analyze, test, build, deploy)
```

### Backend: existing infrastructure

Already exists and ready to consume:
- `admin_users`, `admin_roles`, `admin_permissions`, `admin_role_permissions`, `admin_user_roles` tables
- `has_admin_permission(user_id, permission_code)` function
- 6 admin RPCs implemented: `rpc_admin_kpis_overview`, `rpc_admin_top_events`, `rpc_admin_doctor_metrics`, `rpc_admin_partner_metrics`, `rpc_admin_user_journey`, `rpc_admin_event_search`
- 8 pre-seeded roles: `super_admin`, `analytics_viewer`, `support_agent`, `marketing_analyst`, `partner_manager`, `content_editor`, `data_analyst`, `medical_reviewer`
- 15 pre-seeded permission codes

See [`docs/launch/04c-rbac-roles.md`](docs/launch/04c-rbac-roles.md) and [`docs/launch/04b-admin-rpcs.md`](docs/launch/04b-admin-rpcs.md) for the existing contract.

### Backend: what needs to be added

For the V2 subscription work + new admin domains, the following must be created. Detail in §7.

**New permission codes (~30):**
- `admin.subscription.*` family (read, edit, activate_paid, gift_comp, modules.write, extras.write)
- `admin.doctor.*` family (read, write, verify, deactivate)
- `admin.patient.*` family (read, write, merge)
- `admin.payment.*` family (read, confirm)
- `admin.team.*` family (read, write)
- `admin.audit.read`
- `admin.rep.*` family (read, write, quota.write)
- `admin.support.impersonate`
- `admin.system.read` (monitoring)
- `admin.system.write` (cron triggers, manual ops)

**New roles (2):**
- `rep` — Sales rep. Comp gifts (quota-limited), talk-to-us queue, doctor outreach. NO financial edits, NO admin user changes.
- `accountant` — Financial ops. Confirm payments, edit paid_until, generate reports. NO doctor account edits.

**New admin RPCs (~25):**
- `rpc_admin_doctor_search`
- `rpc_admin_subscription_get` (full state for a doctor)
- `rpc_admin_subscription_activate` (atomic plan activation with audit)
- `rpc_admin_subscription_edit_capacity`
- `rpc_admin_subscription_set_paid_until`
- `rpc_admin_subscription_module_grant`
- `rpc_admin_subscription_module_revoke`
- `rpc_admin_grant_comp_presence` (wraps the existing function, audits, quota-checks)
- `rpc_admin_verification_queue_list`
- `rpc_admin_doctor_verify` (sets `verification_status='verified'`, with audit)
- `rpc_admin_doctor_reject_verification` (with reason)
- `rpc_admin_talk_to_us_queue`
- `rpc_admin_talk_to_us_resolve` (mark contacted / activate plan / dismiss)
- `rpc_admin_suspended_doctors_list`
- `rpc_admin_doctor_deactivate`
- `rpc_admin_patient_list`
- `rpc_admin_patient_merge`
- `rpc_admin_payment_log`
- `rpc_admin_revenue_report`
- `rpc_admin_catalog_plan_update`
- `rpc_admin_catalog_module_update`
- `rpc_admin_audit_log` (filtered, paginated)
- `rpc_admin_rep_performance`
- `rpc_admin_rep_quota_get` / `_set`
- `rpc_admin_system_health`

### Audit table

A new `admin_audit_log` table captures every state-changing admin action. Schema in §11.

---

## 3. RBAC — Roles, permissions, and gating

### The 10 roles (8 existing + 2 new)

| Role | Use case | Key permissions |
|---|---|---|
| **super_admin** | Founder (you) | All permissions |
| **rep** (new) | Sales reps | `admin.doctor.read`, `admin.subscription.gift_comp` (quota-limited), `admin.subscription.read`, `admin.talk_to_us.resolve` |
| **support_agent** | Customer support | `admin.doctor.read`, `admin.patient.read`, `analytics.users.read`, `admin.support.impersonate`, `admin.support.write` |
| **accountant** (new) | Finance | `admin.subscription.activate_paid`, `admin.payment.*`, `admin.subscription.set_paid_until`, `admin.financial_report.read` |
| **doctor_verifier** (renamed from medical_reviewer) | Reviews doctor licenses | `admin.doctor.verify`, `admin.doctor.read`, `admin.doctor.write` |
| **content_editor** | Banners, popups, force-update | `admin.config.read`, `admin.config.write`, `admin.marketing.*` |
| **medical_reviewer** | Medical master entry review (V1.0) | `admin.medical_master.read`, `admin.medical_master.write` |
| **marketing_analyst** | Growth | `analytics.*` (most), `admin.marketing.read` |
| **analytics_viewer** | Read-only dashboard observers (investors) | `analytics.read` only |
| **engineering** (new, restricted) | SRE / DB ops | `admin.system.*` — IP-whitelisted, super_admin must grant explicitly |

### Permission codes — full catalog

**Existing (15):** see [`docs/launch/04c-rbac-roles.md`](docs/launch/04c-rbac-roles.md).

**New (~30):**

```
admin.doctor.read              # View doctor profile, subscription, history
admin.doctor.write             # Edit doctor profile (name, photo, address, specialty)
admin.doctor.verify            # Mark verification_status='verified'/'rejected'
admin.doctor.deactivate        # Set is_active=false
admin.doctor.reactivate        # Set is_active=true

admin.patient.read             # View patient profile
admin.patient.write            # Edit patient profile
admin.patient.merge            # Merge duplicate patient records
admin.patient.deactivate       # Soft-delete patient

admin.subscription.read        # View subscription details
admin.subscription.edit        # Change plan, capacity, status (paid plans)
admin.subscription.activate_paid  # Mark paid + set paid_until
admin.subscription.gift_comp   # Call grant_complimentary_presence (rep-quota limited)
admin.subscription.set_paid_until  # Extend/shorten paid_until (accountant)
admin.subscription.modules.write   # Activate/deactivate subscription_modules
admin.subscription.extras.write    # Edit extra_doctors / extra_secretaries

admin.payment.read             # View payment log / history
admin.payment.confirm          # Mark a payment as received (records in payment_notes + audit)

admin.team.read                # View center_members (multi-doctor centers)
admin.team.write               # Add/remove members, change permissions

admin.financial_report.read    # Revenue, MRR, ARR, churn metrics

admin.audit.read               # View admin_audit_log (own actions + others)
admin.audit.read_all           # View ALL admin actions (super_admin only)

admin.rep.read                 # View rep accounts, performance
admin.rep.write                # Edit rep accounts
admin.rep.quota.write          # Set/edit comp gift quotas

admin.talk_to_us.read          # View talk-to-us intent queue
admin.talk_to_us.resolve       # Mark intent as resolved (contacted, converted, dismissed)

admin.support.impersonate      # View-as-user (read-only, audit-logged)
admin.support.write            # Modify user data on user's behalf
admin.support.password_reset   # Trigger password reset for a user

admin.system.read              # View health/monitoring dashboards
admin.system.write             # Trigger cron jobs manually, manual SQL console

admin.marketing.read           # View banner/popup/campaign list
admin.marketing.write          # CRUD banners, popups, campaigns
admin.marketing.send           # Trigger a campaign to go live (gated separately for safety)
```

### Enforcement pattern (unchanged from existing)

```sql
CREATE OR REPLACE FUNCTION public.rpc_admin_<action>(<params>)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), 'admin.<permission>') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  -- ... action ...
END;
$$;
```

The admin panel itself uses a single helper:

```dart
// lib/core/services/admin_rpc_service.dart
Future<T> callAdminRpc<T>(String name, [Map<String, dynamic>? params]) async {
  try {
    final result = await _client.rpc(name, params: params);
    return result as T;
  } on PostgrestException catch (e) {
    if (e.code == '42501') {
      throw const AdminForbiddenException();
    }
    rethrow;
  }
}
```

The panel calls `permissions/$uid` on login to fetch the user's permission codes and uses them to hide nav items and disable buttons. **Server-side check is the source of truth** — client checks are UX-only.

### RBAC client cache

On login, fetch once:
```dart
// Returns { permissions: ['admin.doctor.read', ...], roles: ['super_admin'] }
final perms = await callAdminRpc('rpc_admin_my_permissions');
```
Store in `AdminAuthCubit` state. Use `perms.contains('admin.doctor.write')` throughout the UI. Re-fetch on hard refresh; don't bother with realtime invalidation (admin role changes are rare).

---

## 4. Design system

### Palette (dark-first)

```
Background        #0B1416   (deep charcoal with subtle blue tint — DocSera DNA)
Surface           #141E20   (cards, panels — one shade lighter)
Surface-elevated  #1B272A   (modals, hovered rows)
Border            rgba(255,255,255,0.06)
Border-strong     rgba(255,255,255,0.12)

Text-primary      #E8EFF1
Text-secondary    #8B9FA3
Text-tertiary     #5C6F73
Text-disabled     #3D5054

Accent            #009092   (DocSera teal — unchanged)
Accent-soft       rgba(0,144,146,0.12)
Accent-hover      #00A4A7
Accent-pressed    #007377

Success           #10B981
Warning           #F59E0B
Error             #EF4444
Info              #06B6D4
Comp/gift         #E07A1F
```

### Glass usage

Reserved (~10-15% of surfaces) for these specific elements only:

- **Modals + dialogs** — `BackdropFilter(blur: 18)` over a dimmed page
- **Toasts / notifications** — glass card bottom-right, auto-dismiss
- **Quick-view drawer** — right-side doctor/patient preview slide-in
- **KPI cards on dashboards** — 4-6 max per dashboard, premium feel
- **Login / lock screen** — full-bleed dark with centered glass card
- **Command palette (Cmd+K)** — glass overlay, fast

NOT glass:
- Tables, lists, form inputs, navigation rail, page bodies, tabs

### Typography

- **Cairo** for Arabic (primary), **Inter** for English (secondary)
- Body: 14px, line-height 1.4
- Title: 16-18px bold for section headers
- Page title: 24px bold
- Compact: 12px for table cells, status pills, metadata
- All weights: 400 / 500 / 600 / 700 only

### Layout

- **Sidebar navigation** (left in RTL, right in LTR), 240px wide, dark gradient, teal accents on active item
- **Top bar**: search (Cmd+K trigger), notifications, admin user menu
- **Main content area**: max-width unconstrained, fills viewport
- **Right-side drawer**: 480px slide-in for quick previews / forms
- **Density**: 32-40px table rows (vs 48-56 in consumer apps), 12-16px padding between sections

### Animations

- Transitions: 150ms cubic-out (snappier than consumer apps' 250ms)
- Modal/drawer slide: 200ms
- Page transition: instant + fade (50ms)
- No bouncy springs anywhere
- Glass elements still fade in softly (200ms)

### Power-user features

- **Command palette (Cmd+K / Ctrl+K)**: fuzzy search across doctors, subscriptions, actions, settings. Linear-style.
- **Keyboard shortcuts**: `D` focus doctor search, `S` focus subscription search, `/` filter current table, `Esc` close modal, `?` help overlay
- **Bulk select on tables**: checkbox column, bulk actions menu
- **CSV export** on every table (gated by permission)
- **Persistent column preferences** (which columns visible, widths) — stored per-admin in localStorage

---

## 5. Hosting and deployment

### Domain
`admin.docsera.app` — separate subdomain. Nginx on the Syrian VPS routes `admin.docsera.app/*` to the static build folder. Same TLS cert (wildcard `*.docsera.app`).

### Build
```bash
flutter build web --release --base-href /
# Output: build/web/
```
- Tree-shaking enabled
- Service worker for cache invalidation
- Source maps committed for debug (admin-only, not public)

### Deploy
- Static files synced via `rsync` over SSH to `/var/www/admin.docsera.app/` on the VPS
- nginx serves with proper cache headers (immutable assets, no-cache for index.html)
- CI workflow: on tag push, build + deploy + cache-purge

### Security
- Admin route at TLD level NEVER reachable without auth (handled by login redirect)
- IP whitelist on `admin.docsera.app`? **Discuss with founder**. Recommended: no IP restriction for V0.1 (you have reps in different locations), but enforce 2FA via Supabase auth for all admin accounts.
- Content-Security-Policy headers from nginx
- HSTS, no embedding, X-Frame-Options DENY

### Monitoring
- Health endpoint `admin.docsera.app/health` returns build hash + Supabase reachability
- Sentry (or self-hosted alternative) optional in V1.5
- Audit log replaces 90% of needed observability — see §11

---

## 6. Domain — Subscription Management (THE BIG ONE)

This is the highest-value section. It replaces 100% of the SQL runbook in `docs/launch/17-subscription-v2.md`.

### 6.1 Doctor search (entry point)

**Route:** `/doctors` (lists) and `/doctors/<id>` (detail with subscription panel)

**Search UI:**
- Top: search box (debounced, server-side, full-text on `first_name`, `last_name`, `email`, `phone_number`)
- Filters: plan, status, suspended, has_modules, has_comp, has_talk_to_us_intent, verification_status
- Table columns: name, phone, email, plan badge, status badge, paid_until, modules count, last activity
- Bulk actions: export CSV, send WhatsApp (V1.5)

**RPC:** `rpc_admin_doctor_search(p_filters jsonb, p_limit int, p_offset int)`

**Permission:** `admin.doctor.read`

### 6.2 Subscription editor (the workhorse)

**Route:** `/doctors/<id>/subscription`

**Layout:**
- Top: doctor card (name, photo, phone, email, center name)
- Status panel: current plan badge, status badge, days remaining, comp flag, payment notes
- **Edit form (modal or inline)**:
  - Plan dropdown (Presence / Starter / Pro / Center)
  - Status dropdown (active / trial / grace_period / suspended / cancelled)
  - Included doctors (1-N), included secretaries (0-N)
  - Extra doctors (0-N), extra secretaries (0-N)
  - Base price (USD, auto-fills from catalog but overridable)
  - Total annual price (auto-computed or override)
  - Paid-until date picker
  - Trial-ends-at date picker (only when trial)
  - Is_promotional_pricing toggle
  - Payment notes textarea
  - Save button → calls `rpc_admin_subscription_edit`
- Module section (Starter only): per-module activate/deactivate checkbox with price
- Extras section (Center only): per-extra seat sliders
- Comp section: gift comp button → opens dialog → calls `rpc_admin_grant_comp_presence`
- History tab: shows `subscription_history` for this center

**RPCs:**
- `rpc_admin_subscription_get(p_center_id uuid)` — full state including history
- `rpc_admin_subscription_edit(p_center_id uuid, p_changes jsonb)` — atomic edit, audit-logged
- `rpc_admin_subscription_activate_paid(p_center_id uuid, p_plan plan, p_amount numeric, p_paid_until timestamptz, p_notes text)` — single button for "activate this paid plan"

**Permissions:** `admin.subscription.read`, `admin.subscription.edit`, `admin.subscription.activate_paid`

### 6.3 Verification queue

**Route:** `/verification-queue`

**Purpose:** doctors who submitted documents but haven't been reviewed.

**Query:** `doctor_verifications` rows where any of `license_status`, `id_status` are `'pending'` OR `doctors.verification_status = 'submitted'`.

**UI:**
- Table: doctor name, submitted_at, license_status, id_status
- Row action: "Review" → opens detail page
- Detail page:
  - Side-by-side: license image preview + ID image preview
  - Form fields: license verified Y/N, ID verified Y/N, rejection reason (textarea, if rejecting)
  - Buttons: "Approve all", "Reject license", "Reject ID", "Request resubmission"
  - Approve → calls `rpc_admin_doctor_verify` which:
    1. Sets `doctor_verifications.license_status = 'approved'`, etc.
    2. Sets `doctors.verification_status = 'verified'`
    3. Auto-trigger fires `subscriptions.documents_verified_at = now()` (already implemented)
    4. Logs to `admin_audit_log`

**Permissions:** `admin.doctor.verify`, `admin.doctor.read`

### 6.4 Talk-to-us queue

**Route:** `/talk-to-us`

**Purpose:** rep follow-up queue. Doctors who tapped the "Talk to us" card on the plan_choice screen.

**Query:** subscriptions where `talk_to_us_intent_at IS NOT NULL` ordered most-recent first.

**UI:**
- Table: doctor name, phone, email, intent_at, days since intent, current status
- Row actions:
  - **WhatsApp** — opens `https://wa.me/<phone>?text=...`
  - **Activate plan** — opens subscription editor with the doctor pre-filled
  - **Gift comp** — opens comp dialog
  - **Mark as contacted** — sets a `last_rep_touch_at` column (new), keeps in queue
  - **Dismiss** — sets `talk_to_us_intent_at = NULL`

**RPCs:**
- `rpc_admin_talk_to_us_queue(p_status text, p_limit int)` — pending / contacted / resolved
- `rpc_admin_talk_to_us_resolve(p_subscription_id uuid, p_action text, p_notes text)`

**Permission:** `admin.talk_to_us.read` + `admin.talk_to_us.resolve`

**Schema change needed:** add `last_rep_touch_at TIMESTAMPTZ` to `subscriptions`.

### 6.5 Comp gift flow

**Trigger from:** doctor detail, talk-to-us queue, or standalone "Gift comp" button.

**UI dialog (glass modal):**
- Doctor name (read-only)
- Reason dropdown: `rep_outreach`, `launch_promo`, `vip_doctor`, `partner`, `other` (with text field if `other`)
- Comp duration: 6 months / 12 months / custom date picker (default: 12 months)
- Notes textarea
- Submit → calls `rpc_admin_grant_comp_presence`
- Quota check: rep role has a quota (`rep_comp_quota` table — V1.0). If quota exceeded, error message.

**RPC:** `rpc_admin_grant_comp_presence(p_center_id uuid, p_reason text, p_expires_at timestamptz, p_notes text)` — wraps the existing `grant_complimentary_presence` function with audit + quota.

**Permission:** `admin.subscription.gift_comp`

### 6.6 Suspended doctors list

**Route:** `/suspended`

**Purpose:** doctors currently in `suspended` status. Reactivation candidates.

**UI:**
- Table: doctor name, plan, suspended_since, reason (trial ended / comp expired / cancelled), prior tier
- Row action: "Reactivate" — opens subscription editor

**RPC:** `rpc_admin_suspended_doctors_list()`

**Permission:** `admin.doctor.read` + `admin.subscription.read`

### 6.7 Trial cliff dashboard

**Route:** `/trial-cliff`

**Purpose:** doctors whose Pro Trial ends in the next 7 / 14 / 30 days. High-conversion opportunity.

**UI:**
- 3 tabs: "Next 7 days", "Next 14 days", "Next 30 days"
- Table per tab: doctor, trial_ends_at, days remaining, signup date, app activity (engagement score from analytics)
- Row actions: WhatsApp, Activate paid plan, Extend trial

**RPC:** `rpc_admin_trial_cliff(p_days int)`

**Permission:** `admin.subscription.read`

### 6.8 Subscription history viewer

For any doctor, view the full audit trail of subscription changes from `subscription_history` table. Visualised as a timeline.

---

## 7. Domain — Doctor Management

### 7.1 Doctor list

**Route:** `/doctors` (shared entry with subscription search)

Already covered in §6.1.

### 7.2 Doctor detail

**Route:** `/doctors/<id>`

**Tabs:**
- **Overview** — basic info, subscription summary, last activity
- **Profile** — full profile editing (name, photo, specialty, address, hours, services)
- **Subscription** — see §6
- **Patients** — list of patients linked to this doctor
- **Documents** — uploaded license + ID with preview
- **Activity** — from analytics, what they've done in the app
- **History** — `subscription_history` + admin actions

**RPC:** `rpc_admin_doctor_get(p_doctor_id uuid)` — bundled state

**Permission:** `admin.doctor.read`

### 7.3 Doctor deactivation

Button on doctor detail. Soft-delete (sets `is_active=false`, records reason).

**RPC:** `rpc_admin_doctor_deactivate(p_doctor_id uuid, p_reason text)`

**Permission:** `admin.doctor.deactivate`

**Effect:** doctor's profile is hidden from `public_doctors` (already filtered by `is_active` in the patient view).

### 7.4 Doctor reactivation

Inverse of deactivation. Permission: `admin.doctor.reactivate`.

---

## 8. Domain — Patient Management

### 8.1 Patient list

**Route:** `/patients`

**UI:**
- Search by phone, email, name
- Filters: connected to doctor, has appointments, blocked status
- Table: name, phone, email, signup date, last login, appointments count, blocked Y/N

**RPC:** `rpc_admin_patient_list(p_filters jsonb, p_limit int, p_offset int)`

**Permission:** `admin.patient.read`

### 8.2 Patient detail

**Route:** `/patients/<id>`

**Tabs:** Overview, Medical history (read-only — sensitive), Appointments, Documents, Devices, Audit

**Permission:** `admin.patient.read`

### 8.3 Patient merge (duplicates)

Two patient records that represent the same person. Admin selects "canonical" record; the other is merged into it. All foreign keys (appointments, conversations, etc.) updated to point at canonical. Duplicate is soft-deleted with `merged_into = <canonical-id>`.

**RPC:** `rpc_admin_patient_merge(p_canonical_id uuid, p_duplicate_id uuid)`

**Permission:** `admin.patient.merge`

---

## 9. Domain — Plan & Module Catalog Editor

### 9.1 Plan catalog editor

**Route:** `/catalogs/plans`

**Purpose:** edit the V2 `plan_catalog` table — change prices, capacity, trial duration, visibility.

**UI:** table of 4 plans (Presence, Starter, Pro, Center) with inline editing of:
- `base_price_usd`
- `included_doctors`, `included_secretaries`
- `extra_doctor_price_usd`, `extra_secretary_price_usd`
- `trial_days`
- `is_self_serve` (visible on plan_choice screen — Pro only currently)
- `is_visible`
- `sort_order`

**RPC:** `rpc_admin_catalog_plan_update(p_plan_key text, p_changes jsonb)`

**Permission:** `admin.catalog.write`

**Important:** existing subscription rows with `is_promotional_pricing=true` retain their original pricing — only NEW subscriptions get the new catalog prices.

### 9.2 Module catalog editor

**Route:** `/catalogs/modules`

Same pattern, for `module_catalog`. Editable fields:
- `price_usd`
- `display_name_ar`, `display_name_en`
- `description_ar`, `description_en`
- `is_starter_purchasable` (CANNOT be set to true for `marketing_gifts` — UI hard guard + RPC hard guard)
- `is_visible`
- `sort_order`

**RPC:** `rpc_admin_catalog_module_update(p_module_key text, p_changes jsonb)`

**Permission:** `admin.catalog.write`

### 9.3 Add new plans / modules (V1.5+)

Both catalogs are designed to be extensible. New plan? Insert a row. New module? Insert. The admin UI for this is V1.5 — for V0.1 / V1.0 use SQL.

---

## 10. Domain — Accounting

### 10.1 Payment ledger

**Route:** `/accounting/payments`

**Purpose:** every payment confirmation logged by the admin team.

**Schema (new table):**
```sql
CREATE TABLE admin_payments (
  id UUID PRIMARY KEY,
  subscription_id UUID REFERENCES subscriptions(id),
  doctor_id UUID REFERENCES doctors(id),
  amount_usd NUMERIC(10,2) NOT NULL,
  payment_method TEXT,             -- 'cash', 'bank_transfer', 'check', 'crypto'
  reference_number TEXT,           -- bank transfer ref, check number
  paid_at TIMESTAMPTZ NOT NULL,
  recorded_by UUID REFERENCES auth.users(id),
  recorded_at TIMESTAMPTZ DEFAULT now(),
  notes TEXT
);
```

When accountant clicks "Activate paid plan" in the subscription editor, this row is created automatically.

**Permission:** `admin.payment.read`, `admin.payment.confirm`

### 10.2 Revenue reports

**Route:** `/accounting/revenue`

**UI:**
- Top: 4 cards — MRR, ARR, paid subscriptions count, average revenue per doctor
- Period picker: month / quarter / year
- Charts: revenue trend, plan distribution, churn rate
- Per-plan breakdown table

**RPC:** `rpc_admin_revenue_report(p_period text)`

**Permission:** `admin.financial_report.read`

### 10.3 Export

Every accounting table has a CSV / Excel export button. Export captured in audit log.

---

## 11. Domain — Audit Log

### 11.1 Schema

```sql
CREATE TABLE admin_audit_log (
  id BIGSERIAL PRIMARY KEY,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_user_id UUID REFERENCES auth.users(id),
  action_code TEXT NOT NULL,          -- 'subscription.edit', 'doctor.verify', etc.
  target_type TEXT,                   -- 'doctor', 'subscription', 'patient', etc.
  target_id UUID,
  changes JSONB,                      -- before/after snapshots
  notes TEXT,
  ip_address INET,
  user_agent TEXT
);

CREATE INDEX idx_audit_log_actor ON admin_audit_log(actor_user_id, occurred_at DESC);
CREATE INDEX idx_audit_log_target ON admin_audit_log(target_type, target_id, occurred_at DESC);
CREATE INDEX idx_audit_log_action ON admin_audit_log(action_code, occurred_at DESC);
```

Every admin RPC that mutates state inserts a row.

### 11.2 Viewer

**Route:** `/audit`

**UI:**
- Filter by: actor, action_code, target_type, date range
- Table: time, actor, action, target (linked), changes diff
- Per-action detail: expandable JSON view

**RPC:** `rpc_admin_audit_log(p_filters jsonb, p_limit int)`

**Permissions:** `admin.audit.read` (own actions), `admin.audit.read_all` (super_admin only)

---

## 12. Domain — Marketing & Notifications

### 12.1 Banner / popup CRUD

Existing. Permission: `admin.config.write`. From original doc.

### 12.2 Force-update control

Existing. Permission: `admin.config.write`. From original doc.

### 12.3 Push notification campaigns (V1.0)

**Route:** `/marketing/campaigns`

**Purpose:** send a one-off push notification to a segment of users (doctors or patients).

**UI:**
- New campaign form:
  - Audience: all doctors / specific tier / all patients / segment query
  - Schedule: now / scheduled time
  - Title (AR + EN), body (AR + EN)
  - Deep link (optional)
- Preview pane
- Send button (gated by `admin.marketing.send` — separate from create)

**RPC:** `rpc_admin_campaign_create(p_payload jsonb)`, `rpc_admin_campaign_send(p_campaign_id uuid)`

**Permission:** `admin.marketing.write`, `admin.marketing.send`

### 12.4 Gift campaigns (V1.5)

Coordinated comp Presence gifts to N doctors at once. Useful for "first 50 oncologists in Damascus" or "all members of MedTech Conference 2026". Builds on §6.5 but at scale.

---

## 13. Domain — Monitoring & System Health

### 13.1 System health dashboard (V1.5)

**Route:** `/system/health`

**Widgets:**
- Database: connection count, slow query list, table sizes
- Edge functions: invocation count, error rate per function (last 24h)
- Cron jobs: last run + next run for every job in `cron.job`
- Auth: signup rate, OTP success rate, current sessions
- Subscriptions: trial-cliff (count expiring in next 24h), suspended count

**RPC:** `rpc_admin_system_health()`

**Permission:** `admin.system.read`

### 13.2 Manual SQL console (V1.5, restricted)

**Route:** `/system/sql`

**UI:** SQL editor + execute button. Read-only by default; write requires confirmation modal.

**Security:**
- IP-whitelisted (super_admin only)
- Every query logged to audit
- Queries > 10 seconds killed
- DDL forbidden via the panel — must use migration files

**Permission:** `admin.system.write`

### 13.3 Cron job control (V1.5)

Trigger any cron job manually. List of all scheduled jobs from `cron.job`. Click "Run now" — logs to audit.

---

## 14. Domain — Support Tools

### 14.1 View-as-user

**Purpose:** support agent can see the app from a user's perspective to debug their issue.

**Implementation:**
- Generate a one-time JWT for the target user with `view_as=true` claim
- Open patient/doctor app in a new tab with that token
- Token is restricted (read-only on all RLS-protected tables, no mutations)
- Auto-expires in 30 minutes
- Logged to audit: who viewed whom and when

**RPC:** `rpc_admin_generate_view_as_token(p_user_id uuid)`

**Permission:** `admin.support.impersonate`

### 14.2 Account recovery

Help a user who lost access (phone changed, etc.). Verify identity manually, then update phone/email.

**Permission:** `admin.support.write`

### 14.3 Password reset

Trigger a password reset email for a user.

**RPC:** `rpc_admin_trigger_password_reset(p_user_id uuid)`

**Permission:** `admin.support.password_reset`

---

## 15. Domain — Reps Management (V1.0)

### 15.1 Rep accounts

**Route:** `/reps`

**UI:**
- List of all rep accounts (filtered admin_users where roles include 'rep')
- For each rep: name, email, joined date, gifts used (this month / total), conversions, performance score

**RPC:** `rpc_admin_rep_list()`

**Permission:** `admin.rep.read`

### 15.2 Rep performance

**Route:** `/reps/<id>`

**UI:**
- KPI cards: total comp gifts, paid conversions, average days to convert, total revenue attributed
- Activity timeline: gifts given, plans activated, talk-to-us resolutions
- Period picker

**RPC:** `rpc_admin_rep_performance(p_rep_user_id uuid, p_period text)`

**Permission:** `admin.rep.read`

### 15.3 Comp quota management

**Schema (new table):**
```sql
CREATE TABLE rep_comp_quota (
  rep_user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  quota_per_month INT NOT NULL DEFAULT 10,
  used_this_month INT NOT NULL DEFAULT 0,
  last_reset_at DATE NOT NULL DEFAULT date_trunc('month', now())::date,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

UI: per-rep quota editor.

**RPC:** `rpc_admin_rep_quota_set(p_rep_user_id uuid, p_quota int)`

**Permission:** `admin.rep.quota.write` (super_admin only)

The `grant_complimentary_presence` RPC checks quota before allowing a rep's comp gift.

---

## 16. Domain — Analytics (existing + V2 additions)

Existing RPCs in [`docs/launch/04b-admin-rpcs.md`](docs/launch/04b-admin-rpcs.md):
- `rpc_admin_kpis_overview`
- `rpc_admin_top_events`
- `rpc_admin_doctor_metrics`
- `rpc_admin_partner_metrics`
- `rpc_admin_user_journey`
- `rpc_admin_event_search`

V2 additions:
- `rpc_admin_subscription_funnel(p_period)` — signup → docs verified → plan chosen → trial → paid conversion
- `rpc_admin_trial_conversion_rate(p_period)` — % of trial doctors that convert to paid
- `rpc_admin_plan_distribution()` — count by plan, snapshot
- `rpc_admin_module_attachment_rate(p_module_key)` — % of Starter doctors who buy each module
- `rpc_admin_comp_to_paid_rate(p_period)` — % of comp Presence doctors that convert to paid

Routes: `/analytics/*`

Permissions: existing `analytics.*` family.

---

## 17. Domain — Admin User Management

### 17.1 List admins

**Route:** `/admins`

**UI:** table of admin_users with their roles, status, last activity.

**RPC:** `rpc_admin_user_list()` (already exists conceptually — confirm in 04b)

**Permission:** `admin.users.read`

### 17.2 Grant / revoke roles

UI: per-admin role checklist. Click to toggle. Audit-logged.

**RPC:** `rpc_admin_user_role_grant(p_user_id uuid, p_role_code text)`, `_revoke(...)`.

**Permission:** `admin.users.write`

### 17.3 Suspend admin

Toggle `admin_users.status = 'suspended'` (existing pattern).

---

## 18. Database schema additions

Total new tables for V0.1: 1 (`admin_audit_log`). For V1.0: +3 (`admin_payments`, `rep_comp_quota`, possibly `admin_campaigns`).

New columns:
- `subscriptions.last_rep_touch_at TIMESTAMPTZ` (for talk-to-us workflow)

New RPCs: ~25 (enumerated throughout sections above).

New permission codes: ~30.

New roles: 2 (`rep`, `accountant`) plus rename existing `medical_reviewer` → `doctor_verifier` (semantically clearer; or keep both — backward-compat).

---

## 19. Security model

### Authentication
- Supabase auth, same instance as the apps
- Admin status = `EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid() AND status = 'active')`
- 2FA strongly recommended for all admin accounts (TOTP via Supabase auth — V1.0)
- Session timeout: 8 hours of inactivity → re-login

### Authorization
- Every state-changing action: server-side `has_admin_permission()` check + audit log entry
- Client checks are UX only (hide buttons), never security
- Forbidden errors (42501) show a friendly "you don't have access" page

### Audit
- Every RPC that mutates state writes to `admin_audit_log`
- Immutable — admins cannot delete audit rows
- Super_admin can view all; others see only own actions

### Network
- HTTPS only via nginx + Let's Encrypt
- HSTS, CSP, X-Frame-Options DENY
- Rate limiting on the auth endpoint (Supabase built-in)
- Manual SQL console additionally IP-whitelisted (V1.5)

### Sensitive operations require confirmation modal
- Doctor deactivation
- Plan downgrade
- Comp gift > 12 months
- Force-update version bump (affects all users)
- Bulk operations (>10 records)

---

## 20. Performance requirements

**Page load:** < 1.5s on a 4G connection from Damascus.

**Table render:** < 100ms for tables up to 500 rows. Server-side pagination beyond.

**Search:** debounced 300ms, server-side index-backed, < 200ms median response.

**Modal open:** < 50ms.

**Real-time updates:** none in V0.1. V1.0 adds Supabase Realtime for the verification queue + talk-to-us queue.

---

## 21. Testing strategy

- **Unit tests:** business logic in cubits, RBAC client cache, formatters
- **Widget tests:** every form component, the design system primitives
- **Integration tests:** the critical happy paths (login → search doctor → activate plan → audit log entry)
- **Manual QA checklist:** every domain has a manual smoke test that the admin performs before V0.1 → V1.0 cut-over
- Target test coverage: 60% for V0.1, 80% for V1.0

---

## 22. CI/CD

GitHub Actions workflow:
- On push to main: analyze + test + build web
- On tag: build + deploy to VPS via rsync over SSH
- Cache invalidation on deploy
- Slack notification on deploy success/failure

Free-tier budget: ~5 minutes per build × 30 builds/month = 150 minutes. Well within free tier.

---

## 23. Known follow-ups (not in V1.0)

- **Multi-tenancy** — if you expand to other regions or white-label
- **Payment processor integration** — when Stripe / Paymob / etc. land in Syria
- **Public partner API** — for clinic management software integrations
- **Mobile admin app** — Flutter shared code → iOS/Android admin app for on-the-go ops (probably never needed; web is fine)
- **AI assistance** — natural language commands ("activate Pro for Dr. Khalil with payment notes 'cash, July rent'")
- **Document OCR for verification** — auto-extract license info from images

---

## 24. Bootstrap (the first super_admin)

Before the panel is usable, the founder must be in `admin_users` with `super_admin` role. Already documented in `docs/launch/04c-rbac-roles.md` § "Grant a user super_admin":

```sql
INSERT INTO public.admin_users (user_id, status, notes)
VALUES ('<founder-uuid>', 'active', 'Founder');

INSERT INTO public.admin_user_roles (user_id, role_code, granted_by)
VALUES ('<founder-uuid>', 'super_admin', '<founder-uuid>');
```

Once the panel ships, this becomes a one-click in V1.0's admin user management UI.

---

## 25. Open questions for the founder

(To be resolved before final V0.1 spec is locked.)

1. **2FA:** mandatory for all admins from day one, or V1.0?
2. **IP whitelisting:** off entirely, or required for super_admin / SRE roles?
3. **Audit retention:** 1 year? 3 years? Indefinitely? (Implications for table size and ministry compliance.)
4. **Backup access:** does the admin panel need a "download full DB snapshot" button (for ministry compliance)? If yes, V1.0 priority.
5. **Translation management:** is ARB-only editing OK for V0.1, or do we need a DB-backed content editor with versioning?

---

**End of comprehensive requirements doc. The implementer should next read the foundation plan at `DocSera-Pro/docs/superpowers/plans/2026-05-12-admin-panel-foundation.md` for the phased build sequence.**
