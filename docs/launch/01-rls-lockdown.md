# 01 — RLS Lockdown on 5 Critical Tables

**Date:** 2026-05-04
**Severity closed:** 🔴 Authentication bypass
**Migration:** `supabase/migrations/20260504120000_lock_down_anon_exposed_tables.sql`

## Summary

Five public tables in the Supabase database had Row Level Security (RLS) disabled. Four of them additionally granted full read/write/delete to the `anon` and `authenticated` roles, meaning anyone holding the public anon key (which ships inside the mobile APK and can be extracted in minutes) could read live OTP codes and impersonate any user. This was an authentication bypass and is the most critical pre-launch security issue closed so far.

## What was wrong

| Table | RLS | Anon grants | Severity | Exploit |
|---|---|---|---|---|
| `login_otps` | ❌ | full DML | 🔴 Critical | Read live phone OTP codes → log in as any user |
| `email_otp` | ❌ | full DML | 🔴 Critical | Same, for email OTP |
| `manual_patients_phone_audit` | ❌ | full DML | 🟡 Medium | Read or tamper with audit log of phone changes |
| `doctor_storage_usage` | ❌ | full DML | 🟡 Medium | Lie about storage quotas; read every doctor's usage |
| `_secrets` | ❌ | (none for anon) | 🟢 Low | Not API-reachable, but RLS off as defense-in-depth gap |

## What changed

For each table, the migration:
1. `REVOKE ALL ... FROM anon, authenticated, PUBLIC` — removed API-role grants.
2. `ENABLE ROW LEVEL SECURITY` — turned RLS on.
3. `FORCE ROW LEVEL SECURITY` — even table owners obey RLS (defense against future migration mistakes).
4. **Added zero policies** — the deny-all default is intentional. These tables are accessed only by edge functions (`send_email_otp`, `cross_app_signup`, `phone_otp_signup`) and `SECURITY DEFINER` RPCs running as `service_role`, which bypasses RLS.

The migration is idempotent — re-running it is a no-op.

## How to operate it

Nothing day-to-day. The locked-down tables are invisible to clients. OTP flows continue through the existing edge functions and RPCs.

If a future feature legitimately needs anon/authenticated access to one of these tables, the right pattern is:
- Add a `SECURITY DEFINER` RPC that exposes only the necessary operation, **not** raw table access.
- Never re-grant to `anon`/`authenticated` directly.

## How to verify

Run this on the VPS at any time. Both queries must return zero rows:

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec -i supabase-db psql -U postgres -d postgres" <<'SQL'

-- Check 1: no public table has RLS disabled
SELECT tablename FROM pg_tables WHERE schemaname='public' AND rowsecurity=false;

-- Check 2: no anon/authenticated grants on the 5 locked tables
SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema='public'
  AND table_name IN ('_secrets','doctor_storage_usage','email_otp','login_otps','manual_patients_phone_audit')
  AND grantee IN ('anon','authenticated','PUBLIC');
SQL
```

## Coordination with DocSera-Pro

Verified before applying: DocSera-Pro touches `login_otps` only via two edge functions (`phone_otp_signup`, `cross_app_signup`), both initialized with `SUPABASE_SERVICE_ROLE_KEY`. Service role bypasses RLS, so DocSera-Pro is unaffected.

## What could go wrong

- **Future migrations may add new tables without RLS.** Run the verification query periodically (or during CI once that's set up) to catch regressions.
- **A migration owner mismatch** can occur — 3 of these 5 tables are owned by `supabase_admin`, not `postgres`. Migrations touching ownership/RLS on those tables must use `-U supabase_admin`. See CLAUDE.md for the apply-migration pattern.
- **A future `SECURITY DEFINER` RPC could over-expose data.** Audit any RPC that touches OTP/secret tables before merging.

## Score impact

7.2 → **8.0** (+0.8). Closing the authentication bypass was the single largest improvement available pre-launch.
