# DocSera — Patient App

## Project Overview

DocSera is a **Flutter-based healthcare mobile application** for patients. It enables appointment booking, doctor search, secure messaging, medical document management, and health record tracking. It targets iOS and Android as primary platforms, with web/desktop support available.

**DocSera-Pro** (the doctor-facing app) shares the same Supabase backend. Changes to database schema, RPC functions, edge functions, or RLS policies affect both apps.

## Tech Stack

- **Framework**: Flutter (Dart SDK ≥3.6.0 <4.0.0)
- **State Management**: BLoC pattern using Cubits (`flutter_bloc`)
- **Backend**: Supabase (self-hosted at `https://api.docsera.app`) — PostgreSQL, Auth, Realtime, Storage, Edge Functions
- **Navigation**: Navigator push/pop with named routes and deep linking (`app_links`)
- **Styling**: `flutter_screenutil` for responsive sizing, Material Design
- **Localization**: ARB-based i18n (English + Arabic with full RTL support)
- **Encryption**: AES-256-GCM for message encryption (`encrypt` package)
- **Notifications**: Pushy (`pushy_flutter`) + `flutter_local_notifications`
- **Auth**: Phone OTP, Email OTP, Biometrics (Face ID / Fingerprint)
- **Storage**: `flutter_secure_storage` (sensitive), `SharedPreferences` (non-sensitive)

## Project Structure

```
lib/
├── app/                  # Constants (colors, keys), text styles
├── Business_Logic/       # Cubits organized by feature (Auth, Appointments, Messages, etc.)
├── models/               # Data models (Conversation, Document, Message, etc.)
├── screens/              # UI pages grouped by feature
│   ├── auth/             # Login, sign-up, identification, forgot password
│   ├── home/             # Main app screens (documents, account, appointments, messages, etc.)
│   ├── doctors/          # Doctor profiles and search
│   ├── centers/          # Medical centers
│   └── misc/             # Miscellaneous screens
├── services/             # Business logic and external integrations
│   ├── supabase/         # Supabase services and repositories
│   ├── auth/             # Authentication service
│   ├── encryption/       # Message encryption (AES-256-GCM)
│   ├── notifications/    # Push notification handling
│   ├── biometrics/       # Face ID / Fingerprint
│   ├── connectivity/     # Network monitoring
│   ├── storage/          # Secure encrypted storage
│   └── navigation/       # Deep linking, app lifecycle
├── utils/                # Helpers (time, errors, text direction, page transitions)
├── widgets/              # Reusable UI components
├── l10n/                 # ARB localization source files
├── gen_l10n/             # Generated localization code (do not edit manually)
├── main.dart             # Entry point, MultiBlocProvider setup
└── splash_screen.dart    # Initial loading screen
supabase/
├── migrations/           # Database migrations
├── functions/            # Edge functions (Deno/TypeScript)
├── schema.sql            # Database schema
└── config.toml           # Supabase project config
```

## Architecture & Patterns

### State Management (BLoC/Cubit)
- All state is managed via Cubits in `Business_Logic/`
- Cubits are initialized in `main.dart` via `MultiBlocProvider`
- Each Cubit has a corresponding state class (e.g., `auth_state.dart`)
- Cubits use injected service repositories — follow this pattern for new features
- Never access Supabase directly from UI — always go through Cubit → Service/Repository

### Repository / Service Pattern
- `services/supabase/repositories/` — data access layer (Auth, User, Favorites, Appointments)
- `services/supabase/` — higher-level services that compose repositories
- Services are singletons, injected into Cubits

### Navigation
- Push/pop Navigator with global NavigatorKey
- Deep links: `docsera://doctor/<public_token>` and `https://docsera.app/doctor/<public_token>`
- Auth-based routing: Splash → Auth screens → Home screens

## Key Conventions

### Naming
- Directories: `PascalCase` for feature folders in `Business_Logic/`, `snake_case` elsewhere
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/methods: `camelCase`

### Styling
- Use `flutter_screenutil` extensions (`.w`, `.h`, `.sp`, `.r`) for all sizing
- Colors: use `AppColors` from `app/const.dart` — primary is `#009092` (teal)
- Text styles: use `AppTextStyles` methods (`getTitle1()` through `getTitle4()`, `getText1()` through `getText4()`)
- Fonts: Montserrat (English), Cairo (Arabic) — auto-selected by locale

