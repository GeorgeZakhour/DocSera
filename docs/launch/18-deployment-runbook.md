# 18 — Deployment Runbook (post-launch operations)

**Date:** 2026-05-10
**Audience:** the operator (you) when you need to ship a change, fix an outage, or roll something back without affecting users.
**Status:** 📚 Living reference — update whenever a procedure changes.

> **The mental model.** There is one production Supabase project at `https://api.docsera.app`, shared by DocSera (patient) and DocSera-Pro (doctor). Everything that protects users from a bad change happens *before* the change reaches that project. The four shields, in order:
>
> 1. **Local mirror** — test SQL/migrations on a Docker Postgres on your Mac before they ever touch the VPS.
> 2. **Backup-before-change** — take a `pg_dump` snapshot seconds before applying anything to prod.
> 3. **Staged mobile rollout** — every release goes to TestFlight Internal / Play Internal first, then 5% → 100% over 2–3 days.
> 4. **Fast rollback** — every change has a documented rollback that takes under 60 seconds.
>
> If one shield fails, the next still protects you. You don't need staging Supabase to be safe — you need these four shields to actually work. This doc is how to make them work.

---

## Verification status

A procedure marked **✅ Verified** has been run end-to-end at least once and is known to work with this exact infrastructure. A procedure marked **🟡 Untested** is documented but never executed — treat the commands as a starting point, not a guarantee. Update this table whenever you run a procedure successfully.

