# 04d — Sample SQL Queries

Copy-paste-ready queries for ad-hoc analysis from Supabase Studio. Every question you'll have in the first month is probably here.

Run them as `postgres` or `supabase_admin` in Supabase Studio's SQL editor. Once the admin panel exists, most of these become RPC calls instead.

## The basics

### How many active users today / this week?
```sql
SELECT * FROM v_dau LIMIT 30;     -- last 30 days
SELECT * FROM v_wau LIMIT 12;     -- last 12 weeks
SELECT * FROM v_mau LIMIT 24;     -- last 24 months
```

### Top events
```sql
SELECT * FROM v_top_events_24h LIMIT 20;
SELECT * FROM v_top_events_7d  LIMIT 30;
SELECT * FROM v_top_events_30d LIMIT 50;
```

### KPI overview (admin-only — must be signed in as super_admin)
```sql
SELECT public.rpc_admin_kpis_overview('7d');
SELECT public.rpc_admin_kpis_overview('30d');
```

## Booking funnel

### Step-by-step counts (last 7 days)
```sql
SELECT
  event_name,
  COUNT(*)        AS occurrences,
  COUNT(DISTINCT user_id) AS unique_users
FROM analytics_events
WHERE occurred_at > now() - interval '7 days'
  AND event_name IN (
    'search_started', 'doctor_profile_viewed',
    'booking_started', 'booking_slot_picked',
    'booking_confirmed', 'booking_failed', 'booking_abandoned'
  )
GROUP BY 1
ORDER BY array_position(ARRAY[
  'search_started','doctor_profile_viewed','booking_started',
  'booking_slot_picked','booking_confirmed','booking_failed','booking_abandoned'], event_name);
```

### Conversion % at each step
```sql
WITH counts AS (
  SELECT event_name, COUNT(DISTINCT user_id) AS users
  FROM analytics_events
  WHERE occurred_at > now() - interval '7 days'
    AND event_name IN ('search_started','booking_started','booking_confirmed')
  GROUP BY 1
)
SELECT
  (SELECT users FROM counts WHERE event_name='search_started')   AS searched,
  (SELECT users FROM counts WHERE event_name='booking_started')  AS started_booking,
  (SELECT users FROM counts WHERE event_name='booking_confirmed')AS confirmed,
  ROUND(100.0 * (SELECT users FROM counts WHERE event_name='booking_started')
              / NULLIF((SELECT users FROM counts WHERE event_name='search_started'), 0), 1) AS pct_search_to_book,
  ROUND(100.0 * (SELECT users FROM counts WHERE event_name='booking_confirmed')
              / NULLIF((SELECT users FROM counts WHERE event_name='booking_started'), 0), 1) AS pct_book_to_confirm;
```

## Doctor performance

### Most-viewed doctors (last 30 days)
```sql
SELECT * FROM v_doctor_profile_views_30d LIMIT 50;
```

### Drill into one doctor
```sql
SELECT public.rpc_admin_doctor_metrics('<doctor-uuid>'::uuid, '30d');
```

### Doctors with the highest booking conversion
```sql
SELECT
  properties->>'doctor_id' AS doctor_id,
  COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed') AS views,
  COUNT(*) FILTER (WHERE event_name='booking_confirmed')      AS confirms,
  ROUND(100.0 * COUNT(*) FILTER (WHERE event_name='booking_confirmed')::numeric
              / NULLIF(COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed'), 0), 1) AS conversion_pct
FROM analytics_events
WHERE occurred_at > now() - interval '30 days'
  AND properties ? 'doctor_id'
  AND event_name IN ('doctor_profile_viewed', 'booking_confirmed')
GROUP BY 1
HAVING COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed') >= 10
ORDER BY conversion_pct DESC NULLS LAST
LIMIT 20;
```

### Phone-click rate per doctor (marketing signal — what % of viewers want to call)
```sql
SELECT
  properties->>'doctor_id' AS doctor_id,
  COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed') AS views,
  COUNT(*) FILTER (WHERE event_name='doctor_phone_clicked')  AS phone_clicks,
  ROUND(100.0 * COUNT(*) FILTER (WHERE event_name='doctor_phone_clicked')::numeric
              / NULLIF(COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed'), 0), 1) AS phone_click_pct
FROM analytics_events
WHERE occurred_at > now() - interval '30 days'
  AND properties ? 'doctor_id'
  AND event_name IN ('doctor_profile_viewed', 'doctor_phone_clicked')
GROUP BY 1
HAVING COUNT(*) FILTER (WHERE event_name='doctor_profile_viewed') >= 10
ORDER BY phone_click_pct DESC NULLS LAST
LIMIT 20;
```

## Loyalty / partners / offers

