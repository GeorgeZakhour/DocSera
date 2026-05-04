# 02 — Forced-Update Mechanism

**Date:** 2026-05-04
**Severity addressed:** 🔴 No emergency brake for shipped versions
**Migration:** `supabase/migrations/20260504130000_app_config.sql`

## Summary

A server-controlled gate that runs at app startup. When the operator marks a version as below-minimum, every user on that version sees a blocking "Update Required" screen and cannot use the app until they install the new version from the App Store / Play Store. This is the standard mechanism every banking and healthtech app uses to push security patches in hours instead of weeks.

## Why it matters

Without this, if a security bug is found in a shipped version, the only recourse is to upload a new version to the stores and hope users update. In practice, 30–50% of users delay updates for weeks. For a healthcare app, a 4-week tail of a vulnerable version is unacceptable. With this gate, ~95% of users move within 24 hours of flipping the switch.

## What changed

### Database
- **New table:** `public.app_config` — single-row (id=1 enforced) holding minimum & latest version per platform, store URLs, and force-update messages in EN/AR.
- **New RPC:** `public.rpc_get_app_config()` — `SECURITY DEFINER`, returns config as JSONB. Granted to `anon` + `authenticated` so the check works pre-login.
- RLS on, no direct table grants — clients read only via the RPC.

### Flutter app
- `lib/services/app_config/app_config_service.dart` — fetches config, compares current `package_info_plus` version to minimum, returns whether a force update is required. **Fails open on network errors** (transient timeouts must not block users; the offline banner already covers true offline state).
- `lib/screens/misc/force_update_screen.dart` — full-screen, no-back, no-dismiss, "Update Now" button opens the platform store via `url_launcher`.
- `lib/splash_screen.dart` — calls the check after auth-ready, before navigating to home/login.

## How to operate it

### Day-to-day
Nothing. Seeded values are `0.0.0`, which never forces an update.

### When you need to force an update
SSH to the VPS and run one query:

```sql
UPDATE public.app_config
SET min_supported_version_ios     = '1.4.0',
    min_supported_version_android = '1.4.0',
    ios_store_url     = 'https://apps.apple.com/app/docsera/id<real-id>',
    android_store_url = 'https://play.google.com/store/apps/details?id=app.docsera',
    updated_at = now()
WHERE id = 1;
```

Within minutes (next time each user opens the app), users on versions below 1.4.0 are blocked at the splash screen.

### When you ship a new release
Update `latest_version_ios` / `latest_version_android` so future "soft" update prompts (when added) know what to recommend. **Do not** raise `min_supported_version` unless the older version is genuinely unsafe — forcing updates is a strong action.

## How to verify

```bash
# On the VPS — confirm RPC works and returns the expected shape
ssh -p 2203 george@94.252.183.77 \
  "docker exec -i supabase-db psql -U postgres -d postgres -c \
   \"SELECT public.rpc_get_app_config();\""
```

Should return JSON with `min_supported_version_ios`, `min_supported_version_android`, store URLs, and message strings.

To verify the gate from the client side, temporarily set `min_supported_version_*` to a value above the currently-installed version, open the app, confirm the force-update screen appears with the correct localized message, then revert.

## What could go wrong

- **Setting `min_supported_version` higher than the latest version on the store.** Users would be locked out forever. **Always** ship the new version to the stores first, wait for it to be available in both regions, then bump the minimum.
- **Wrong store URLs.** "Update Now" button would 404. Test both URLs in a browser before flipping the switch.
- **Network failure on splash.** By design, the check fails open — users can use the app on a flaky connection. This means if you ever need the gate to activate on a partial-outage day, some users won't see it. Acceptable trade-off vs. blocking the entire user base on transient errors.
- **Version comparison ambiguity.** The comparator parses dotted-numeric segments only (e.g., `1.2.3`). Pre-release suffixes like `1.2.3-beta` are stripped to `1.2.3`. Avoid using non-numeric version strings.

## Score impact

8.0 → **8.3** (+0.3). Critical for a healthcare app's security posture, less impactful in immediate visible quality.
