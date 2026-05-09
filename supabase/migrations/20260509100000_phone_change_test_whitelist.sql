-- Add test-phone whitelist to the patient-app phone-change flow so it
-- behaves the same way as the cross-app send_sms_otp edge function:
-- the small set of internal test numbers (00963900000001..13) accept
-- "123456" as the OTP without consulting the public.otp table.
--
-- Why: the patient app's "Account → contact info → phone" flow goes
-- through rpc_request_phone_change + rpc_verify_phone_otp(e164, p_otp),
-- not through the cross-app send_sms_otp edge function. So the whitelist
-- shipped in send_sms_otp/index.ts didn't apply here. End result: a
-- tester typing 0900000009 + 123456 got "wrong OTP" because the actual
-- generated value was a random 6-digit code in public.otp.
--
-- This is a temporary dev/test bypass. The "(test_otp_bypasses)" memory
-- on the agent's side flags it for purge before public launch — search
-- "TEST_PHONES" / "DEV_TEST_OTP" to find every site.

CREATE OR REPLACE FUNCTION public.rpc_verify_phone_otp(e164 text, p_otp text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_e164    text;
  v_test_phones text[] := ARRAY[
    '00963977557755',
    '00963900000001','00963900000002','00963900000003',
    '00963900000004','00963900000005','00963900000006',
    '00963900000007','00963900000008','00963900000009',
    '00963900000010','00963900000011','00963900000012',
    '00963900000013'
  ];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  -- Normalize input phone for whitelist comparison. The patient app may
  -- pass either "0900000009" or "+963900000009" or "00963900000009"; we
  -- only want to accept the bypass when the canonical form matches an
  -- entry in v_test_phones.
  v_e164 := trim(coalesce(e164, ''));
  IF v_e164 LIKE '+963%' THEN
    v_e164 := '00963' || substring(v_e164 from 5);
  ELSIF v_e164 LIKE '09%' THEN
    v_e164 := '00963' || substring(v_e164 from 2);
  ELSIF v_e164 LIKE '9%' AND v_e164 NOT LIKE '00963%' THEN
    v_e164 := '00963' || v_e164;
  END IF;

  -- DEV bypass: if this is a test phone and the code is "123456", accept
  -- without touching public.otp. Same set used by the send_sms_otp edge
  -- function (see supabase/functions/send_sms_otp/index.ts).
  IF v_e164 = ANY(v_test_phones) AND p_otp = '123456' THEN
    UPDATE public.users
       SET phone_number   = e164,
           phone_verified = true,
           updated_at     = now()
     WHERE id = v_user_id;
    -- Don't blow up if there happens to be a stale row.
    DELETE FROM public.otp WHERE phone = e164;
    RETURN;
  END IF;

  -- Real path: consult public.otp.
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