### Most-viewed partners (last 30 days)
```sql
SELECT * FROM v_partner_profile_views_30d LIMIT 50;
```

### Per-offer performance (impressions → clicks → redemptions)
```sql
SELECT * FROM v_offer_views_30d LIMIT 50;
```

### Drill into one partner
```sql
SELECT public.rpc_admin_partner_metrics('<partner-uuid>'::uuid, '30d');
```

### Voucher redemption rate
```sql
SELECT
  date_trunc('week', occurred_at)::date AS week,
  COUNT(*) FILTER (WHERE event_name='voucher_received') AS issued,
  COUNT(*) FILTER (WHERE event_name='voucher_used')     AS used,
  ROUND(100.0 * COUNT(*) FILTER (WHERE event_name='voucher_used')::numeric
              / NULLIF(COUNT(*) FILTER (WHERE event_name='voucher_received'), 0), 1) AS used_pct
FROM analytics_events
WHERE occurred_at > now() - interval '12 weeks'
  AND event_name IN ('voucher_received', 'voucher_used')
GROUP BY 1
ORDER BY 1 DESC;
```

## Auth & OTP

### OTP success rate by channel and platform (last 7 days)
```sql
SELECT * FROM v_otp_success_rate_7d;
```

### Where OTP fails most
```sql
SELECT
  properties->>'channel'    AS channel,
  platform,
  app_version,
  properties->>'error_code' AS error_code,
  COUNT(*) AS failures
FROM analytics_events
WHERE occurred_at > now() - interval '7 days'
  AND event_name = 'otp_failed'
GROUP BY 1, 2, 3, 4
ORDER BY failures DESC
LIMIT 20;
```

## App-version distribution

### Who's running which version?
```sql
SELECT * FROM v_app_version_distribution;
```

This view powers the forced-update decision: if a version has a security bug and ≤5% of users are on it, raise the minimum.

## Engagement & retention

### DAU / WAU / MAU ratios (stickiness indicator — DAU/MAU > 20% is healthy for a healthtech app)
```sql
WITH d AS (SELECT MAX(active_users) AS dau FROM v_dau WHERE day = current_date),
     w AS (SELECT MAX(active_users) AS wau FROM v_wau WHERE week = date_trunc('week', current_date)::date),
     m AS (SELECT MAX(active_users) AS mau FROM v_mau WHERE month = date_trunc('month', current_date)::date)
SELECT d.dau, w.wau, m.mau,
       ROUND(100.0 * d.dau / NULLIF(m.mau, 0), 1) AS dau_mau_pct,
       ROUND(100.0 * d.dau / NULLIF(w.wau, 0), 1) AS dau_wau_pct
FROM d, w, m;
```

### Sessions per user (last 30 days)
```sql
SELECT
  user_id,
  COUNT(*) AS sessions,
  ROUND(AVG(duration_ms)/1000.0, 1) AS avg_session_seconds,
  MIN(started_at) AS first_session,
  MAX(started_at) AS last_session
FROM analytics_sessions
WHERE started_at > now() - interval '30 days'
  AND user_id IS NOT NULL
GROUP BY 1
ORDER BY sessions DESC
LIMIT 50;
```

## Per-user investigations (support)

### Show me a user's recent activity
```sql
SELECT public.rpc_admin_user_journey('<user-uuid>'::uuid, 200);
```

Or a raw query if you don't have the admin role yet:
```sql
SELECT occurred_at, event_name, category, screen, properties
FROM analytics_events
WHERE user_id = '<user-uuid>'::uuid
ORDER BY occurred_at DESC
LIMIT 200;
```

### Find users who hit a specific error in the last 24h
```sql
SELECT user_id, COUNT(*) AS error_count, max(occurred_at) AS last_seen
FROM analytics_events
WHERE event_name = 'booking_failed'
  AND occurred_at > now() - interval '24 hours'
  AND user_id IS NOT NULL
GROUP BY 1
ORDER BY error_count DESC;
```

## Maintenance

### Storage growth
```sql
SELECT
  pg_size_pretty(pg_total_relation_size('public.analytics_events')) AS events_size,
  pg_size_pretty(pg_total_relation_size('public.analytics_sessions')) AS sessions_size,
  pg_size_pretty(pg_total_relation_size('public.analytics_devices')) AS devices_size,
  (SELECT COUNT(*) FROM public.analytics_events) AS event_rows,
  (SELECT COUNT(*) FROM public.analytics_sessions) AS session_rows;
```

### Run retention cleanup (deletes events > 24 months old)
```sql
SELECT public.analytics_cleanup_old_events(interval '24 months');
```

Schedule this weekly via cron from the VPS:
```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec -i supabase-db psql -U postgres -d postgres -c \
   \"SELECT public.analytics_cleanup_old_events(interval '24 months');\""
```
