# DocSera Launch Documentation

Operator-focused docs for everything done in preparation for the public launch of the DocSera patient app. Each numbered file documents one work item: what changed, why, how to operate it, how to verify it's working, and what could go wrong.

## Index

| # | Doc | Status | Score after |
|---|---|---|---|
| 01 | [RLS lockdown on 5 tables](01-rls-lockdown.md) | ✅ Done | 8.0 / 10 |
| 02 | [Forced-update mechanism](02-forced-update.md) | ✅ Done | 8.3 / 10 |
| 03 | [Crash reporting (Sentry)](03-crash-reporting.md) | ✅ Done | 8.6 / 10 |
| 04 | [Analytics — overview & architecture](04-analytics.md) | ✅ Done | 8.9 / 10 |
| 04a | [Event taxonomy (the contract)](04a-event-taxonomy.md) | ✅ Done | — |
| 04b | [Admin RPCs (admin panel API)](04b-admin-rpcs.md) | ✅ Done | — |
| 04c | [Admin RBAC: roles & permissions](04c-rbac-roles.md) | ✅ Done | — |
| 04d | [Sample SQL queries](04d-sample-queries.md) | ✅ Done | — |
| 05 | [Internal security review (findings + fixes)](05-security-review.md) | ✅ Done | 9.0 / 10 |
| 05a | [Pen-test brief (ministry submission doc)](05a-pentest-brief.md) | ✅ Done | — |
| 06 | [Syrian Ministry License (ترخيص) — full playbook](06-ministry-license-playbook.md) | 📚 Living reference | — |
| 07 | [Legal documents (Privacy / Terms / Medical Disclaimer / Report Abuse) + deletion lifecycle + consent tracking + in-app UI](07-legal-documents.md) | ✅ Done | 9.2 / 10 |
| 08 | [CI / GitHub Actions (analyze + tests + Android build + iOS build)](08-ci-github-actions.md) | ✅ Done | 9.3 / 10 |
| 09 | [Comprehensive test strategy (367 tests, 9 integration funnels, encryption guard)](09-test-strategy.md) | ✅ Done | 9.4 / 10 |
| — | Lint cleanup sweep (1068 → 275 analyzer issues, silent RTL bug caught and fixed) | ✅ Done | 9.42 / 10 |
| — | iOS pbxproj cleanup (11 spurious xcframework refs removed; CI iOS gate strict) | ✅ Done | 9.43 / 10 |
| — | Untranslated Arabic — 33 new l10n keys + 2 security fixes (OTP debug-leak gated, dead Doctor ID widget removed) | ✅ Done | 9.45 / 10 |
| 10 | [Performance pass — 4 setState/N+1 antipatterns fixed on hot screens](10-perf-pass.md) | ✅ Done | 9.55 / 10 |
| 12 | [Accessibility audit — contrast fixes + tooltips + patterns](12-accessibility.md) | ✅ Done | 9.65 / 10 |
| — | [Full roadmap & score progression](roadmap.md) | Living doc | — |

## How to use these docs

- **Before launch** — read top-to-bottom to understand the security and operational posture of the app.
- **For App Store / Play Store review** — relevant excerpts go into the privacy and security sections of the submission.
- **When something breaks at 2am** — find the relevant doc, follow the verification commands.
- **When hiring or onboarding** — give a new dev this folder; they'll be productive in a day.

## Conventions

Every doc has the same shape:
1. **Summary** — one-paragraph what + why.
2. **What changed** — files, tables, infra.
3. **How to operate it** — daily commands.
4. **How to verify** — copy-pasteable checks.
5. **What could go wrong** — known failure modes.
6. **Score impact** — what this moved on the launch-readiness scale.
