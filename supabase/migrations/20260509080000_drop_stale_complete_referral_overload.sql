-- Drop the stale `complete_referral(uuid, text, text, text)` overload.
--
-- Background:
--   Two overloads of `public.complete_referral` exist in production with the
--   same parameter names but different positional orderings:
--     1) (p_referral_code text, p_referred_user_id uuid, p_referred_phone text, p_device_id text)  -- correct, matches current schema
--     2) (p_referred_user_id uuid, p_referred_phone text, p_device_id text, p_referral_code text)  -- stale, references columns
--        (`referrals.referred_id`, `referrals.points_awarded`) that do not exist in the live schema
--
-- The Flutter client calls this RPC via PostgREST with named arguments. Because both
-- overloads share the same argument-name set, Postgres cannot disambiguate and returns
-- "function complete_referral(...) is not unique". The Dart caller in
-- `lib/screens/auth/sign_up/recap_info.dart` swallows the error (non-blocking), so signup
-- completes but no referral row, points entries, or phone burn is recorded.
--
-- Overload 2 was never applied via a checked-in migration (likely an ad-hoc psql apply
-- that drifted from the schema). Dropping it restores unambiguous resolution and the
-- working April 2026 behavior.

DROP FUNCTION IF EXISTS public.complete_referral(uuid, text, text, text);
