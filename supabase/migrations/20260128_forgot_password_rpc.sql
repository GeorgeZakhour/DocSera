CREATE OR REPLACE FUNCTION public.rpc_validate_email_otp_peek(p_email text, p_code text, p_purpose text DEFAULT 'forgot_password'::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_hash text;
begin
  v_hash := encode(digest(p_code, 'sha256'), 'hex');

  -- Check if a valid, unconsumed, non-expired OTP exists
  return exists (
    select 1
    from public.email_otps
    where
      email = lower(trim(p_email))
      and purpose = p_purpose
      and consumed_at is null
      and expires_at > now()
      and code_hash = v_hash
  );
end;
$function$
