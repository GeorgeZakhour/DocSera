-- Rewrite rpc_verify_phone_otp to read its bypass configuration from
-- public._test_otp_config (added in 20260517100000) instead of carrying
-- a hardcoded whitelist + OTP string in source.
--
-- Behavioural changes vs the prior version
-- (20260509100000_phone_change_test_whitelist.sql):
--
--   1. Dev-test bypass for the configured test_phones is now GATED on
--      bypass_until > now(). If bypass_until is NULL or in the past, the
--      whitelist effectively does not exist — the real public.otp lookup
--      runs unconditionally. To enable for a window:
--
--          UPDATE public._test_otp_config
--          SET bypass_until = now() + interval '2 hours',
--              updated_by   = 'manual',
--              updated_at   = now()
--          WHERE id = 1;
--
--   2. A separate, ALWAYS-ON reviewer bypass: if the call's normalized
--      phone matches reviewer_phone AND the supplied OTP matches
--      reviewer_otp_code, the verify succeeds without touching the otp
--      table. Designed for the single demo account credential we hand
--      to App Store / Play Store reviewers in their App Review
--      Information field.
--
--   3. Phones, OTP code, and reviewer credentials are read from the
--      config table (populated on the VPS only — no values in git).
--
-- The function signature, return type, and the canonical normalization
-- of inbound phone formats are unchanged from the prior version.

CREATE OR REPLACE FUNCTION public.rpc_verify_phone_otp(e164 text, p_otp text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id        uuid := auth.uid();
  v_e164           text;
  v_cfg            public._test_otp_config%ROWTYPE;
  v_bypass_active  boolean;
  v_is_reviewer    boolean;
  v_is_test_phone  boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- Normalize input phone to canonical 00963... form so the whitelist /
  -- reviewer comparisons are consistent regardless of which surface the
  -- patient app submitted ("0900000009" vs "+963900000009" vs full).
  v_e164 := trim(coalesce(e164, ''));
  IF v_e164 LIKE '+963%' THEN
    v_e164 := '00963' || substring(v_e164 from 5);
  ELSIF v_e164 LIKE '09%' THEN
    v_e164 := '00963' || substring(v_e164 from 2);
  ELSIF v_e164 LIKE '9%' AND v_e164 NOT LIKE '00963%' THEN
    v_e164 := '00963' || v_e164;
  END IF;

  -- Load the singleton config row. If the table is empty for any
  -- reason, every bypass branch fails closed and we fall through to
  -- the real otp lookup.
  SELECT * INTO v_cfg FROM public._test_otp_config WHERE id = 1;

  v_bypass_active := v_cfg.bypass_until IS NOT NULL
                     AND v_cfg.bypass_until > now();

  v_is_reviewer   := v_cfg.reviewer_phone IS NOT NULL
                     AND v_cfg.reviewer_phone <> ''
                     AND v_e164 = v_cfg.reviewer_phone;

  v_is_test_phone := v_cfg.test_phones IS NOT NULL
                     AND v_e164 = ANY(v_cfg.test_phones);

  -- 1) Reviewer path — always on for the single configured phone + OTP.
  IF v_is_reviewer
     AND v_cfg.reviewer_otp_code IS NOT NULL
     AND v_cfg.reviewer_otp_code <> ''
     AND p_otp = v_cfg.reviewer_otp_code THEN
    UPDATE public.users
       SET phone_number   = e164,
           phone_verified = true,
           updated_at     = now()
     WHERE id = v_user_id;
    DELETE FROM public.otp WHERE phone = e164;
    RETURN;
  END IF;

  -- 2) Dev-test path — only while bypass_until is in the future.
  IF v_bypass_active
     AND v_is_test_phone
     AND v_cfg.test_otp_code IS NOT NULL
     AND v_cfg.test_otp_code <> ''
     AND p_otp = v_cfg.test_otp_code THEN
    UPDATE public.users
       SET phone_number   = e164,
           phone_verified = true,
           updated_at     = now()
     WHERE id = v_user_id;
    DELETE FROM public.otp WHERE phone = e164;
    RETURN;
  END IF;

  -- 3) Real path — consult public.otp.
  IF NOT EXISTS (
    SELECT 1 FROM public.otp
     WHERE phone = e164
       AND otp = p_otp
       AND expires_at > now()
  ) THEN
    RAISE EXCEPTION 'INVALID_OR_EXPIRED_OTP';
  END IF;

  UPDATE public.users
     SET phone_number   = e164,
         phone_verified = true,
         updated_at     = now()
   WHERE id = v_user_id;

  DELETE FROM public.otp WHERE phone = e164;
END $$;
