# 07 — Legal Documents (Privacy / Terms / Medical Disclaimer / Report Abuse)

**Date:** 2026-05-05
**Score impact:** 9.05 → 9.2

## Summary

Four legal documents, in Arabic and English, hosted at `docsera.app`. They're the public-facing legal foundation for the app — required by the Syrian Ministry of Communications & Technology for the ترخيص, by Apple App Store, and by Google Play Store. Plus database-level consent tracking that builds an audit trail of which user accepted which version.

## What was built

### 1. Four published documents

| Document | URL | Version | Effective | Length |
|---|---|---|---|---|
| **Privacy Policy** (سياسة الخصوصية) | https://docsera.app/privacy-policy/ | 2.0 | 2026-05-05 | 397 lines |
| **Terms of Use** (شروط الاستخدام) | https://docsera.app/terms-of-service/ | 2.0 | 2026-05-05 | 331 lines |
| **Medical Disclaimer** (الإقرار الطبي) | https://docsera.app/medical-disclaimer/ | 1.0 | 2026-05-05 | 233 lines (NEW) |
| **Report Abuse** (الإبلاغ عن محتوى مخالف) | https://docsera.app/report-illicit-content/ | 1.1 | 2026-05-05 | refreshed |

All four are bilingual AR/EN with a language toggle and the existing visual style. Source files in `~/development/docsera-landing/public/<doc>/index.html`.

### 2. Version manifest (sidecar)

`https://docsera.app/legal/versions.json` — single JSON document the app fetches at startup to detect when a user must re-consent:

```json
{
  "documents": [
    { "code": "privacy_policy",     "version": "2.0", "effective_date": "2026-05-05", "requires_consent": true,  "url": "..." },
    { "code": "terms_of_service",   "version": "2.0", "effective_date": "2026-05-05", "requires_consent": true,  "url": "..." },
    { "code": "medical_disclaimer", "version": "1.0", "effective_date": "2026-05-05", "requires_consent": true,  "url": "..." },
    { "code": "report_illicit_content", "version": "1.1", "effective_date": "2026-05-05", "requires_consent": false, "url": "..." }
  ]
}
```

### 3. Database consent-tracking

Migration `20260505110000_user_legal_consents.sql` — `user_legal_consents` table + 2 RPCs (`rpc_record_legal_consent`, `rpc_get_my_legal_consents`). RLS-locked, accessed only via the RPCs.

Schema:
```
id, user_id, document_code, version, accepted_at,
app_version, platform, locale
UNIQUE (user_id, document_code, version)
```

This is the audit trail. For every user, you can prove which version they accepted, when, from which app version and platform.

### 4. Deletion lifecycle (Tier 1 → Tier 4)

Migration `20260505100000_account_deletion_lifecycle.sql` — three new user-callable RPCs:

| RPC | Purpose |
|---|---|
| `rpc_request_account_deletion()` | User-initiated permanent-deletion request. Sets `deletion_requested_at`. Account locked. 30-day window. |
| `rpc_cancel_account_deletion()` | Reverts within the 30-day window. |
| `rpc_get_account_deletion_status()` | Read-only status for the UI. |

Plus two operator-only RPCs:
- `fn_pseudonymize_user(uuid)` — scrubs personal columns; pseudonymizes denormalized snapshots in appointments + conversations + relatives; deletes user_devices; nulls user_id on analytics rows.
- `fn_hard_purge_user(uuid)` — full cascade-delete of all related rows.

Plus the orchestrator `fn_process_account_deletions()` that runs both passes daily.

**Daily cron installed on VPS:** `/etc/cron.daily/docsera-account-deletions`. Logs to `/var/log/docsera-account-deletions.log`.

Tested end-to-end: smoke runs return `{"pseudonymized": 0, "purged": 0}` (correct — no users in the lifecycle yet).

### 5. Permission cleanup

Removed during this step (verified unused in code):
- Android: `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`
- iOS: `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription`

