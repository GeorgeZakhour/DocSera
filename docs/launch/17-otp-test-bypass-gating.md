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

## Toggling on the production VPS

There is no separate dev / staging environment for DocSera — there's
only the one production VPS (94.252.183.77). To test the auth flow
without burning real SMS / email, the team toggles the bypass ON
briefly, runs the test, then toggles it OFF again.

A toggle script lives at `/home/george/scripts/otp_test` on the VPS.
It edits the docker-compose `.env` file (adds or removes the
`ALLOW_TEST_OTP=true` line) and recreates the `supabase-edge-functions`
container so the new value takes effect.

### Usage

```bash
# Check current state — always run this first / last
~/scripts/otp_test status

# Enable bypass (writes ALLOW_TEST_OTP=true to .env, recreates container)
~/scripts/otp_test on

# Disable bypass (removes the line, recreates container)
~/scripts/otp_test off

# Enable + auto-disable after 30 minutes (uses `at` if installed)
~/scripts/otp_test on 30
```

`on` prints a big warning so the operator can't miss that production
is in a bypass-active state. `status` is safe to run anytime; `off`
is idempotent.

### Compose change that makes the toggle work

`docker-compose.yml` (the supabase one at
`/data/supabase/docker/supabase/docker/`) declares the env var on the
`functions` service with a default of empty:

```yaml
ALLOW_TEST_OTP: "${ALLOW_TEST_OTP:-}"
```

The actual value comes from the `.env` file in the same directory. The
toggle script writes / removes `ALLOW_TEST_OTP=true` in that `.env`.
A backup of the original compose lives at
`docker-compose.yml.before-allow-test-otp-2026-05-10.bak`.

### Hard rule

After every short testing session, `~/scripts/otp_test off`. Verify with
`~/scripts/otp_test status`. The `on N` form with a self-disable timer
exists specifically to prevent forgotten-toggle situations — use it
when you're not sure how long you'll need.

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
