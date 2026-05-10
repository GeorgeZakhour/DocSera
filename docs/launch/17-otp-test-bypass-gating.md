# OTP Test-Bypass Gating (`ALLOW_TEST_OTP`)

**Status:** Gated. Production must run with `ALLOW_TEST_OTP` **unset**.
**Decision date:** 2026-05-10.

## What changed

Five Supabase edge functions used to accept hardcoded test codes
(`123456` and `000000`) for whitelisted phones / email domains. The
whitelists are public source code on GitHub — anyone could pick a
listed phone, type `123456`, and authenticate against a real account.

The bypasses are still useful for dev / staging (skip Mailgun & SMS
costs, deterministic E2E tests) — so they're now gated on a runtime
env var rather than removed.

## Files affected

DocSera (patient app):
- `supabase/functions/send_email_otp/index.ts`

DocSera-Pro (doctor app):
- `supabase/functions/send_doctor_otp/index.ts`
- `supabase/functions/send_sms_otp/index.ts`
- `supabase/functions/phone_otp_signup/index.ts`
- `supabase/functions/confirm_password_reset/index.ts`

Each one now starts the bypass branch with:

```ts
const allowTestOtp = Deno.env.get("ALLOW_TEST_OTP") === "true";
```

and AND's that into every `isTest…` check. Any value other than the
literal string `"true"` (including unset, `false`, `1`, `True`)
disables the bypass entirely.

## Production deployment checklist

When deploying the edge functions to the production Supabase instance,
**do NOT set `ALLOW_TEST_OTP`**. Verify with:

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-functions printenv | grep ALLOW_TEST_OTP"
```

Empty output = bypass is OFF (correct for production).

Output of `ALLOW_TEST_OTP=true` = bypass is ON. **Stop the deploy and
investigate.**

## Dev / staging deployment

For dev or staging instances where you want the bypass active (e.g.,
to run E2E tests without burning real SMS), set the env var on the
edge-functions container:

```bash
# On the dev / staging VPS:
docker exec supabase-functions \
  /bin/sh -c 'export ALLOW_TEST_OTP=true && /supabase/functions/start.sh'
```

Or persist via the Supabase project's `secrets` table /
`docker-compose.yml` `environment:` block, depending on how the
instance was provisioned.

## What still works without the bypass

- All real OTP flows: SMS via Twilio/SMS provider, email via Mailgun
- The whitelisted test phones / emails can still receive real codes
  if a real provider is configured for them — the bypass just skips
  the provider, it doesn't change which numbers can request codes
- Existing user accounts created during dev with the bypass still
  work; they authenticate against real OTPs going forward

## Rollback

If the bypass needs to be re-enabled in production for any reason
(emergency recovery, debugging), set the env var temporarily and
restart the functions. Don't edit the source to "just remove the
guard" — that's how the original problem started.

## Related

- [`05-security-review.md`](./05-security-review.md) — original audit
  that flagged this as a launch blocker
- DocSera memory: `project_test_otp_bypasses` — historical log of
  the test phone / email lists
