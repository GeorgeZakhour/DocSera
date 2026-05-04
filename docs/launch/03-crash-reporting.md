# 03 — Crash Reporting (Sentry)

**Date:** 2026-05-04
**Severity addressed:** 🔴 No production observability — flying blind
**Provider:** Sentry.io (cloud, EU region — `ingest.de.sentry.io`)

## Summary

Every crash, unhandled exception, and explicitly-captured error in the DocSera app is now sent to a Sentry project hosted in the EU. The dashboard shows ranked issues, full stack traces with file paths and line numbers, device/OS metadata, and a workflow to mark issues resolved. Healthtech-safe defaults are configured: no PII, no screenshots, no request bodies leave the device.

## Why it matters

Without crash reporting, the first you'd hear about a production crash is a 1-star App Store review days later, with no stack trace. With Sentry, you see crashes within seconds of them occurring, ranked by user impact, with the exact line of Dart code that broke. This is the foundation for actually-fixing bugs in production.

## Why Sentry cloud (not self-hosted)

- **Sanctions on Syria were lifted June/July 2025** — Sentry signup works from Syrian IPs as of May 2026 (verified by successful test event delivery).
- **VPS is RAM-constrained.** Self-hosting Sentry would cost ~8GB RAM (Sentry proper) or ~1GB (GlitchTip). Cloud cost: zero VPS resources.
- **EU region (`ingest.de.sentry.io`)** keeps crash data within EU jurisdiction — closest equivalent to in-region hosting without the operational burden.
- **Free tier** = 5,000 errors/month, more than enough for years at current scale.

If Sentry ever blocks Syria again, the fallback is GlitchTip self-hosted — Sentry-API-compatible, so the Flutter SDK does not change, only the DSN.

## What changed

### Files
- [pubspec.yaml](../../pubspec.yaml) — added `sentry_flutter: ^8.10.0`.
- [lib/services/observability/sentry_init.dart](../../lib/services/observability/sentry_init.dart) — init wrapper with PII scrubbing, environment tagging, and test helpers.
- [lib/main.dart](../../lib/main.dart) — wraps `runApp` in `SentryInit.run(...)`.
- `dart_defines/sentry.json` — gitignored, holds the real DSN.
- `dart_defines/sentry.example.json` — committed, shows the expected shape.
- `.gitignore` — excludes `dart_defines/*.json` except `*.example.json`.
- [CLAUDE.md](../../CLAUDE.md) — documents the build workflow.

### Healthtech-safe configuration
Configured in `sentry_init.dart`:
- `sendDefaultPii: false` — no IP addresses, names, emails, or device identifiers.
- `attachScreenshot: false` — never captures the UI (which could show patient data).
- `attachViewHierarchy: false` — same reason.
- `beforeSend` hook — strips request/response bodies from network breadcrumbs and clears any user PII fields.
- `tracesSampleRate: 0.1` — 10% performance sampling, keeps quota lean.
- Auto-tagged environment: `debug` / `staging` (TestFlight/Play Internal) / `production`.

### Build-time DSN injection
The DSN is **not** hardcoded. It's loaded from `dart_defines/sentry.json` at build time. If the file is missing or `SENTRY_DSN` is empty, Sentry is fully disabled (no-op) — safe to ship.

## How to operate it

### Daily (Xcode workflow)
**Just hit Run in Xcode.** No commands, no flags. The DSN was baked into `ios/Flutter/Generated.xcconfig` by:

```bash
flutter build ios --config-only --dart-define-from-file=dart_defines/sentry.json
```

This only needs to be re-run if `dart_defines/sentry.json` changes (e.g., DSN rotation, enabling test mode) or after `flutter clean`.

### Daily (terminal / Android Studio)
```bash
flutter run --dart-define-from-file=dart_defines/sentry.json
```

### Triggering a test event
Set `SENTRY_TEST: "1"` in `dart_defines/sentry.json`, rebuild config, run the app once. A `StateError` appears in the dashboard within seconds. Set back to `""` after.

### Viewing crashes
[https://docsera.sentry.io](https://docsera.sentry.io) → Issues tab. Filter by environment (`production` / `staging` / `debug`) to ignore your own debugging noise.

## How to verify

1. Set `SENTRY_TEST: "1"` in `dart_defines/sentry.json`.
2. Run `flutter build ios --config-only --dart-define-from-file=dart_defines/sentry.json`.
3. Build & run from Xcode on a real device.
4. Within 30 seconds, an event titled `StateError: Sentry test captured error.` should appear at https://docsera.sentry.io.

**Verified working on 2026-05-04** with release tag `1.0.0 (17)` from device.

## What could go wrong

- **`flutter clean` wipes `Generated.xcconfig`.** Re-run the `flutter build ios --config-only` command after every clean.
- **`dart_defines/sentry.json` is committed by accident.** It's in `.gitignore`, but if anyone moves it or copies its contents elsewhere, the DSN leaks. Rotate the DSN immediately if this happens — it's a moderate-severity leak (write-only key, not a service-role key).
- **Sentry quota exceeded.** Free tier = 5,000 errors/month. If a crash storm bursts the quota, later crashes are dropped. Monitor the Stats tab; bump `tracesSampleRate` lower if performance events dominate.
- **Syria/Syriatel blocks `ingest.de.sentry.io`.** SDK fails silently, app keeps working, but you lose visibility for affected users. Periodically curl-test from VPS:
  ```bash
  ssh -p 2203 george@94.252.183.77 "curl -I https://ingest.de.sentry.io 2>&1 | head -3"
  ```

## Score impact

8.3 → **8.6** (+0.3). Foundational — every other launch-readiness improvement is safer once you can see what breaks in production.
