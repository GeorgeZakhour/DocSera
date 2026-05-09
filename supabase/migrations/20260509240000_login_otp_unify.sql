-- Unify the new-device 2FA flow with the rest of the OTP pipeline.
--
-- Before this migration:
--   * send_login_otp(phone) generated a random OTP, stored it in
--     public.login_otps, and RETURNED the code plaintext to the
--     client. It never called Syriatel. End result: real users
--     could never receive a new-device 2FA OTP, and the OTP was
--     leaked over the wire.
--   * verify_login_otp(phone, code, device_id) coupled OTP
--     verification with the trusted_devices append.
--   * The whitelist for "123456" lived in send_sms_otp (writes to
--     doctor_phone_otps) — different table, different code path.
--
-- After this migration:
--   * Client uses the unified send_sms_otp edge function with
--     purpose='login_2fa'. Real phones get Syriatel SMS, whitelisted
--     phones (00963900000001..14) accept '123456'. No OTP leaks.
--   * Client verifies with rpc_verify_phone_otp(p_phone, p_code,
--     p_purpose='login_2fa').
--   * Client trusts the device via the existing trust_current_device
--     RPC (already used by the email-OTP login path — single
--     responsibility, reused here).
--
-- public.login_otps table is left in place; operators can drop it
-- after confirming no other process references it.

DROP FUNCTION IF EXISTS public.send_login_otp(text);
DROP FUNCTION IF EXISTS public.verify_login_otp(text, text, text);