Refactored: `_requestStoragePermission()` in `document_options_bottom_sheet.dart` now no-ops on modern Android (sandbox + scoped storage handle the save-as-PDF flow).

### 6. Flutter consent service

`lib/services/legal/legal_consent_service.dart`:
- `LegalConsentService.instance.recordConsent(documentCode:, version:)` — records consent for one doc.
- `LegalConsentService.instance.recordConsentForAll({...})` — for the signup flow's "I accept all" pattern.
- `LegalConsentService.instance.getMyConsents()` — reads back what the user accepted.
- `LegalDocumentCodes` constants for document codes.
- `LegalConsentService.urlFor(code, locale)` — returns `https://docsera.app/<doc>/?lang=ar` for in-app links.

## In-app UI wiring — complete

All three required UI surfaces are now wired:

### 1. Signup — three required consent checkboxes ✅
[lib/screens/auth/sign_up/terms_of_use_page.dart](../../lib/screens/auth/sign_up/terms_of_use_page.dart) was rewritten so the user must explicitly accept the Privacy Policy, Terms of Use, and Medical Disclaimer (three separate checkboxes). Each box has a tappable underlined link that opens the corresponding live document in `LaunchMode.inAppWebView` with the user's locale (`?lang=ar` or `?lang=en`). The Continue button is disabled until all three are checked. On Continue, the chosen versions are staged in `SharedPreferences['pending_legal_consents']` and the user proceeds with signup.

### 2. Post-auth replay ✅
[lib/main.dart](../../lib/main.dart) — the AuthCubit `Authenticated` listener now calls `_replayPendingLegalConsents()` which reads the staged versions and calls `rpc_record_legal_consent` for each. The RPC is idempotent on `(user_id, document_code, version)` so repeats are no-ops. After successful replay the SharedPreferences key is cleared. If the network call fails, the staged data remains for the next auth event.

### 3. Settings → Legal Information ✅
[lib/screens/home/account/legal_information.dart](../../lib/screens/home/account/legal_information.dart) now shows **four** entries instead of three: Terms of Use, Privacy Policy, **Medical Disclaimer (new)**, Report Illicit Content. All open the live URLs with the user's locale.

### 4. Re-consent gate (version bumps) ✅
[lib/services/legal/legal_versions_checker.dart](../../lib/services/legal/legal_versions_checker.dart) and [lib/widgets/legal_reconsent_gate.dart](../../lib/widgets/legal_reconsent_gate.dart) implement the version-mismatch detection and the blocking dialog.

How it works:
- The gate widget wraps `CustomBottomNavigationBar` from inside [lib/splash_screen.dart](../../lib/splash_screen.dart). It triggers on first build and on every app-foreground event via `WidgetsBindingObserver`.
- It fetches `https://docsera.app/legal/versions.json`, calls `rpc_get_my_legal_consents`, and computes the set of `requires_consent` documents whose current version differs from the user's last accepted version.
- If any pending docs exist, a non-dismissible modal appears with one checkbox per pending doc, a tappable link to view each one in-app, and a "Review and accept" button that calls `recordAcceptanceForPending(...)`. The dialog only closes after acceptance succeeds.
- If the manifest is unreachable (network blip, Syriatel hiccup), the check fails open and the user proceeds — no false-positive lockouts.
- Cached manifest is reused across foreground checks; an in-flight fetch is deduped so rapid foreground-toggle doesn't fire parallel HTTP requests.

### How to trigger a re-consent prompt for testing

Bump a version in `~/development/docsera-landing/public/legal/versions.json`, redeploy (hot-patch via `docker cp` or full Coolify rebuild), then reopen the app. The first foreground event after auth will show the dialog.

## Permanent deploy (next time you change a legal document)

The site is hosted via Coolify pulling `ghcr.io/georgezakhour/docsera-landing:latest`. Today's deploy was a hot-patch via `docker cp` so the changes are live now. **For permanent deploy of any future legal change:**

