-- Single-row config table holding the test/reviewer OTP bypass state.
--
-- Why this exists:
--   * The dev-test bypass was previously hardcoded in
--     rpc_verify_phone_otp (see 20260509100000_phone_change_test_whitelist.sql)
--     as an always-on whitelist of 13 phones accepting "123456". That made
--     the bypass surface public on every fresh clone of the repo.
--   * The new model: the function reads phones / OTPs / reviewer creds
--     from this table at call time, and the dev-test path is only active
--     while bypass_until > now(). Secrets are populated on the VPS only,
--     never committed.
--
-- Security:
--   * RLS enabled + FORCED; no policies defined. This means anon and
--     authenticated roles have zero access. Only service_role (edge
--     functions, admin psql sessions) can read or write. Same posture
--     as _secrets / login_otps.
--   * SECURITY DEFINER functions running as supabase_admin / postgres
--     also see the row (they bypass RLS by privilege, not by policy).
--
-- Usage (run on the VPS, never commit values):
--
--   -- One-time: populate phones + reviewer creds.
--   UPDATE public._test_otp_config
--   SET test_phones      = ARRAY['00963900000001', ..., '00963900000013'],
--       test_otp_code    = '123456',
--       reviewer_phone   = '00963900000000',
--       reviewer_otp_code= '<rotate me>',
--       updated_by       = 'admin-setup',
--       updated_at       = now()
--   WHERE id = 1;
--
--   -- Flip dev-test bypass ON for 2 hours:
--   UPDATE public._test_otp_config
--   SET bypass_until = now() + interval '2 hours',
--       updated_by   = 'manual',
--       updated_at   = now()
--   WHERE id = 1;
--
--   -- Flip dev-test bypass OFF immediately:
--   UPDATE public._test_otp_config
--   SET bypass_until = NULL,
--       updated_by   = 'manual',
--       updated_at   = now()
--   WHERE id = 1;
--
-- The reviewer phone bypass is independent of bypass_until — once
-- reviewer_phone / reviewer_otp_code are populated, the configured phone
-- always accepts the configured OTP.

CREATE TABLE IF NOT EXISTS public._test_otp_config (
  id                 int PRIMARY KEY DEFAULT 1,
  bypass_until       timestamptz,
  test_phones        text[]      NOT NULL DEFAULT ARRAY[]::text[],
  test_otp_code      text        NOT NULL DEFAULT '',
  reviewer_phone     text,
  reviewer_otp_code  text,
  updated_by         text,
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (id = 1)
);

ALTER TABLE public._test_otp_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._test_otp_config FORCE ROW LEVEL SECURITY;
-- No policies = no anon/authenticated access. service_role bypasses RLS
-- by privilege; SECURITY DEFINER functions see the row via their owner.

-- Lock down direct grants too. We rely on RLS for client-side blocks,
-- but explicit REVOKE removes any inherited PUBLIC privileges.
REVOKE ALL ON TABLE public._test_otp_config FROM PUBLIC;
REVOKE ALL ON TABLE public._test_otp_config FROM anon;
REVOKE ALL ON TABLE public._test_otp_config FROM authenticated;

-- Seed the singleton row. Real values are populated on the VPS only.
INSERT INTO public._test_otp_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
