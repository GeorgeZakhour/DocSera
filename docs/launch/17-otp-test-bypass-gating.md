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

---

## V2 — 2026-05-17 update

Three follow-on hardenings on top of the v1 boolean gate above. Patient
app only (DocSera-Pro unchanged for now).

### 1. `ALLOW_TEST_OTP` now accepts an ISO timestamp for auto-expiry

The boolean form still works (backwards-compatible). The new safer form
is an ISO-8601 timestamp — the bypass is active only while
`Date.now() < timestamp`, and **auto-disables** even if you forget the
toggle-off step.

| Env value | Effect |
|---|---|
| unset / `""` / `"false"` | Off |
| `"true"` | On (legacy; no auto-expiry) |
| `"2026-05-17T20:00:00Z"` (any ISO-8601 timestamp) | On until that time |
| Anything else | Off (safe failure) |

Single-command "on for 2 hours, then auto-off":

```bash
# On the VPS — generates "now + 2 hours" in ISO UTC
echo "ALLOW_TEST_OTP=$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)" \
  >> /data/supabase/docker/supabase/docker/.env
docker compose -f /data/supabase/docker/supabase/docker/docker-compose.yml \
  up -d --force-recreate functions
```

(On macOS the equivalent is `date -u -v+2H +%Y-%m-%dT%H:%M:%SZ`.)

After two hours, even without any further action, the email bypass goes
back to off — the next call to `send_email_otp` evaluates the timestamp
fresh and finds it in the past. **The auto-expiry does not need a
process restart** — it's checked per request.

The toggle script `~/scripts/otp_test on N` still works (legacy boolean
path); the timestamp form is recommended for any "I'm leaving this
running while I do other things" testing.

### 2. Phone-side bypass moved out of the public migration

The previous migration `20260509100000_phone_change_test_whitelist.sql`
hardcoded 13 test phones + the OTP value `"123456"` directly in
`rpc_verify_phone_otp`. Public source. Always on.

Two new migrations supersede it:

- [`20260517100000_test_otp_config_table.sql`](../../supabase/migrations/20260517100000_test_otp_config_table.sql) —
  creates `public._test_otp_config`, an RLS-locked single-row table
  (no anon / authenticated access; service_role + SECURITY DEFINER only).
- [`20260517100100_phone_otp_bypass_via_config.sql`](../../supabase/migrations/20260517100100_phone_otp_bypass_via_config.sql) —
  rewrites `rpc_verify_phone_otp` to read its phones / OTP / reviewer
  creds from the config table.

The config table is created **empty**. Until you populate it on the VPS,
no phone bypass exists at all. To populate:

```bash
ssh -p 2203 george@94.252.183.77

# Inside the VPS, as supabase_admin (only service_role / definer roles
# can see this table):
docker exec -i supabase-db psql -U supabase_admin -d postgres <<'SQL'
UPDATE public._test_otp_config
SET test_phones       = ARRAY[
      '00963977557755',
      '00963900000001','00963900000002','00963900000003',
      '00963900000004','00963900000005','00963900000006',
      '00963900000007','00963900000008','00963900000009',
      '00963900000010','00963900000011','00963900000012',
      '00963900000013'
    ],
    test_otp_code     = '123456',
    reviewer_phone    = '00963900000000',
    reviewer_otp_code = 'CHANGE_ME_BEFORE_REVIEW_SUBMISSION',
    updated_by        = 'admin-setup',
    updated_at        = now()
WHERE id = 1;
SELECT id, bypass_until, array_length(test_phones, 1) AS n_phones, reviewer_phone IS NOT NULL AS has_reviewer
  FROM public._test_otp_config;
SQL
```

The phones / OTPs are now on the VPS only — `git log` reveals only the
table structure, never the values.

### Phone-side: flip dev-test bypass on for 2 hours

```bash
ssh -p 2203 george@94.252.183.77
docker exec -i supabase-db psql -U supabase_admin -d postgres <<'SQL'
UPDATE public._test_otp_config
SET bypass_until = now() + interval '2 hours',
    updated_by   = 'manual',
    updated_at   = now()
WHERE id = 1;
SELECT bypass_until FROM public._test_otp_config WHERE id = 1;
SQL
```

### Phone-side: flip off immediately

```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres <<'SQL'
UPDATE public._test_otp_config
SET bypass_until = NULL,
    updated_by   = 'manual',
    updated_at   = now()
WHERE id = 1;
SQL
```

(The phone-side bypass also auto-expires when `bypass_until` is in the
past — no recreate or restart needed; it's read per call.)

### 3. Permanent reviewer-account path

App Store and Google Play both require a working demo account in their
"App access" / "Sign-In Required" sections so reviewers can sign in
without a real phone. The reviewer path is intentionally **separate
from `ALLOW_TEST_OTP`** so the dev-test bypass can be off while the
reviewer demo account still works.

Email side — set on the VPS in the same `.env` as ALLOW_TEST_OTP:

```bash
REVIEWER_EMAIL=docsera.app@gmail.com
REVIEWER_EMAIL_OTP=<6-digit code you hand to reviewers>
```

Phone side — set in the config table (see populate command above):

```sql
reviewer_phone     = '00963900000000'
reviewer_otp_code  = '<6-digit code you hand to reviewers>'
```

Both are always-on. Rotate after each major release (or after any
suspected leak) by updating the env var / column and recreating the
functions container.

What you put in App Store Connect → App Review Information → Sign-In Required:

```
Phone:    00963900000000
Email:    docsera.app@gmail.com
Password: <demo account password>
OTP:      837461   (sent automatically — no real SMS or email needed)

Note: This is a sandboxed demo account with synthetic data only.
```

Same content in Play Console → App content → App access.

### Migration rollout order (on the VPS)

```bash
# 1. Apply both new migrations (table first, then function recreate)
scp -P 2203 supabase/migrations/20260517100000_test_otp_config_table.sql \
   george@94.252.183.77:/tmp/m1.sql
scp -P 2203 supabase/migrations/20260517100100_phone_otp_bypass_via_config.sql \
   george@94.252.183.77:/tmp/m2.sql

ssh -p 2203 george@94.252.183.77
docker cp /tmp/m1.sql supabase-db:/tmp/m1.sql
docker cp /tmp/m2.sql supabase-db:/tmp/m2.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres \
  -v ON_ERROR_STOP=1 -f /tmp/m1.sql
docker exec -i supabase-db psql -U supabase_admin -d postgres \
  -v ON_ERROR_STOP=1 -f /tmp/m2.sql

# 2. Populate the config table (see "populate" command earlier).
# 3. Add REVIEWER_EMAIL / REVIEWER_EMAIL_OTP to the functions .env and
#    recreate the functions container.
```

Between step 1 (function recreate) and step 2 (populate), the phone
bypass is **off entirely** — the function reads an empty config and
falls through to real OTP. That's the desired fail-closed posture for
the gap.

### Old migration

[`20260509100000_phone_change_test_whitelist.sql`](../../supabase/migrations/20260509100000_phone_change_test_whitelist.sql)
remains in git history and on disk. It's already run on prod; the v2
migrations supersede the function body, so the hardcoded list is no
longer executed. No need (and no clean way) to "delete the history" —
git rewrite isn't worth it. The values are visible to anyone reading
old commits, so the rotation step in the reviewer / dev-test paths is
worth doing once the v2 deploy lands.
