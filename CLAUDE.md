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

## Testing

- **Framework**: `flutter_test` + `bloc_test` + `mocktail`
- **Test location**: `test/` directory
- **Run tests**: `flutter test`
- **Run analysis**: `flutter analyze`
- Test Cubits using `blocTest()` with mocked services
- Integration tests in `test/integration/`

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
- No CI/CD pipeline exists yet — builds are done locally
- Both DocSera and DocSera-Pro share the same Supabase backend — coordinate schema changes
