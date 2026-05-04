-- Per-IP rate limiting for email OTP requests.
--
-- Existing rate limit (per phone, per minute) protects a single phone from being
-- spammed. This RPC adds a complementary per-IP limit so an attacker rotating
-- phones/emails from one IP can't bypass the limit and run up our SMS bill or
-- enumerate registered numbers.
--
-- Policy: max 30 OTP requests per IP per hour. Generous enough that families
-- behind shared NAT and offices on a single IP work fine; tight enough that
-- programmatic abuse is throttled before it gets expensive.

BEGIN;

-- Re-purpose the existing otp_rate_limits table (email, ip, requested_at).
-- Add an index on (ip, requested_at) for the lookup pattern.
CREATE INDEX IF NOT EXISTS idx_otp_rate_limits_ip_requested
  ON public.otp_rate_limits (ip, requested_at DESC);

-- Aggressive housekeeping — anything older than 24h is irrelevant.
DELETE FROM public.otp_rate_limits WHERE requested_at < now() - interval '24 hours';

-- Anti-enumeration / anti-abuse RPC. Edge function calls this BEFORE issuing
-- an OTP; if it returns false, the function should refuse with 429.
CREATE OR REPLACE FUNCTION public.rpc_check_otp_ip_rate(p_email text, p_ip text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  -- Be tolerant of missing inputs — never block legitimate users due to
  -- header parsing edge cases. Empty IP just means "skip the check".
  IF p_ip IS NULL OR p_ip = '' THEN
    RETURN true;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.otp_rate_limits
  WHERE ip = p_ip
    AND requested_at > now() - interval '1 hour';

  IF v_count >= 30 THEN
    RETURN false;
  END IF;

  -- Record this request.
  INSERT INTO public.otp_rate_limits (email, ip, requested_at)
  VALUES (COALESCE(p_email, ''), p_ip, now());

  RETURN true;
END
$$;

REVOKE ALL ON FUNCTION public.rpc_check_otp_ip_rate(text, text) FROM PUBLIC;
-- Only edge functions (service_role) call this — never the client directly.
GRANT EXECUTE ON FUNCTION public.rpc_check_otp_ip_rate(text, text) TO service_role;

COMMIT;