1. Edit the source HTML in `~/development/docsera-landing/public/<doc>/index.html`.
2. Bump `version` and `effective_date` in `~/development/docsera-landing/public/legal/versions.json`.
3. `cd ~/development/docsera-landing && npm run build`
4. Commit + push to your git repo. Coolify will rebuild and redeploy the container.
5. After deployment, the version-tracking system will auto-prompt users to re-consent.

If you want the changes live faster (before Coolify rebuild), repeat the `docker cp` hot-patch — it's safe and survives until the next image rebuild.

## What may still need updating ("v2.1 watch-list")

Per your direction, the documents reflect the **current state of the app** as of 2026-05-05. When the following features land, the relevant document should be bumped to v2.1 and users re-prompted to re-consent:

| Future change | Affects | What to update |
|---|---|---|
| **Comprehensive notification system** (push, email, SMS for many event types) | Privacy Policy §2 (How we use your data), §3.3 (technical providers if a new SMS or email provider is added), §11 (permissions) | Add the new notification categories explicitly and the opt-out mechanism |
| **Doctor tier visibility in app** (free-tier doctors with no booking button, etc.) | Terms of Use §1 (Service definition), §5 (Booking) | Disclose that some doctors' availability or features depend on their subscription |
| **Marketing emails (when you start sending them)** | Privacy Policy §2 (operational vs marketing communications), §1.1 (marketing_checked usage) | Describe marketing content, opt-in/opt-out flow, frequency cap |
| **In-app payments (if added)** | Terms of Use §5 (paid consultation fees), §8 (refunds and limitation of liability), Privacy Policy §1 (financial data) | New section on payment processing, PCI/SAMA compliance, refund policy |
| **Telehealth video calls (if added)** | Privacy Policy §1.2 (call metadata, recording policy), §5 (encryption of video) | New "video consultation" subsection |
| **AI-assisted features** (symptom check, document parsing, etc.) | Privacy Policy §1.3 (technical data), §3.3 (third-party AI provider if any), §2 (purposes) | Disclose AI usage, training-data exclusion, limitations |
| **New third-party service** (analytics SaaS, SMS provider, payment gateway, AI vendor, etc.) | Privacy Policy §3.3 | Add to the list with country of operation and exact data shared |
| **New permission requested** (Bluetooth, contacts, etc.) | Privacy Policy §11, Terms §3 | Add to permissions list |
| **Change of hosting / data residency** | Privacy Policy §4 | Update server location statement |
| **Major schema changes** (new patient-data type stored) | Privacy Policy §1.1 / §1.2 | Add the new data type explicitly |

When updating, follow the "permanent deploy" steps above and bump the version in `versions.json`. The app will then surface a re-consent prompt automatically once the in-app banner is wired (item 3 above).

## How to verify everything is live

```bash
# 1. All four pages return 200 with new content
for u in /privacy-policy/ /terms-of-service/ /medical-disclaimer/ /report-illicit-content/ /legal/versions.json; do
  curl -sL -o /dev/null -w "%{http_code} %{size_download}b $u\n" "https://docsera.app$u"
done

# 2. Database tables and functions exist
ssh -p 2203 george@94.252.183.77 'docker exec -i supabase-db psql -U postgres -d postgres -c "\\dt public.user_legal_consents"'

# 3. Cron job installed
ssh -p 2203 george@94.252.183.77 'sudo ls -la /etc/cron.daily/docsera-account-deletions /etc/cron.weekly/docsera-analytics-cleanup'

# 4. Permission cleanup applied
grep -E "QUERY_ALL_PACKAGES|MANAGE_EXTERNAL_STORAGE" android/app/src/main/AndroidManifest.xml || echo "✅ removed"
grep -E "NSLocationAlways" ios/Runner/Info.plist || echo "✅ removed"
```

All checks confirmed passing on 2026-05-05.
