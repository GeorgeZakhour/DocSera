# Pending Follow-ups

**Last updated:** 2026-05-06

A scratchpad for items that came up during reviews / external feedback but haven't been worked yet. **Not part of the official roadmap steps** — these are operational/perf/quality follow-ups to discuss and prioritize when the user is ready.

> **Important for any agent:** do **not** silently start working through this list. The user wants to review and prioritize each item before any of it is touched. Wait for explicit go-ahead.

---

## From external code review (received 2026-05-06)

A second-opinion agent reviewed the codebase and flagged six items that the prior reviews / roadmap steps didn't address. The user asked to record these for later discussion.

### 1. 🟡 19 `Image.network` calls still uncached
**Estimated effort:** 30 min
**Why it matters:** every uncached `Image.network` re-downloads the bytes on every rebuild — wastes bandwidth (precious in Syria's network conditions), wastes battery, and causes visible flicker. The codebase already imports `cached_network_image` (verified in pubspec deps audit Step 14), so the fix is mechanical: replace `Image.network(url)` → `CachedNetworkImage(imageUrl: url)`.
**Risk:** very low. Same API surface, same crash semantics; just adds caching.
**Where to start:** `grep -rn "Image\.network" lib/`.

### 2. 🟡 24 PNGs not converted to WebP
**Estimated effort:** 30 min
**Why it matters:** WebP at the same visual quality is typically 25–35% smaller than PNG. With 24 PNGs in the bundle, this is real APK/IPA size reduction. Roadmap Step 14 (deps audit) flagged this category as deferred; this is the concrete to-do.
**How:** `cwebp -q 85 in.png -o out.webp` per file, then update asset references in code/pubspec.yaml. Test that transparency-sensitive images (logos with transparent backgrounds) still render correctly.
**Risk:** low — but verify each converted image visually before committing. A bad conversion shows up as compression artifacts on launch.

### 3. 🟠 Search is still client-side
**Estimated effort:** half day
**Why it matters:** as the doctor list grows past a few hundred, fetching the whole list to filter in-app becomes wasteful (bandwidth + memory). Server-side search (Postgres `to_tsvector` or a dedicated search RPC) scales better and also enables fuzzy matching, ranking, etc.
**Risk:** medium — touches core functionality. Need a real RPC + integration test against the mock service we already use. The Step 8 test infrastructure (`_helpers/fixtures.dart`) is already in place to verify behavior.
**Where to start:** `lib/services/supabase/supabase_search_service.dart` and the Step 11 search debouncer (which is already in place — server-side search compounds the wins).

### 4. 🟠 Splash screen is still 5.4 seconds
**Estimated effort:** 2-3 hours
**Why it matters:** App store reviewers (especially Apple) are quick to flag "slow startup" as a UX issue. Beyond that, 5.4s is a brutal first impression for a new user. Industry target is <2s on a mid-range device.
**Probable causes** (need to profile to confirm):
- Sequential `await` in initializers (Sentry → Supabase → Pushy → notifications) where parallel would work
- Heavy `flutter_native_splash` config or large splash assets
- `_init()` in AuthCubit doing too much before first frame
**Where to start:** `lib/main.dart` and `lib/splash_screen.dart`. Run with `--profile` and check the timeline.
**Risk:** medium — startup ordering matters. Some inits genuinely depend on others; need to verify before parallelizing.

### 5. 🔴 Sentry only captures 1 exception — 109 silent `catch (_)` blocks
**Estimated effort:** half day (108 sites to triage; not all need Sentry)
**Why it matters:** This is the single biggest observability gap in the codebase. Step 3 (Sentry) gave us crash visibility, but a silent `try { ... } catch (_) { /* ignore */ }` swallows the exception entirely — Sentry never sees it. In healthcare app specifically, you absolutely need to know when a `book_appointment` or `send_message` silently fails.
**The right fix is NOT to add `Sentry.captureException` to all 109.** Many of those `catch (_)` blocks are correct: defensive code for non-critical paths (e.g. "log the cache write failure but don't bother the user"). The fix is:
1. Triage all 109 sites
2. For each: is this swallowing a critical error? If yes → `Sentry.captureException(e, stackTrace: st)`. If no → leave as-is OR add a `// intentional swallow: <reason>` comment so future agents don't add Sentry.
3. Document the decision pattern in CLAUDE.md
**Risk:** low if done carefully (just adding error reports), but high if done sloppily (Sentry quota burn from non-critical errors).
**Where to start:** `grep -rn "catch (_)\|catch (e) {}" lib/ --include="*.dart"` then triage by file.

### 6. 🟠 No offline caching
**Estimated effort:** 1-2 days
**Why it matters:** healthcare data is *most* valuable when network is bad — patient at clinic without WiFi, doctor reviewing records on a slow connection. Without offline caching, the app is unusable in those scenarios. The current `SharedPrefsService.saveCachedData` partially exists (used for appointments and favorites), but it's:
- Not consistent across data types (some use it, some don't)
- Not encryption-aware (cached medical records would land in shared_prefs unencrypted)
- Not invalidation-aware (no TTL or version check)
**Probable solution:**
- Audit which screens *should* work offline (probably: appointments list, health profile, visit reports)
- Use `flutter_secure_storage` or an encrypted Hive box for the actual records (must respect the AES key model from Step 5 security review)
- Add a "stale data" UI indicator for offline-rendered content
**Risk:** medium — touches the encryption boundary. Must verify with the security-review approach (Step 5) that cached data is encrypted at rest.

---

## Priority recommendation (when revisited)

If/when the user wants to work through these, the order I'd recommend:

1. **#5 — Sentry silent exceptions** (🔴 critical observability gap)
2. **#1 + #2 — Image caching + WebP** (cheap wins, ~1 hour total)
3. **#4 — Splash time** (visible user impact, store-review risk)
4. **#6 — Offline caching** (high-value but biggest scope)
5. **#3 — Server-side search** (only matters once you have many doctors)

But the user hasn't agreed to this order — that's just my read of cost/value.

---

## Other deferred items recorded earlier in the roadmap

For completeness, these are also pending and tracked elsewhere:

- **PDF library consolidation** (5 PDF libs ship: `pdf`, `printing`, `pdfx`, `flutter_pdfview`, `syncfusion_flutter_pdf` — `pdfx` and `flutter_pdfview` overlap; consolidation is a 1–2 day session). Tracked in `13-deps-bundle-audit.md`.
- **iOS Privacy Manifest (`ios/Runner/PrivacyInfo.xcprivacy`)** — Apple-required since May 2024 for SDKs that touch sensitive APIs. Tracked in `14-app-store-assets.md` (and CLAUDE.md "App Store submission" section).
- **Sentry release tagging** — tag each beta/release build with version (e.g. `1.0.0-rc.1`) so Sentry groups crashes per build. Tracked in `14-app-store-assets.md`.
- **Two UI bugs visible in marketing screenshots** — voice-message timer inverted (`0:27 / 0:00`); booking-page Arabic phrasing awkward (`هذا الموعد محجوز أصلاً 15 دقيقة`). Tracked in `14-app-store-assets.md`.
- **Doctolib leak in ARB** — `lib/l10n/app_en.arb:189` `authorizationStatement` says "Doctolib services" instead of "DocSera services" — leftover from a template. Should be fixed before submission.
- **Login page widget test** — deferred during Step 8 because of `BiometricStorage` / `local_auth` platform-channel mocking complexity. Tracked in `09-test-strategy.md`.
- **Coverage trend gate in CI** — needs baseline lcov first. Tracked in `09-test-strategy.md`.
- **Reconsent dialog widget test** — `_ReconsentDialog` is private; needs API surface change to be testable. Tracked in `09-test-strategy.md`.
- **AuthRepository RPC-shaped paths** — mocktail can't ergonomically mock `PostgrestFilterBuilder`. Covered indirectly via the auth-funnel integration test but not the rpc-shaped methods directly. Tracked in `09-test-strategy.md`.

---

## How to use this doc

When the user says *"let's work on the follow-ups"*, point them here and ask which item(s) they want to tackle. Don't pick one autonomously — these are all real-but-not-blocking, and the user's mood and available time should determine which makes sense to do.
