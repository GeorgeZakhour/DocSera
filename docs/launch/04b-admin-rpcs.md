# 04b — Admin RPCs (the admin panel API)

This is the contract between the future admin panel and the analytics backend. The admin panel **never writes raw SQL** — it calls these RPCs and renders the JSON they return.

All RPCs are `SECURITY DEFINER` and gate on `has_admin_permission(auth.uid(), '<code>')`. Unauthorized callers get a `42501 forbidden` error.

## Calling an RPC from Flutter

```dart
final json = await Supabase.instance.client.rpc(
  'rpc_admin_kpis_overview',
  params: {'p_period': '7d'},
);
// json is a Map<String, dynamic>
```

Errors surface as `PostgrestException` — wrap in try/catch and check `code == '42501'` for "forbidden" (user lacks the permission).

---

## `rpc_admin_kpis_overview(p_period text)`

**Permission:** `analytics.read`

**Purpose:** Top-level dashboard. Single JSON object with the most-watched product KPIs.

**Parameters:**
- `p_period` — `'24h'` / `'7d'` / `'30d'` / `'90d'`. Defaults to `'7d'`.

**Returns:**
```json
{
  "period": "7d",
  "active_users": 4210,
  "sessions": 11_582,
  "avg_session_duration_seconds": 184.3,
  "signups": 312,
  "logins": 8021,
  "bookings_started": 1502,
  "bookings_confirmed": 678,
  "booking_conversion_pct": 45.1,
  "otp_success_pct": 92.4
}
```

**UI rendering (admin panel home):** 8 cards (one per metric). Show the absolute number large, with the period as a subtitle. Optionally: trend indicator vs. previous period (compute by calling twice).

---

## `rpc_admin_top_events(p_period text, p_limit int)`

**Permission:** `analytics.read`

**Purpose:** Most-fired events with unique-user counts. Useful for "what are users actually doing?"

**Parameters:**
- `p_period` — `'24h'` / `'7d'` / `'30d'`. Defaults to `'7d'`.
- `p_limit` — max rows. Defaults to `50`.

**Returns:**
```json
[
  {"event_name": "screen_viewed", "category": "app", "occurrences": 41_283, "unique_users": 4210},
  {"event_name": "doctor_profile_viewed", "category": "doctor", "occurrences": 8201, "unique_users": 3104},
  {"event_name": "booking_confirmed", "category": "booking", "occurrences": 678, "unique_users": 612},
  ...
]
```

**UI rendering:** sortable table, with a search/filter on event_name.

---

## `rpc_admin_doctor_metrics(p_doctor_id uuid, p_period text)`

**Permission:** `analytics.doctors.read`

**Purpose:** Per-doctor performance dashboard. Powers the "How many people viewed Dr. X?" question.

**Parameters:**
- `p_doctor_id` — UUID of the doctor.
- `p_period` — `'7d'` / `'30d'` / `'90d'`. Defaults to `'30d'`.

**Returns:**
```json
{
  "doctor_id": "8f3a-...",
  "period": "30d",
  "profile_views": 824,
  "unique_viewers": 502,
  "phone_clicks": 73,
  "address_clicks": 41,
  "shares": 18,
  "favorites": 56,
  "booking_starts": 102,
  "booking_confirms": 67
}
```

**UI rendering (doctor detail page in admin panel):** A card grid showing each metric. Below: a sparkline trend (compute by calling with smaller windows: '7d', '14d-7d', etc.).

---

## `rpc_admin_partner_metrics(p_partner_id uuid, p_period text)`

**Permission:** `analytics.partners.read`

**Purpose:** Per-partner dashboard.

**Parameters:**
- `p_partner_id` — UUID of the partner.
- `p_period` — `'7d'` / `'30d'` / `'90d'`. Defaults to `'30d'`.

**Returns:**
```json
{
  "partner_id": "5c1b-...",
  "period": "30d",
  "profile_views": 1402,
  "unique_viewers": 893,
  "phone_clicks": 51,
  "address_clicks": 37,
  "offer_views": 4503,
  "offer_clicks": 712,
  "voucher_redemptions": 89
}
```

**UI rendering:** same shape as doctor metrics. Useful for partner billing/reporting.

---

## `rpc_admin_user_journey(p_user_id uuid, p_limit int)`

**Permission:** `analytics.users.read`

**Purpose:** Every event a single user fired, in reverse chronological order. For support: "User X says checkout is broken — show me what they did."

**Parameters:**
- `p_user_id` — UUID of the user.
- `p_limit` — max events. Defaults to `200`.

**Returns:**
```json
[
  {
    "occurred_at": "2026-05-04T12:31:08Z",
    "event_name": "booking_failed",
    "category": "booking",
    "screen": "/appointment/confirm",
    "properties": {"doctor_id": "...", "error_code": "slot_already_booked"},
    "app_version": "1.0.0+17",
    "platform": "ios",
    "session_id": "..."
  },
  {
    "occurred_at": "2026-05-04T12:31:01Z",
    "event_name": "booking_slot_picked",
    ...
  },
  ...
]
```

**UI rendering:** a vertical timeline. Color-code by category. Allow expanding a row to see full `properties`. Filter by date range.

---

## `rpc_admin_event_search(p_filters jsonb, p_limit int)`

**Permission:** `analytics.events.read`

**Purpose:** Generic event explorer. The "PostHog-like" raw event browser.

**Parameters:**
- `p_filters` — JSONB with optional keys:
  - `event_name` — exact match
  - `category` — exact match
  - `user_id` — UUID, exact match
  - `platform` — `'ios'` / `'android'`
  - `since` — ISO timestamp lower bound (inclusive)
  - `until` — ISO timestamp upper bound (exclusive)
- `p_limit` — capped at 1000.

**Returns:** array of event objects, same shape as `rpc_admin_user_journey` but with `user_id` and `anonymous_id` fields included.

**UI rendering:** a filterable table. Add inputs for each filter key. Pagination via shifting `until` to the oldest `occurred_at` in the previous page.

---

## Funnel and retention RPCs (Stage 4 — coming next)

The following are planned but not yet implemented. They'll follow the same shape as the above.

- `rpc_admin_funnel(p_funnel_name text, p_period text)` — generic funnel. Pre-defined named funnels: `signup`, `booking`, `loyalty_redemption`. Returns step-by-step counts with conversion %.
- `rpc_admin_retention(p_cohort_period text)` — retention cohort table (D1, D7, D30 retention by signup week).
- `rpc_admin_screen_flow(p_period text, p_from_screen text)` — most common next-screen after a given screen. Powers "where do users go from the home tab?"

---

## Pattern for adding a new admin RPC

```sql
CREATE OR REPLACE FUNCTION public.rpc_admin_<name>(<params>)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.has_admin_permission(auth.uid(), '<permission.code>') THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  -- Compute v_result here.

  RETURN v_result;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_<name>(<param-types>) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_admin_<name>(<param-types>) TO authenticated;
```

Three rules: gate on a permission, return JSONB, mark `STABLE` (allows query optimizer to cache).

## Error handling at the admin panel layer

Every RPC can return:
- A successful JSONB payload (200 OK).
- `42501 forbidden` if the user lacks the required permission.
- Postgres exceptions (timeouts, internal errors) — surface as 500.

The admin panel should display a friendly error for `forbidden` (showing the user a "you don't have access" page) and a generic "something went wrong" for everything else.
