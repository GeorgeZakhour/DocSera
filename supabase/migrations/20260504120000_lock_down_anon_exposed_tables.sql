-- Lock down 5 public tables that were either RLS-disabled or had anon/authenticated grants.
--
-- Audit (May 2026) showed that login_otps, email_otp, manual_patients_phone_audit,
-- doctor_storage_usage, and _secrets had RLS off. Four of them additionally granted
-- full DML (SELECT/INSERT/UPDATE/DELETE) to the anon and authenticated roles, meaning
-- any holder of the public anon key (shipped in the mobile APK) could read live OTP
-- codes and forge auth — an authentication bypass.
--
-- The Flutter clients never access these tables directly. OTP traffic goes through
-- the send_email_otp edge function and rpc_verify_email_otp / verify_login_otp RPCs,
-- which run as service_role / SECURITY DEFINER and bypass RLS. So enabling RLS with
-- zero policies (deny-all to non-service-role) is the correct lock-down and is safe
-- to apply without client changes.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. login_otps  (CRITICAL — phone OTP codes)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.login_otps FROM anon, authenticated, PUBLIC;
ALTER TABLE public.login_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_otps FORCE  ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. email_otp  (CRITICAL — email OTP codes; legacy table, still in use)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.email_otp FROM anon, authenticated, PUBLIC;
ALTER TABLE public.email_otp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_otp FORCE  ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3. manual_patients_phone_audit  (audit log — must be tamper-proof)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.manual_patients_phone_audit FROM anon, authenticated, PUBLIC;
ALTER TABLE public.manual_patients_phone_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.manual_patients_phone_audit FORCE  ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 4. doctor_storage_usage  (per-doctor quota tracking)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.doctor_storage_usage FROM anon, authenticated, PUBLIC;
ALTER TABLE public.doctor_storage_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_storage_usage FORCE  ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 5. _secrets  (already had no anon grants; enabling RLS as defense-in-depth)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public._secrets FROM anon, authenticated, PUBLIC;
ALTER TABLE public._secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._secrets FORCE  ROW LEVEL SECURITY;

COMMIT;

-- ---------------------------------------------------------------------------
-- Post-migration verification (run separately after applying):
--
--   SELECT tablename, rowsecurity,
--          (SELECT count(*) FROM pg_policies p
--             WHERE p.schemaname='public' AND p.tablename=t.tablename) AS policies
--   FROM pg_tables t
--   WHERE schemaname='public' AND rowsecurity=false;
--   -- expected: 0 rows
--
--   SELECT table_name, grantee
--   FROM information_schema.role_table_grants
--   WHERE table_schema='public'
--     AND table_name IN ('_secrets','doctor_storage_usage','email_otp',
--                        'login_otps','manual_patients_phone_audit')
--     AND grantee IN ('anon','authenticated');
--   -- expected: 0 rows
-- ---------------------------------------------------------------------------
