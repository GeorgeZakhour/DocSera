# Launch Roadmap

Living doc — updated after each completed step. Score is a subjective launch-readiness rating out of 10, where 10 = "I would put my own family on this app."

**Current score: 9.4 / 10**
**Last updated:** 2026-05-05

## Done

| # | Item | Doc | Score after |
|---|---|---|---|
| 1 | RLS lockdown on 5 critical tables | [01-rls-lockdown.md](01-rls-lockdown.md) | 8.0 |
| 2 | Forced-update mechanism | [02-forced-update.md](02-forced-update.md) | 8.3 |
| 3 | Crash reporting (Sentry) | [03-crash-reporting.md](03-crash-reporting.md) | 8.6 |
| 4 | Analytics — full system (backend tables + RBAC + ingestion/admin RPCs + Flutter SDK with offline queue + 86-event catalog + critical-path instrumentation + complete docs) | [04-analytics.md](04-analytics.md), [04a](04a-event-taxonomy.md), [04b](04b-admin-rpcs.md), [04c](04c-rbac-roles.md), [04d](04d-sample-queries.md) | 8.9 |
| 5 | Internal security review — 2 Critical + 3 High + 4 of 5 Medium fixes applied; cert-pinning deliberately deferred with documented rationale; build script with obfuscation; weekly cleanup cron; per-IP OTP rate limit; URL scrubber in Sentry | [05-security-review.md](05-security-review.md), [05a-pentest-brief.md](05a-pentest-brief.md), [06-ministry-license-playbook.md](06-ministry-license-playbook.md) | 9.05 |
| 6 | Legal documents — Privacy Policy, Terms of Use, Medical Disclaimer (new standalone), Report Abuse — all v1.0 pre-launch baseline, AR+EN, deployed live; deletion lifecycle (3-tier model + daily cron); consent-tracking DB + Flutter service; permission cleanup (QUERY_ALL_PACKAGES, MANAGE_EXTERNAL_STORAGE, iOS Location-Always all removed); in-app UI wiring (signup 3 checkboxes, settings 4 items, splash re-consent gate, locale-aware URLs) | [07-legal-documents.md](07-legal-documents.md) | 9.2 |
| 7 | CI (GitHub Actions) — analyze + tests + Android debug build (green) + iOS simulator build (non-blocking until Step 9b); APK uploaded as artifact; AGP 8.9.1 / Kotlin 2.1.0 in settings.gradle pluginManagement; dead Firebase config removed; stale tests parked in `test/_pending_rewrite/` | [08-ci-github-actions.md](08-ci-github-actions.md) | 9.3 |
| 8 | Test strategy + suite — **302 tests** (+242 from baseline of 60), 1 skipped: infrastructure (`test/_helpers/`); model round-trips (Message, Document, Conversation, Note, AppointmentDetails, PatientProfile, Banner+Section, Offer, Voucher, Partner, Gift, Promotion, PopupBanner, Referral, SignUpInfo, HomeCard); utility tests (ErrorHandler, text-direction, deep-link validator security tripwire, color, doctor image, shared_prefs, time edge cases); cubit tests (auth, user, appointments + extended, notes, documents, conversation, health-profile-wizard, partner); **encryption tests** (21, AES-256-CBC text + bytes round-trips, tamper detection, wrong-key fail-soft, lifecycle); seven integration funnels (auth, booking, messaging incl. encryption, document-upload, notes-RLS contract, documents-RLS contract, deep-link); widget tests (OfflineBanner, wizard, complete-profile-banner, partner widgets, loyalty cards); CI runs with `--coverage` and uploads `lcov.info` artifact | [09-test-strategy.md](09-test-strategy.md) | 9.4 |

## Pending — in priority order

| # | Item | Importance | Why it matters | Estimated time | Score after |
|---|---|---|---|---|---|
| 4 | **Analytics events** (Supabase `analytics_events` table + key events: signup, OTP success/fail, booking start/complete, message sent) | 🟠 High | Can't improve what you can't measure. Booking funnel + OTP success rate are the two metrics that tell you if the app *works* in the field. Lightweight, no extra infra. | 3–4h | 8.8 |
| 5 | **Pen test + security review** (auth, encryption, RPCs, edge functions) | 🔴 Critical | Healthtech is a high-value target. The RLS audit found one real hole; others may exist. External eyes find what we miss. | 2–4 days external, 1–2 days internal | 9.1 |
| 6 | **Privacy Policy + Terms of Service + Medical Disclaimer** (in-app screens + URLs for store listings, EN + AR) | 🔴 Critical | App stores reject medical apps without these. Also legally required for GDPR-aligned users. | 1 day to draft + 1 day legal review | 9.2 |
| 9 | **Lint cleanup sweep** — burn down the ~1000+ analyzer warnings & infos: unused imports, unused locals, dead null-aware ops, withOpacity → withValues codemod, Unicode bidi marks in literals, must_be_immutable, etc. After this, tighten CI to be strict on warnings (`--fatal-warnings`). | 🟡 Medium | Not blocking but compounding tech debt. Once cleaned, every new warning becomes a real signal instead of background noise, and CI can enforce it. | 4–6h | 9.42 |
| 9b | **Re-enable strict iOS CI build** — clean up the 4 hardcoded PBXFileReference entries in `ios/Runner.xcodeproj/project.pbxproj` that point at `Flutter/Release/{App,Flutter}.xcframework`, then flip `continue-on-error: false` on the build-ios job. Local Xcode builds keep working unchanged. | 🟡 Medium | iOS CI currently passes-by-warning; once cleaned, it becomes a real gate. | 1–2h | 9.43 |
| 10 | **Resolve `untranslated_ar.txt`** | 🟠 High | Arabic is the default locale. Untranslated keys = English text in an Arabic UI. | 2–4h | 9.45 |
| 11 | **Performance pass** (`search_page`, `map_results_page`, `doctor_profile_page`) | 🟠 High | Highest-traffic screens. Profile first, then fix targeted issues. | 1–2 days | 9.55 |
| 12 | **Beta testing** (TestFlight + Play Internal, 2–4 weeks, ~20–50 real users) | 🔴 Critical | Single biggest crash-rate-reducer. Catches device-specific bugs solo testing misses. | Calendar 2–4 weeks; setup 3h | 9.7 |
| 13 | **Accessibility audit** (Semantics labels, contrast, dynamic-type) | 🟡 Medium | Healthtech serves elderly/visually-impaired patients. Legal in EU. | 1 day audit + 1–2 days fixes | 9.8 |
| 14 | **Dependency + bundle audit** (77 deps; `flutter build apk --analyze-size`) | 🟡 Medium | Likely 10–15 MB savings. Smaller install = higher conversion in low-bandwidth markets. | 4–6h | 9.9 |
| 15 | **App store assets** (per-locale screenshots, descriptions, icons, privacy nutrition labels) | 🟠 High | Required to publish. Underestimated time-sink. | 1 day | 10.0 |

## Total time budget

- **Engineering work I can do:** ~3–5 working days (#4, #7, #8, #9, #11, #12).
- **Human/external in-the-loop:** legal review (#6), pen test (#5), beta cycle (#10) — ~3–4 calendar weeks regardless of engineering velocity.

## Critical truth

The 9.7 → 10.0 last mile is **store assets and beta time**, not code. The score that most determines "is this safe in patients' hands" tops out at #5 (pen test) + #10 (beta). Plan calendar time for both starting now.
