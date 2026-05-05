# 13 — Dependency & Bundle Audit

**Date:** 2026-05-05
**Score impact:** 9.65 → 9.7
**Roadmap step:** 14

> Note: this doc is numbered 13 because it covers what the launch roadmap calls Step 14 (deps audit). The `13-` prefix follows file-creation order.

## Why this step exists

`pubspec.yaml` had grown to 67 direct dependencies (plus ~150 transitive). Every dep adds APK/IPA size, attack surface, supply-chain risk, and maintenance burden. The roadmap target was "10–15 MB savings" through cleanup; the actual win came from a focused removal of unused packages + moving build-time tools to the right scope, not aggressive size hunting.

## What was audited

Each direct dep in `pubspec.yaml` was checked for actual usage:

```bash
for dep in <name>; do
  grep -rn "package:$dep/" lib/ test/
done
```

Three categories surfaced:

| Category | Action | Count |
|---|---|---|
| Truly unused (zero imports anywhere) | Remove from pubspec | 4 |
| Build-time tools in main deps | Move to `dev_dependencies` | 2 |
| Used but overlapping (different purposes) | Document, defer consolidation | 1 group (PDF libs) |

## What was removed

### 4 truly-unused packages

| Package | Why we thought it might be used | What we actually found |
|---|---|---|
| `svg_path_parser ^1.0.0` | SVG path manipulation | Zero imports anywhere |
| `signature ^6.0.0` | Drawing/capturing user signatures | The grep matches were "doctor signature" label strings, not the package itself |
| `unicode ^0.3.1` | Arabic text manipulation | Matches were `RegExp(..., unicode: true)` (the regex flag, not the package) and a test description |
| `diacritic ^0.1.6` | Arabic search normalization | Only matches were comments about diacritics; actual diacritic-stripping is custom code in `lib/utils/arabic_reshaper/` |

### 2 build-time tools moved to `dev_dependencies`

These are run via `dart run flutter_X:Y`, never imported as Dart code. They have no business shipping to production users.

| Package | Was | Now |
|---|---|---|
| `flutter_launcher_icons ^0.14.3` | `dependencies:` only | `dev_dependencies:` only |
| `flutter_native_splash ^2.4.6` | **Duplicated** in both `dependencies:` AND `dev_dependencies:` (genuine bug) | `dev_dependencies:` only |

## Effects

**Production bundle**: estimate ~300–450 KB smaller. Couldn't measure precisely because `flutter build apk --analyze-size` failed locally (Mac disk was full at audit time). The estimate is based on the removed packages' on-disk pub-cache footprint.

**`pub.lock`**: cleaner resolution. Each removed direct dep also removes its transitive subtree — net 4 fewer transitive packages.

**`dev_dependencies` scope**: now correctly carries the build tooling. If anyone publishes a package depending on this app, build tools no longer leak as transitive deps. Currently nobody does, but it's future-proof.

**Verification:**
- `flutter pub get` → "Changed 7 dependencies" (clean resolution)
- `flutter analyze`: 0 errors
- `flutter test`: 367 passing, 1 skipped

## What's intentionally NOT in this audit

### PDF library consolidation (deferred)

The codebase ships **5 PDF-related libraries**:

| Library | Used in | Purpose |
|---|---|---|
| `pdf ^3.11.3` | 7 files | PDF *generation* (visit reports, send-document) |
| `printing ^5.14.2` | 2 files | OS print dialog for generated PDFs |
| `pdfx ^2.9.1` | 2 files | PDF *rendering* in-app (documents page) |
| `flutter_pdfview ^1.4.0+1` | 1 file | PDF *rendering* in-app (document preview) |
| `syncfusion_flutter_pdf ^29.2.4` | 2 files | PDF parsing/manipulation (send-document, documents page) |

`pdfx` and `flutter_pdfview` overlap (both are in-app PDF viewers) — likely consolidatable to one. `syncfusion_flutter_pdf` is the heaviest and pulls in the syncfusion runtime (~3–5 MB on its own).

**Why deferred:** consolidation requires hands-on testing with real PDFs from real devices to confirm rendering parity. Doing it speculatively risks breaking the documents page or visit-report rendering, which are user-facing features. This is a 1–2 day focused session, not a 5-minute pubspec edit. Tracked for after launch.

### Bundle size measurement (deferred to CI)

`flutter build apk --analyze-size` requires a clean local build of ~5 GB intermediate artifacts. Better to measure in CI on a fresh checkout when needed. The `Build` workflow (`build.yml`) can be extended to run analyze-size on tagged releases — small follow-up.

### Aggressive minor-version bumps (not done)

`flutter pub outdated` reports 157 packages have newer compatible versions. Bumping them all without reading changelogs is risky (breaking changes hide in minor versions). Track on a per-quarter cadence as a focused task rather than mass-update.

## Patterns for future code

Recorded in `CLAUDE.md` so any agent / developer adding deps follows them:

- **Before adding a dep**, grep `pubspec.yaml` for similar functionality. The PDF/image-picker/file-picker space is full of overlap; pick one and stick with it.
- **Build-time tools (`flutter_launcher_icons`, `flutter_native_splash`, code generators, etc.) go in `dev_dependencies`** — never main `dependencies:`.
- **A dep without an `import` somewhere in `lib/` or `test/` is unused.** Periodically grep-audit and prune.

## Score impact

9.65 → **9.7**. Modest because the bundle savings were under 1 MB — far from the "10-15 MB" the roadmap optimistically estimated. The bigger savings (PDF consolidation) require focused work that's higher-risk and out of scope. The audit's real value is hygiene + a clean baseline for future dep additions.