| Procedure | Status | Last verified | Notes |
|---|---|---|---|
| A — Mobile release | 🟡 Untested | — | — |
| B — DB migration | 🟡 Untested | — | — |
| C — Edge function deploy | 🟡 Untested | — | — |
| D — Take backup | ✅ Verified | 2026-05-10 | 6.8 MB baseline, 30 sec total |
| E — Restore backup | 🟡 Untested | — | — |
| F — Local mirror | 🟡 Untested | — | — |
| G — Full local Supabase stack | 📅 Deferred to post-launch | — | See [Procedure G](#procedure-g--full-local-supabase-stack-post-launch) |

See the [verification log](#verification-log) at the bottom of this doc for each run's command + observed output.

### Container naming quirk (this VPS)

Your VPS runs Coolify, which manages many containers with UUID-style names (e.g., `rsjhamotnbx879hhyzqqy4ja-194241317837`). **The Supabase containers are an exception** — they keep their standard names (`supabase-db`, `supabase-edge-functions`, `supabase-storage`, etc.) because they were brought up via the Supabase compose stack, not via Coolify.

Confirmed Supabase container names (as of 2026-05-10):
- `supabase-db` — Postgres 15.8.1.085 — **this is the one all DB commands target**
- `supabase-edge-functions` — Deno runtime for edge functions
- `supabase-storage` — file storage (uploaded documents)
- `supabase-auth` — gotrue (auth service)
- `supabase-kong` — API gateway
- `supabase-rest` — PostgREST
- `supabase-realtime`, `supabase-pooler`, `supabase-meta`, `supabase-studio`, `supabase-analytics`, `supabase-vector`, `supabase-imgproxy`

If you ever see "no such container: supabase-db" when running a procedure, run `ssh -p 2203 george@94.252.183.77 "docker ps | grep supabase"` to verify the container is still up and named the same way.

---

## Table of contents

1. [Daily mental model](#daily-mental-model) — the 3 categories of changes
2. [Procedure A — release a new mobile app version](#procedure-a--release-a-new-mobile-app-version)
3. [Procedure B — apply a database migration](#procedure-b--apply-a-database-migration)
4. [Procedure C — deploy an edge function](#procedure-c--deploy-an-edge-function)
5. [Procedure D — take a production backup](#procedure-d--take-a-production-backup)
6. [Procedure E — restore a backup (recovery drill)](#procedure-e--restore-a-backup-recovery-drill)
7. [Procedure F — local Postgres mirror for testing migrations](#procedure-f--local-postgres-mirror-for-testing-migrations)
8. [Procedure G — full local Supabase stack (post-launch)](#procedure-g--full-local-supabase-stack-post-launch) — the real "staging on your laptop" setup, deferred
9. [Emergency procedures](#emergency-procedures) — outages, rollbacks, halts
9. [Pre-flight checklist](#pre-flight-checklist) — run before every prod change
10. [Practice schedule](#practice-schedule) — the drills you should run monthly
11. [What we deliberately don't do (yet)](#what-we-deliberately-dont-do-yet)

---

## Daily mental model

Every change you'll make falls into one of three categories. Pick the right procedure for the category — don't mix:

| Category | Examples | Procedure | Risk to users if wrong |
|---|---|---|---|
| **Mobile-only** | UI fixes, new screens, l10n strings, business-logic in `lib/` | A | Bad UI, app crash — fixable by next release |
| **Database** | New column, new index, new RLS policy, new RPC, schema change | B | Data corruption or app-wide outage — protected by backup |
| **Edge function** | Logic in `supabase/functions/<name>/index.ts` | C | One feature breaks (OTP, email, push) — fast rollback |

**90% of post-launch work is Category A.** No database touched, no risk to user data — only risk is a bad UI release, which staged rollout protects against. Get comfortable with Procedure A first; the others are rare.

---

## Procedure A — release a new mobile app version

Use this whenever you change anything in `lib/`, `assets/`, `pubspec.yaml`, or anywhere outside `supabase/`. Both DocSera (patient) and DocSera-Pro (doctor) follow the same procedure with their own bundle IDs.

### Step 1 — verify locally

```bash
flutter analyze
flutter test
```

Both green. If either fails, fix before going further.

### Step 2 — bump the version

In `pubspec.yaml`:
```yaml
version: 1.2.3+45  # marketing-version+build-number
```

Bump the build number (`+45 → +46`) for every upload. Bump the marketing version (`1.2.3 → 1.2.4`) for user-facing releases.

### Step 3 — build signed releases

```bash
# Both platforms
./scripts/build_release.sh

# Or individually:
flutter build appbundle --release  # Android (Play Store)
flutter build ipa --release        # iOS (App Store)
```

Output:
- Android: `build/app/outputs/bundle/release/app-release.aab`
- iOS: `build/ios/ipa/Runner.ipa`

### Step 4 — upload to internal tracks

**Android (Play Console):**
1. Go to [play.google.com/console](https://play.google.com/console) → DocSera app → **Testing** → **Internal testing**
2. **Create new release** → upload the `.aab` → **Save** → **Review release** → **Start rollout to Internal testing**
3. Available to testers within ~10 minutes
4. Open the app on your phone — verify the new version actually installed (Settings → About)

**iOS (App Store Connect):**
1. Open Xcode → **Product** → **Archive**, or use Transporter to upload `Runner.ipa`
2. Wait for processing (~10–30 min — App Store Connect emails you)
3. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → DocSera app → **TestFlight**
4. Add the new build to **Internal Testing** group → testers get a push notification from the TestFlight app

### Step 5 — burn-in for 24 hours

Use the app on your own phone for at least 24 hours covering the golden paths:
- Login (phone OTP, email OTP, biometrics)
- Book an appointment, cancel one, reschedule one
- Send a message, receive a message
- Upload a document
- All of the above in Arabic and in English

Watch Sentry (`sentry.docsera.app` or wherever your project lives) — any new error types since the last release? Fix them before promoting.

### Step 6 — promote to production with staged rollout

**Android:**
- Play Console → **Production** → **Create new release** → promote the same build from Internal testing
- **Rollout percentage: 5%** initially
- Watch crash-free rate for 24 hours (Play Console → **Quality** → **Android vitals**)
- If green: ramp to 20% → 50% → 100% over 2–3 days
- If red: **halt rollout** (Procedure: Emergency / Halt rollout below)

**iOS:**
- App Store Connect → **App Store** tab → **+ Version** → upload the build → fill in "What's New" → submit for review
- Apple review takes 1–3 days
- After approval, choose **Phased Release** (default 7-day ramp: 1% → 2% → 5% → 10% → 20% → 50% → 100%)
- Apple's phased release is automatic but can be paused at any percentage

### Step 7 — tag the release in git

```bash
git tag v1.2.3
git push --tags
```

The tag triggers `.github/workflows/build.yml` automatically — verifies the build is reproducible from the tagged commit. (See [08-ci-github-actions.md](08-ci-github-actions.md).)

---

## Procedure B — apply a database migration

Use this whenever you have a new file in `supabase/migrations/`.

**The hard rule:** never run a migration on prod that you haven't run on the local mirror first, and never run one on prod without a backup taken in the last 5 minutes.

### Step 1 — write the migration

Create the file:
```
supabase/migrations/20260510120000_add_appointment_notes.sql
```

Format: `YYYYMMDDHHMMSS_description.sql`. The timestamp ordering is what determines apply-order across environments.

Inside, wrap everything in a transaction so a partial failure rolls back:
```sql
BEGIN;

ALTER TABLE appointments ADD COLUMN notes text;

COMMIT;
```

For `SECURITY DEFINER` functions, **always** include `SET search_path = public, pg_temp` (see [05-security-review.md](05-security-review.md)).

### Step 2 — test on the local mirror

(Set up the mirror once via Procedure F.)

```bash
docker exec -i docsera-test-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase/migrations/20260510120000_add_appointment_notes.sql
```

If it errors on the mirror, fix the SQL — don't ever paper over by editing prod-only. Re-run until it applies cleanly.

After applying, sanity-check the schema change is what you expected:
```bash
docker exec -i docsera-test-db psql -U postgres -d postgres \
  -c "\d appointments"
```

### Step 3 — backup prod (Procedure D)

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-db pg_dump -U postgres postgres | gzip > /tmp/backup-pre-migration-$(date +%Y%m%d-%H%M).sql.gz"
```

Note the file name — you'll need it to restore.

### Step 4 — apply to prod

Per the runbook in [CLAUDE.md](../../CLAUDE.md#applying-migrations-on-self-hosted-supabase):

```bash
# Copy migration to the VPS
scp -P 2203 supabase/migrations/20260510120000_add_appointment_notes.sql \
  george@94.252.183.77:/tmp/migration.sql

# Apply as supabase_admin (works for everything)
ssh -p 2203 george@94.252.183.77 \
  "docker cp /tmp/migration.sql supabase-db:/tmp/migration.sql && \
   docker exec -i supabase-db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f /tmp/migration.sql"
```

`-v ON_ERROR_STOP=1` aborts on the first error so a half-applied migration doesn't sneak through.

### Step 5 — verify on prod

Check the schema actually changed:
```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-db psql -U postgres -d postgres -c '\d appointments'"
```

Check the app still works — open it on your phone and exercise the affected feature.

### Step 6 — commit the migration

```bash
git add supabase/migrations/20260510120000_add_appointment_notes.sql
git commit -m "db: add appointments.notes column"
git push
```

This is essential — the file in git is the canonical record of what's deployed. Out-of-band SQL is forbidden because the next dev (or future-you) will believe git is the source of truth.

### Rollback path

If Step 5 reveals the migration broke something, immediately:

```bash
# Restore from the backup taken in Step 3
ssh -p 2203 george@94.252.183.77 \
  "gunzip < /tmp/backup-pre-migration-YYYYMMDD-HHMM.sql.gz | \
   docker exec -i supabase-db psql -U supabase_admin -d postgres"
```

This restores the entire database to its pre-migration state. Any user actions in the intervening minutes will be lost — that's the trade-off and why backups should be taken seconds before, not minutes.

For migrations that only added a column or index, a targeted rollback is faster and lossless:
```sql
ALTER TABLE appointments DROP COLUMN notes;  -- targeted reversal
```

Document the rollback SQL inside the migration file as a comment, so future-you doesn't have to reverse-engineer it under pressure.

---

## Procedure C — deploy an edge function

Use this whenever you change a file in `supabase/functions/<name>/`.

### Step 1 — test locally

```bash
supabase functions serve send_email_otp --env-file ./supabase/.env.local
```

Hit it with `curl`:
```bash
curl -X POST http://localhost:54321/functions/v1/send_email_otp \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

If it works locally, proceed.

### Step 2 — back up the currently-deployed version

Before deploying new code, snapshot what's running:
```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-edge-functions cat /home/deno/functions/send_email_otp/index.ts" \
  > /tmp/send_email_otp.previous.ts
```

Keep `/tmp/send_email_otp.previous.ts` on your laptop until the new version has been live for an hour with no errors.

### Step 3 — deploy

The exact deploy mechanism on this self-hosted Supabase is:
```bash
# Copy new function code into the edge-functions container
scp -P 2203 -r supabase/functions/send_email_otp \
  george@94.252.183.77:/tmp/send_email_otp_new

ssh -p 2203 george@94.252.183.77 \
  "docker cp /tmp/send_email_otp_new/. supabase-edge-functions:/home/deno/functions/send_email_otp/ && \
   docker restart supabase-edge-functions"
```

The container restart is fast (~5 sec). During that window, calls to *any* edge function will fail — schedule deploys for low-traffic windows if possible.

### Step 4 — smoke test

Make a real call (e.g., trigger an OTP send to a test number you control):
```bash
curl -X POST https://api.docsera.app/functions/v1/send_email_otp \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"you@yourtestdomain.com"}'
```

Check that you receive the email. If you don't, roll back immediately:

### Rollback (under 60 seconds)

```bash
scp -P 2203 /tmp/send_email_otp.previous.ts \
  george@94.252.183.77:/tmp/send_email_otp_rollback.ts

ssh -p 2203 george@94.252.183.77 \
  "docker cp /tmp/send_email_otp_rollback.ts supabase-edge-functions:/home/deno/functions/send_email_otp/index.ts && \
   docker restart supabase-edge-functions"
```

You're back on the previous version in under a minute.

---

## Procedure D — take a production backup

**Status: ✅ Verified 2026-05-10.** This is the single most important procedure in this doc. You'll run it before every migration, and on a schedule (currently manual — automation deferred).

### One-line command

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-db pg_dump -U postgres postgres | gzip > /tmp/backup-$(date +%Y%m%d-%H%M).sql.gz"
```

This produces a gzipped SQL dump of the entire database in `/tmp/` on the VPS. **Baseline size: 6.8 MB** (as of 2026-05-10, pre-launch). Will grow with real users — expect a few hundred MB at thousands of users; still small. Retention: `/tmp/` is wiped on VPS reboot — pull the file to your laptop if you need it for more than a day:

```bash
scp -P 2203 george@94.252.183.77:/tmp/backup-YYYYMMDD-HHMM.sql.gz \
  ~/docsera-backups/
```

The local backup directory is `~/docsera-backups/` (created on 2026-05-10). Each backup file is ~7 MB compressed today, so 1 GB of disk holds ~140 backups — keeping the last 30 days at one-per-day costs ~210 MB. Don't worry about disk space.

**Sanity check the size after every backup.** If it's dramatically smaller than your baseline (say <50% of last backup), the dump probably failed mid-stream — re-run before trusting it. If it's dramatically larger, it's probably fine (data grew); just note the new baseline.

### What's in the backup

- All schemas (`public`, `auth`, `storage`, etc.)
- All RLS policies
- All `SECURITY DEFINER` functions
- All data in every table

### What's NOT in the backup

- Files in Supabase Storage (the actual blobs — uploaded documents, profile pictures). These live on the VPS filesystem, not in Postgres. Backing them up is a separate procedure (deferred — see "What we deliberately don't do" below).
- Edge function code (it's in git, that's its backup).
- VPS-level config (Docker compose, nginx, env vars). Those should be in a separate ops-config repo.

### How long it takes

Taking the backup: ~10–30 seconds for a database under 1 GB.
Pulling the backup to your laptop: depends on your internet, usually under a minute.

### Verifying the backup actually works

A backup you've never restored is not a backup — it's a hope. **Run the recovery drill (Procedure E) at least once a month.**

---

## Procedure E — restore a backup (recovery drill)

Practice this **before you ever need it for real.** The first time you restore should not be during an outage.

### Restore to a local Docker Postgres (recommended for drills)

```bash
# 1. Spin up a fresh Postgres
docker run -d --name docsera-restore-test \
  -p 5434:5432 \
  -e POSTGRES_PASSWORD=test \
  postgres:15

# 2. Wait for it to be ready
sleep 5

# 3. Restore the backup into it
gunzip < ~/docsera-backups/backup-YYYYMMDD-HHMM.sql.gz | \
  docker exec -i docsera-restore-test psql -U postgres -d postgres

# 4. Verify the data is there
docker exec -i docsera-restore-test psql -U postgres -d postgres \
  -c "SELECT COUNT(*) FROM users;"

# 5. Clean up when done
docker rm -f docsera-restore-test
```

If step 4 returns a non-zero count matching your prod user count, the backup is valid.

### Restore to prod (real emergency only)

This **overwrites all data in prod with the backup.** Any writes that happened after the backup was taken are lost. Use only if data is corrupted beyond repair and the loss-window is acceptable.

```bash
# DANGER — only run this in an actual data-loss emergency
ssh -p 2203 george@94.252.183.77 \
  "gunzip < /tmp/backup-YYYYMMDD-HHMM.sql.gz | \
   docker exec -i supabase-db psql -U supabase_admin -d postgres"
```

Before running this on prod, take a *new* backup of the corrupted state first (so you can forensically inspect what went wrong even after restoring):
```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-db pg_dump -U postgres postgres | gzip > /tmp/corrupted-state-$(date +%Y%m%d-%H%M).sql.gz"
```

---

## Procedure F — local Postgres mirror for testing migrations

One-time setup. After this, you have a local copy of the prod schema that you can test any SQL against safely.

### Step 1 — pull the prod schema (no data)

```bash
ssh -p 2203 george@94.252.183.77 \
  "docker exec supabase-db pg_dump -U postgres --schema-only postgres" \
  > ~/docsera-prod-schema.sql
```

The `--schema-only` flag means structure only, no rows — safe to keep on your laptop.

### Step 2 — create the local container

```bash
docker run -d --name docsera-test-db \
  -p 5433:5432 \
  -e POSTGRES_PASSWORD=test \
  postgres:15

sleep 5

# Load the schema
docker cp ~/docsera-prod-schema.sql docsera-test-db:/tmp/schema.sql
docker exec docsera-test-db psql -U postgres -d postgres -f /tmp/schema.sql
```

(Some `auth.*` and `storage.*` schema bits will fail to load locally because they depend on Supabase-specific extensions. That's fine — your migrations operate on `public.*` which loads cleanly.)

### Step 3 — verify

```bash
docker exec docsera-test-db psql -U postgres -d postgres -c "\dt public.*"
```

You should see your tables listed.

### Refreshing the mirror

When the prod schema changes (because *you* applied a migration), refresh by re-running Steps 1–2. The container persists across Docker restarts; remove it to start fresh:
```bash
docker rm -f docsera-test-db
```

---

## Procedure G — full local Supabase stack (post-launch)

**Status: 📅 Deferred to post-launch.** This is the closest thing to a real staging environment you can have without renting a second VPS — a full copy of every Supabase service running on your Mac via `supabase start`. Cost: ~1–2 hours one-time setup, ~4–6 GB RAM while running.

### Why deferred until post-launch

The pre-launch period is the wrong time to introduce new tooling. You are protected today by:
- **Procedure F** — catches bad SQL before prod ever sees it
- **TestFlight / Play Internal** — catches bad app behavior on real devices before public users see it
- **Procedure D** — backups protect against everything else

Procedure G doesn't catch a category of bug that those three miss. It just makes some categories *cheaper* to catch (no need to wait 24h for a TestFlight build to verify a Dart-against-new-schema change). That's a velocity improvement, not a safety improvement — worth doing once you're shipping fast, not while you're still finding the launch bar.

### What it gives you when you do set it up

- Full app testing against a fresh local Supabase (Postgres + Auth + Storage + Realtime + Edge Functions + Studio + Kong)
- Switching app between local and prod via `--dart-define` (NOT manual `const.dart` edits — that path leads to shipping localhost-pointed builds to the App Store)
- Edge function development with hot reload via `supabase functions serve`
- A "blank slate" environment where you can break things freely without affecting users

### Trigger to actually set this up

Set this up the first time *any* of these happen:
- You're about to ship a feature touching schema + Dart code + edge function in one PR
- You're about to refactor auth or RLS policies
- You shipped a bug that would have been caught by full local testing (and a TestFlight build would have been overkill)

### The intended daily workflow (what this looks like once set up)

Every morning:
1. `supabase start` — local stack comes back up in ~30 sec (Docker resumes from disk; data persists across restarts)
2. `flutter run --flavor dev` — the app launches pointing at `http://localhost:54321` with a different icon (so you can tell at a glance you're on dev)
3. Develop, break things, run migrations against the local DB, edit edge functions, refresh — all without touching a single live byte
4. When something is verified working: commit the migration / edge function / Dart change, then **separately** apply it to prod via Procedures B / C / A
5. Switch the app to prod for a final sanity check via `flutter run --flavor prod`

The daily mental model: **dev is where you work, prod is where you ship.** You should rarely run anything *against* prod manually — prod receives changes only via verified migrations and verified releases.

### Prerequisites (the work BEFORE this procedure can be used)

Procedure G requires three pieces of work first, in this order:

**Prerequisite 1 — `const.dart` reads URL/key from environment, not hardcoded:**

In [lib/app/const.dart](../../lib/app/const.dart), replace hardcoded constants with:
```dart
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://api.docsera.app',  // production fallback
  );
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '<prod-anon-key>',
  );
}
```

The defaults remain prod — so existing builds that don't pass `--dart-define` still work exactly as before. Only `--flavor dev` builds will receive the local override.

**Prerequisite 2 — build flavors:**

Add `dev` and `prod` flavors at three layers:
- **Flutter:** `flutter run --flavor dev` / `--flavor prod`. Configured via `flavorDimensions` in `android/app/build.gradle` and Xcode schemes.
- **Android bundle ID:** `app.docsera.dev` (dev) vs `app.docsera` (prod) — both can coexist on one phone with different icons.
- **iOS bundle ID:** `com.docsera.dev` (dev) vs `com.docsera` (prod) — same idea, configured in Xcode build configurations.

Set the dev flavor to default to local URL via `--dart-define=SUPABASE_URL=http://localhost:54321` baked into a `scripts/run_local.sh` wrapper so you don't type it every time.

**Prerequisite 3 — test data seeding:**

Without seed data, `supabase start` gives you an empty database — you can't test login, can't book appointments, can't see anything. You need:

- **A schema dump from prod** (Procedure F's `~/docsera-prod-schema.sql`) loaded into the local stack so the structure matches
- **Synthetic test users** — say 5 patients, 3 doctors, 2 medical centers — created via SQL inserts in `supabase/seed.sql`. Use *fake* phone numbers and emails (e.g., `+963900000001`, `test1@example.com`). The existing OTP-bypass `123456` (per [project_test_otp_bypasses.md](../../.claude/projects/-Users-georgezakhour-development-DocSera/memory/project_test_otp_bypasses.md)) makes login trivial for these accounts.
- **Synthetic appointments, conversations, documents** — enough to cover every screen with real-looking data. ~50 rows total is enough.
- **Refresh script:** `scripts/refresh_local_schema.sh` that pulls the latest prod schema and re-applies seed data. Run when prod schema changes.

**IMPORTANT:** Never seed real production data into local. Even if it would be more realistic, it's a privacy risk (user data on your laptop) and a security risk (a leaked test bundle could include real PHI). Always synthetic.

### High-level commands (verify when actually doing this)

```bash
# One-time
brew install supabase/tap/supabase    # CLI
cd <project-root>
supabase init                          # creates supabase/config.toml if not present
supabase start                         # brings up the full stack on Docker
psql -h localhost -p 54322 -U postgres < supabase/seed.sql  # load test data

# Daily
supabase start                         # idempotent — resumes existing stack
./scripts/run_local.sh                 # wraps flutter run --flavor dev with --dart-defines

# When prod schema changes (after applying a migration to prod)
./scripts/refresh_local_schema.sh      # pulls prod schema, re-applies seed
```

### DocSera-specific gotchas to plan for

| Service | Local behavior | Workaround |
|---|---|---|
| Phone OTP (SMS) | No SMS gateway locally | Existing test bypass `123456` works (see `project_test_otp_bypasses.md`) |
| Email OTP | No SMTP locally | Run [Mailpit](https://github.com/axllent/mailpit) on `localhost:1025` to capture emails in a web UI |
| Push notifications (Pushy) | Won't deliver | Test push only on TestFlight/Play Internal — accept this gap |
| Sentry | Would pollute prod project | Either set `SENTRY_DSN=""` for local, or create a separate dev DSN |
| Anon key | Different from prod | Build flavors handle this — never hardcode prod key as default |

### Required Flutter changes before this works

- `lib/app/const.dart` must read URL/anon-key via `String.fromEnvironment(...)` instead of hardcoded constants
- Add `--flavor dev` and `--flavor prod` build flavors with different bundle IDs so both can coexist on one phone
- A `Makefile` or `scripts/run_local.sh` so the long `--dart-define` command isn't typed by hand each time

When this procedure is actually performed, fully document it here with verified commands and observed gotchas — same pattern as Procedure D's verification log.

### Maintenance burden (the honest cost)

Procedure G is not free to maintain. Things that will need ongoing attention:

| Concern | How often | Effort |
|---|---|---|
| Refresh local schema after each prod migration | Per migration | ~2 min |
| Re-create test users when seed data drifts from new schema | Whenever schema changes break seed | ~10 min |
| Update local Supabase version when prod is upgraded | Quarterly | ~30 min |
| Debug local-only issues (port conflicts, Docker disk space) | When they arise | Variable |

The total cost is small once you're past setup, but it's non-zero. Build flavors specifically can be a source of subtle bugs — wrong flavor in CI, wrong flavor at submission. Be deliberate.

### When this is verified, mark it ✅ at the top

Update the [verification status table](#verification-status) when each prerequisite + the procedure itself is verified. Likely tracked as four sub-statuses:
- G.1 — `const.dart` reads from environment
- G.2 — Build flavors `dev` / `prod` work
- G.3 — Test data seed produces a usable app
- G.4 — Full daily workflow (`supabase start` → develop → ship via Procedures A/B/C) used for at least one feature

---

## Emergency procedures

### Halt a Play Store rollout

If Sentry shows a crash spike after a Play release rollout begins:

1. [play.google.com/console](https://play.google.com/console) → app → **Production** → current release
2. **Halt rollout** button (top right) — stops new users from getting the build
3. Existing users on the bad version stay on it; new installs get the previous version
4. Fix the bug, ship a new version, resume rollout (or replace it)

### Halt an iOS phased release

1. App Store Connect → app → **App Store** → current version → **Phased Release for Automatic Updates**
2. **Pause** button — pauses the percentage ramp
3. Optionally remove the version from sale entirely (**Remove from Sale**) — drastic, only for severe data-loss bugs

### Edge function is broken in production

Roll back to the previous version (Procedure C → Rollback). If you don't have the previous version saved (you forgot Step 2), `git checkout` the previous version of the file and deploy that.

### A migration corrupted data

1. Stop further writes to the affected table by quickly disabling the relevant feature in the app via a server-side flag (if you have one) — otherwise:
2. Restore from the pre-migration backup (Procedure E → "Restore to prod"). All writes since the backup are lost.
3. Forensically inspect the corrupted-state backup (the one you took before restoring) to understand what went wrong.

### VPS is down

Out of scope for this doc — that's an infrastructure issue. Check uptime monitoring (currently: none — deferred). The VPS is at `94.252.183.77` (port 2203 SSH); Supabase services are Docker containers managed via `docker compose` in `/home/george/supabase/`.

---

## Pre-flight checklist

**Run through this before every prod change**, no matter how small. Print it, tape it next to your monitor.

```
[ ] My change is committed locally (no uncommitted work in progress)
[ ] My change has been pushed to GitHub (`git push`)
[ ] CI is green for the latest commit (analyze + tests passed)
[ ] If touching DB:
    [ ] Migration tested on local mirror (Procedure F)
    [ ] Backup taken in last 5 minutes (Procedure D)
    [ ] Backup file noted: /tmp/backup-_____________
    [ ] Rollback SQL written and reviewed
[ ] If touching edge function:
    [ ] Local serve test passed (Procedure C, Step 1)
    [ ] Previous version saved to /tmp/<func>.previous.ts
[ ] If shipping mobile app:
    [ ] Build number bumped in pubspec.yaml
    [ ] Internal Testing track will receive build first (NOT production directly)
    [ ] 24-hour burn-in window scheduled in calendar
[ ] Sentry dashboard open in another tab to watch error rate
[ ] I have ~30 min of focused time — no distractions during the change
```

---

## Practice schedule

These drills keep the procedures muscle-memory. The first time you do a real one shouldn't be the first time you've ever run the commands.

| Drill | Frequency | Procedure |
|---|---|---|
| Take a backup, pull to laptop | Weekly | D |
| Restore the latest backup to local Docker | Monthly | E |
| Refresh local schema mirror | Whenever you write a migration | F |
| Practice halting a Play rollout (in Play Console UI, no actual halt) | Once before launch | Emergency |
| Practice halting iOS phased release (in App Store Connect UI) | Once before launch | Emergency |

Calendar reminder suggestions:
- **Every Monday 9:00** — "Take prod backup, pull to ~/docsera-backups/"
- **First Monday of each month** — "Run recovery drill (Procedure E)"

---

## What we deliberately don't do (yet)

These are real practices used at larger orgs that we've consciously deferred. Each is documented with the trigger that should make us reconsider:

| Practice | Why deferred | Trigger to reconsider |
|---|---|---|
| Separate staging Supabase instance | High setup cost; pre-launch timeline | After 1,000 active users OR hire of 2nd engineer |
| Automated daily backups via cron | One more moving part to maintain | After first month post-launch — set up if you've forgotten the weekly manual once |
| Storage blob backup (uploaded files) | Manual procedure exists; rare-event recovery | If documents become legally-required to retain (regulatory) |
| Feature flags table | Premature for current feature velocity | When shipping a feature that's risky and you want to dark-launch it |
| Blue-green deployment for edge functions | The 5-second restart is acceptable | When edge function call rate exceeds 100 req/sec |
| VPS-level uptime monitoring (UptimeRobot, Pingdom) | Manual check is OK at current scale | Day 1 post-launch — set up free tier ASAP |
| Database point-in-time recovery (PITR) | Requires WAL archiving config on self-hosted | When data-loss tolerance drops below 24 hours |

When you do reconsider any of these, document the migration in a new launch doc.

---

## Score impact

This is operational documentation, not a code or schema change — it doesn't move a launch-readiness score directly. But it dramatically reduces the bus-factor risk: if you stepped away for a week, anyone with VPS access could keep the app running by following this doc. That's the real value.

Treat this doc as living. Every time you ship a change and notice the procedure was missing a step or had an error, fix the doc the same day.

---

## Verification log

A chronological record of when each procedure was actually run end-to-end. Append to this whenever you complete a drill or a real run — it's the difference between "documented" and "trusted."

### 2026-05-10 — Procedure D (take a production backup) — first run

**Context:** First-ever practice drill, ~2 weeks before public launch. Operator wanted hands-on confidence before relying on the procedure in production.

**Pre-flight discovery:** Listing containers via `docker ps | head -20` did *not* show `supabase-db` (it was past line 20 because Coolify-managed containers crowded the top of the list). Required filtering with `grep -iE 'postgres|supabase|db'` to confirm `supabase-db` was running. Lesson captured in the [container naming quirk](#container-naming-quirk-this-vps) section above.

**Commands run, in order:**

```bash
# 1. Confirm container exists
ssh -p 2203 george@94.252.183.77 "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -iE 'postgres|supabase|db'"
# → confirmed: supabase-db / supabase/postgres:15.8.1.085 / Up 6 weeks (healthy)

# 2. Take backup on the VPS
ssh -p 2203 george@94.252.183.77 "docker exec supabase-db pg_dump -U postgres postgres | gzip > /tmp/backup-$(date +%Y%m%d-%H%M).sql.gz"
# → no output (success)

# 3. Verify file exists on VPS
ssh -p 2203 george@94.252.183.77 "ls -lh /tmp/backup-*.sql.gz"
# → -rw-rw-r-- 1 george george 6.8M May 10 19:24 /tmp/backup-20260510-1824.sql.gz

# 4. Pull to laptop
mkdir -p ~/docsera-backups
scp -P 2203 george@94.252.183.77:/tmp/backup-20260510-1824.sql.gz ~/docsera-backups/
# → 6962KB transferred in 29 sec at 238 KB/s

# 5. Verify local copy
ls -lh ~/docsera-backups/
# → -rw-r--r-- 1 georgezakhour staff 6.8M May 10 18:27 backup-20260510-1824.sql.gz
```

**Observations to note for next time:**
- Total time: ~1 minute including verification steps
- Backup size: 6.8 MB compressed (this is the pre-launch baseline)
- VPS-to-laptop transfer: ~30 sec at 238 KB/s (your home connection on 2026-05-10)
- No errors at any step
- VPS clock is ~57 minutes ahead of laptop clock (filename `19:24` on VPS vs `18:27` mtime on laptop — VPS appears to be set to a different timezone or has clock drift). Worth double-checking the VPS timezone if scheduled jobs ever look mistimed.

**Outcome:** ✅ Procedure D verified working. Operator confirmed comfort with the commands. First real backup file lives at `~/docsera-backups/backup-20260510-1824.sql.gz`.

**Next:** Run Procedure E (restore drill) against this backup file to confirm it's not just bytes but actually-restorable data.

---

<!-- When you run another drill, add a new dated section above this line, following the same structure: Context / Commands / Observations / Outcome. -->

