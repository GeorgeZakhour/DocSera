-- Drop the legacy 2-arg rpc_verify_phone_otp(e164, p_otp) and the
-- legacy rpc_request_phone_change(e164) — both pre-date the
-- unified send_sms_otp + 3-arg verify path that DocSera-Pro and
-- DocSera now share.
--
-- Verified zero callers remain:
--   * DocSera/auth_repository.dart   → uses 3-arg (p_phone, p_code)
--   * DocSera/account_security_service.dart → uses 3-arg (p_phone, p_code, p_purpose)
--   * DocSera-Pro/supabase_doctor_service.dart → 3-arg
--   * DocSera-Pro/otp_step_up_page.dart → 3-arg
--
-- Dropping these is the cleanup the security review flagged:
--   1. The 2-arg form had its own TEST_PHONES bypass that was a
--      duplicate of the unified send_sms_otp whitelist.
--   2. rpc_request_phone_change generated an OTP in public.otp and
--      RETURNED it to the client (debug shortcut). Dropping it
--      eliminates the leak surface entirely.

DROP FUNCTION IF EXISTS public.rpc_verify_phone_otp(text, text);
DROP FUNCTION IF EXISTS public.rpc_request_phone_change(text);