### Accessibility (post-Step-13 patterns)
- **Never use `AppColors.orangeText` (#FFA070) as a text color.** It fails WCAG AA on every background it appears on. Use `AppColors.giftAccent` (#E07A1F) for orange-accent text instead. Decorative icons can still use `orangeText` if shape is the signal.
- **Never use `AppColors.background3` (#F7FDFC) as a text color.** It's a background tint, not a text color — invisible on white/near-white surfaces. Use `Colors.grey.shade700` or `AppColors.mainDark` for secondary text.
- **Every icon-only `IconButton` must have a `tooltip:`** — Flutter wires `tooltip` to the Semantics label, so this fixes both long-press hint AND screen-reader announcement at once.
- **For tappable icons in `GestureDetector`/`InkWell`** (which don't auto-label), wrap in `Semantics(label: ..., button: true, child: ...)`.
- **Tooltip strings always come from `AppLocalizations`** — they're user-facing text and need Arabic translation (project default locale).
- See [docs/launch/12-accessibility.md](docs/launch/12-accessibility.md) for full WCAG cheat-sheet and rationale.

### Localization
- All user-facing strings must be in ARB files (`lib/l10n/app_en.arb`, `app_ar.arb`)
- Access via `AppLocalizations.of(context)?.key`
- Default locale: Arabic (`ar`)
- Track untranslated keys in `untranslated_ar.txt`

### Time Handling
- Store all times in UTC in the database
- Use `DocSeraTime` utility (`utils/time_utils.dart`) for Syria timezone display
- Methods: `tryParseToSyria()`, `toUtc()`

### Error Handling
- Use `ErrorHandler` utility for centralized error management
- Cubits should emit error states with user-friendly messages
- Always wrap Supabase calls in try-catch

### Encryption
- Chat messages use AES-256-GCM via `MessageEncryptionService`
- Encrypted messages are prefixed with `"ENC:"`
- Encryption key is fetched via RPC: `rpc_get_encryption_key()`
- Always handle graceful degradation if encryption is unavailable

### Authentication
- Phone OTP via `send_login_otp` / `verify_login_otp` RPCs
- Email OTP via `send_email_otp` edge function
- Biometrics via `local_auth` package
- Session auto-refresh every 10 minutes
- `AuthCubit` listens to `Supabase.auth.onAuthStateChange`

### Connectivity
- `ConnectivityService` monitors network status with deep socket checks
- `OfflineBanner` widget displays when disconnected
- Custom `_SyriaClient` applies 30-second HTTP timeout for slow networks

### Crash reporting (Sentry)
- Wrapped via `SentryInit.run(...)` in `main.dart` (lib/services/observability/sentry_init.dart)
- DSN loaded at build time from `dart_defines/sentry.json` (gitignored — see `dart_defines/sentry.example.json` for the shape)
- Healthtech-safe defaults: `sendDefaultPii: false`, screenshots/view-hierarchy capture disabled, `beforeSend` strips request/response bodies and PII fields
- If `SENTRY_DSN` is empty, Sentry is fully disabled (no-op) — safe to ship without it

**Rebuilding Xcode config after editing `dart_defines/sentry.json`:**
```bash
flutter build ios --config-only --dart-define-from-file=dart_defines/sentry.json
```
Then build/run from Xcode normally — the DSN is now baked into `ios/Flutter/Generated.xcconfig` until the next `flutter clean`.

For Android Studio / `flutter run` from terminal:
```bash
flutter run --dart-define-from-file=dart_defines/sentry.json
```

## Supabase Backend (Shared with DocSera-Pro)

### Key Tables
`users`, `doctors`, `appointments`, `conversations`, `messages`, `documents`, `notes`, `relatives`, `banners`, `user_devices`, `doctor_vacations`, `otp`

### RPC Functions
- Patient-facing: `book_appointment_by_patient`, `cancel_appointment_by_patient`, `get_available_slots`, `rpc_get_my_user`, `rpc_update_my_user`, `rpc_get_my_relatives`
- Auth: `phone_exists`, `email_exists`, `send_login_otp`, `verify_login_otp`
- Critical RPCs use `SECURITY DEFINER`

### Edge Functions (Deno/TypeScript)
- `send_email_otp`, `push_notifications`, `update_email_admin`

### Database Triggers
- `trg_sync_appointment_date_time` — syncs appointment date/time fields
- `trg_handle_new_message` — updates conversation metadata on new messages
- `trg_award_points_after_done` — loyalty points after completed appointments

### Security conventions (post-2026-05-04 internal review)

- **Never log PII or auth material.** Phone, email, OTP code, password, JWT, Pushy token, session token must never appear in `print` / `debugPrint` / Sentry breadcrumbs. When debugging is necessary, log lengths or boolean outcomes only, gated on `kDebugMode`.
- **Plaintext credentials in `SharedPreferences` are forbidden.** Use `flutter_secure_storage` (via `BiometricStorage` for biometric flows or `SecureStorageService` for raw keys). `SharedPreferences` is for non-sensitive UI state only.
- **Every new `SECURITY DEFINER` function must include `SET search_path = public, pg_temp`** at function definition time. This prevents schema-injection attacks. The audit migration `20260504160000_secdef_search_path_hardening.sql` retroactively pinned all existing functions.
- **Inputs from external sources (deep links, RPC payloads) must be validated for length and charset** before reaching the database. The deep-link handler caps tokens at 64 chars and `[A-Za-z0-9_-]`.
- See [docs/launch/05-security-review.md](docs/launch/05-security-review.md) for the full audit and findings.

### Row-Level Security
- All public tables have RLS enabled and forced — always respect and maintain RLS policies
- OTP / secret / audit tables (`login_otps`, `email_otp`, `_secrets`, `doctor_storage_usage`, `manual_patients_phone_audit`, plus the `*_otps` / `*_rate_limits` family) have RLS on with **zero policies by design** — they are accessed only by edge functions and `SECURITY DEFINER` RPCs running as `service_role`. Never grant `anon`/`authenticated` access or add permissive policies to these.

### Applying migrations on self-hosted Supabase
The Supabase CLI is not used in this setup. Migrations run directly via `psql` inside the `supabase-db` container on the VPS:

```bash
# Copy migration to the VPS
scp -P 2203 supabase/migrations/<file>.sql george@94.252.183.77:/tmp/migration.sql

# Apply as supabase_admin (superuser — works for both postgres- and supabase_admin-owned tables)
ssh -p 2203 george@94.252.183.77 \
  "docker cp /tmp/migration.sql supabase-db:/tmp/migration.sql && \
   docker exec -i supabase-db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f /tmp/migration.sql"
```

Use `-U supabase_admin` whenever the migration touches RLS, ownership, or `supabase_admin`-owned tables (`_secrets`, `doctor_storage_usage`, `manual_patients_phone_audit`). `-U postgres` is fine for everything else but `supabase_admin` works universally.

## Working safely with multiple agents (loss-prevention)

**Always commit and push launch-prep work as soon as a step is complete.** On 2026-05-05 a parallel agent's `git reset` + working-tree clean wiped ~20 file modifications spanning multiple roadmap steps. The work was recovered from a dangling commit, but it was a near-miss — `git gc` would have made it permanent.

The convention going forward:

- After completing any roadmap step (`docs/launch/<NN>-*.md`), commit immediately:
  ```bash
  git add -A
  git commit -m "feat(launch): step N — <summary>"
  git push origin main
  ```
- For mid-step checkpoints (migration applied, file rewritten, fix verified), prefer a WIP commit over holding modifications.
- If you must hold WIP across a context switch, at minimum: `git stash --include-untracked -m "<descriptive>"`.
- Never trust that work in the working tree is safe — only the commit + remote push is durable.
- Secrets in `dart_defines/sentry.json` are gitignored; pushing is safe.

## Testing

- **Framework**: `flutter_test` + `bloc_test` + `mocktail`
- **Test location**: `test/` directory
- **Run tests**: `flutter test`
- **Run analysis**: `flutter analyze`
- Test Cubits using `blocTest()` with mocked services
- Integration tests in `test/integration/`

## CI/CD discipline (free-tier — IMPORTANT)

GitHub Actions is on the free tier (2,000 minute-units/month) and the user is **not paying** and **does not plan to pay**. CI is split into two workflows so the budget never blows:

| Workflow | File | Trigger | Cost/run | Purpose |
|---|---|---|---|---|
| **CI** | `.github/workflows/ci.yml` | Every push to `main` and every PR | ~8 min-units (Linux only) | Fast: `flutter analyze` + `flutter test` |
| **Build** | `.github/workflows/build.yml` | **Manual only** (`workflow_dispatch`) or `v*` tag push | ~58 min-units (50 of which are macOS at 10× multiplier) | Android APK + iOS simulator builds |

**Rules for any agent working in this repo:**

1. **Never re-add Android or iOS build jobs to `ci.yml`.** They live in `build.yml` for a reason. The math: at the user's pace, every-push iOS builds exhaust the free tier in <2 weeks. The split saves ~50 min/push.
2. **Native build failures on `main` are not normally caught by `ci.yml`.** That is by design. When the user pushes Dart-only changes, analyze + tests are sufficient; the build workflow is the final gate before a release or when verifying a native-touching change.
3. **When a CI failure surfaces a native bug** (the build workflow is red), fix it but don't add per-push gating "to catch it earlier." The signal-to-noise of per-push native builds isn't worth the cost.
4. **Free-tier headroom**: ~250 pushes/month on `ci.yml`, ~25 full builds/month on `build.yml`, before exhaustion. Watch usage at github.com/settings/billing if approaching limits.

### When to PROACTIVELY suggest running the Build workflow

The user does NOT remember to run builds — agents must suggest it whenever the change risks breaking the native build. Trigger this suggestion immediately after committing if any of the following is true:

| Triggering change | Why a build is needed |
|---|---|
| Edit to anything under `ios/**` | Xcode project, Info.plist, Podfile, AppDelegate, entitlements, AssetCatalog — any of these can break iOS without breaking analyze/tests |
| Edit to anything under `android/**` | Gradle config, AndroidManifest, MainActivity, Kotlin/Java sources, NDK, signing config |
| Edit to `pubspec.yaml` (deps added/upgraded/removed) | New native plugins or version bumps can fail Pod install or Gradle resolution |
| Edit to `.github/workflows/build.yml` itself | Workflow change must be verified by running the workflow |
| Edit to `analysis_options.yaml`, `dart_defines/*` | Build-time configuration that's not exercised by analyze/tests |
| Touching `MessageEncryptionService` or other plugin-channel code | Platform-channel surface changes can compile-fail on one platform |
| **Before tagging a release** (any `v*` tag) | Tag push triggers `build.yml` automatically, but agents should still suggest a pre-tag dry run |
| Before merging a PR that contains any of the above | Manual build run from the PR branch is the gate |

How the suggestion should sound (terse, with the exact command):

> "You touched `ios/Runner.xcodeproj/project.pbxproj` — recommend running the build workflow before relying on this commit:
> ```
> gh workflow run build.yml
> ```
> (Or via UI: Actions → Build (Android + iOS) → Run workflow.)"

If only one platform is affected (e.g. only `android/**` changed), suggest the targeted form to save minutes:

> ```
> gh workflow run build.yml -f ios=false
> ```

### When NOT to suggest a build

- Pure Dart/Flutter changes under `lib/` (UI, logic, tests, l10n) — analyze + tests cover these
- Doc changes (`docs/**`, `*.md`)
- Test-only changes (`test/**`)
- Asset-only additions (`assets/images/**`) unless they trigger an asset catalog regeneration on iOS
- Pure CI config changes to `ci.yml` (analyze + tests will run on the next push anyway)

See [docs/launch/08-ci-github-actions.md](docs/launch/08-ci-github-actions.md) for the full design rationale and history.

## Commands

```bash
# Run the app
flutter run

# Run tests
flutter test

# Run analysis
flutter analyze

# Generate localization files
flutter gen-l10n

# Build for release
flutter build apk        # Android
flutter build ios         # iOS

# Supabase (local dev)
supabase start
supabase functions serve
supabase db push          # Apply migrations
```

## Important Notes

- Supabase credentials are in `app/const.dart` — these are client-side anon keys (safe for mobile)
- The app has 77 dependencies — check `pubspec.yaml` before adding new ones to avoid duplicates
- CI is split: `ci.yml` (analyze + test on every push) + `build.yml` (manual builds only — see "CI/CD discipline" above)
- Both DocSera and DocSera-Pro share the same Supabase backend — coordinate schema changes
