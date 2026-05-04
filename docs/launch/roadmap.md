# Launch Roadmap

Living doc — updated after each completed step. Score is a subjective launch-readiness rating out of 10, where 10 = "I would put my own family on this app."

**Current score: 9.05 / 10**
**Last updated:** 2026-05-04

## Done

| # | Item | Doc | Score after |
|---|---|---|---|
| 1 | RLS lockdown on 5 critical tables | [01-rls-lockdown.md](01-rls-lockdown.md) | 8.0 |
| 2 | Forced-update mechanism | [02-forced-update.md](02-forced-update.md) | 8.3 |
| 3 | Crash reporting (Sentry) | [03-crash-reporting.md](03-crash-reporting.md) | 8.6 |
| 4 | Analytics — full system (backend tables + RBAC + ingestion/admin RPCs + Flutter SDK with offline queue + 86-event catalog + critical-path instrumentation + complete docs) | [04-analytics.md](04-analytics.md), [04a](04a-event-taxonomy.md), [04b](04b-admin-rpcs.md), [04c](04c-rbac-roles.md), [04d](04d-sample-queries.md) | 8.9 |
| 5 | Internal security review — 2 Critical + 3 High + 4 of 5 Medium fixes applied; cert-pinning deliberately deferred with documented rationale; build script with obfuscation; weekly cleanup cron; per-IP OTP rate limit; URL scrubber in Sentry | [05-security-review.md](05-security-review.md), [05a-pentest-brief.md](05a-pentest-brief.md), [06-ministry-license-playbook.md](06-ministry-license-playbook.md) | 9.05 |

## Pending — in priority order

| # | Item | Importance | Why it matters | Estimated time | Score after |
|---|---|---|---|---|---|
| 4 | **Analytics events** (Supabase `analytics_events` table + key events: signup, OTP success/fail, booking start/complete, message sent) | 🟠 High | Can't improve what you can't measure. Booking funnel + OTP success rate are the two metrics that tell you if the app *works* in the field. Lightweight, no extra infra. | 3–4h | 8.8 |
| 5 | **Pen test + security review** (auth, encryption, RPCs, edge functions) | 🔴 Critical | Healthtech is a high-value target. The RLS audit found one real hole; others may exist. External eyes find what we miss. | 2–4 days external, 1–2 days internal | 9.1 |
| 6 | **Privacy Policy + Terms of Service + Medical Disclaimer** (in-app screens + URLs for store listings, EN + AR) | 🔴 Critical | App stores reject medical apps without these. Also legally required for GDPR-aligned users. | 1 day to draft + 1 day legal review | 9.2 |
| 7 | **CI (GitHub Actions)** — `flutter analyze` + `flutter test` + Android build on every PR | 🟠 High | Catches regressions before they ship. Free for current usage. | 2–3h | 9.3 |
| 8 | **Resolve `untranslated_ar.txt`** | 🟠 High | Arabic is the default locale. Untranslated keys = English text in an Arabic UI. | 2–4h | 9.4 |
| 9 | **Performance pass** (`search_page`, `map_results_page`, `doctor_profile_page`) | 🟠 High | Highest-traffic screens. Profile first, then fix targeted issues. | 1–2 days | 9.5 |
| 10 | **Beta testing** (TestFlight + Play Internal, 2–4 weeks, ~20–50 real users) | 🔴 Critical | Single biggest crash-rate-reducer. Catches device-specific bugs solo testing misses. | Calendar 2–4 weeks; setup 3h | 9.7 |
| 11 | **Accessibility audit** (Semantics labels, contrast, dynamic-type) | 🟡 Medium | Healthtech serves elderly/visually-impaired patients. Legal in EU. | 1 day audit + 1–2 days fixes | 9.8 |
| 12 | **Dependency + bundle audit** (77 deps; `flutter build apk --analyze-size`) | 🟡 Medium | Likely 10–15 MB savings. Smaller install = higher conversion in low-bandwidth markets. | 4–6h | 9.9 |
| 13 | **App store assets** (per-locale screenshots, descriptions, icons, privacy nutrition labels) | 🟠 High | Required to publish. Underestimated time-sink. | 1 day | 10.0 |

## Total time budget

- **Engineering work I can do:** ~3–5 working days (#4, #7, #8, #9, #11, #12).
- **Human/external in-the-loop:** legal review (#6), pen test (#5), beta cycle (#10) — ~3–4 calendar weeks regardless of engineering velocity.

## Critical truth

The 9.7 → 10.0 last mile is **store assets and beta time**, not code. The score that most determines "is this safe in patients' hands" tops out at #5 (pen test) + #10 (beta). Plan calendar time for both starting now.
