# Step 19 — Lint cleanup to zero + regression ratchet

**Date completed:** 2026-05-17
**Spec:** [docs/superpowers/specs/2026-05-16-lint-cleanup-to-zero-design.md](../superpowers/specs/2026-05-16-lint-cleanup-to-zero-design.md)
**Plan:** [docs/superpowers/plans/2026-05-16-lint-cleanup-to-zero-plan.md](../superpowers/plans/2026-05-16-lint-cleanup-to-zero-plan.md)

## What happened

`flutter analyze` was driven from **335 issues to 0** in the DocSera patient app, across 5 phases. The final ratchet promotes the dangerous lints to compiler errors so they cannot regress without breaking the build.

| Phase | What | Issues removed |
|---|---|---|
| 0 — Pre-flight | Cleared 2 errors from orphaned NotificationToastOverlay port (`e222836`) | 335 → 333 |
| 1 — Mechanical | unused imports/vars/fields/elements + prints → debugPrint + style fixes + file_names renames | 333 → 211 (-122) |
| 2 — Deprecated APIs | Color component getters, SVG `color:` → `colorFilter:`, WillPopScope → PopScope, withOpacity, GoogleMap.style, Geolocator.locationSettings, QR styles, Supabase `.execute()`, etc. | 211 → 157 (-54) |
| 3 — `use_build_context_synchronously` | 157 BuildContext-after-await fixes across 47 files, in 9 batches | 157 → 0 (-157) |
| 4 — Ratchet | Promoted `use_build_context_synchronously` + `unused_*` + `avoid_print` + `deprecated_member_use` from `info` → `error` in `analysis_options.yaml` | 0 → 0 |

## Phase 3 patterns (use_build_context_synchronously)

Every BuildContext-after-await call was classified into one of these patterns before fixing:

| Pattern | Shape | Fix |
|---|---|---|
| **A** | `setState` after await | `if (!mounted) return;` before `setState` |
| **B** | `Navigator.of(context).pop/push` after await | Cache `final nav = Navigator.of(context);` BEFORE await, mounted check after |
| **C** | `ScaffoldMessenger.of(context).showSnackBar` after await | Cache messenger before await, mounted check after |
| **D** | `context.read<Cubit>()` after await | Cache cubit BEFORE await; cubit refs survive unmount safely |
| **E** | `showDialog` / `showModalBottomSheet` after await | Cache Navigator + mounted check |
| **F** | Provably safe (e.g., context re-read via `navigatorKey.currentContext` each invocation) | Inline `// ignore: use_build_context_synchronously` with one-line justification |

**Strict rules followed throughout Phase 3:**
- Sequential, file-by-file. **No parallel subagents** (per multi-agent loss-prevention memory).
- Batch commit every 3-5 files. Push after every commit.
- Never `// ignore_for_file:` — that defeats the ratchet.
- Inline `// ignore:` allowed only with one-line justification; auditable list below.

## Commit hashes

**Pre-flight:**
- `e222836` — chore(main): drop orphaned notification-toast port; keep SystemUI overlay

**Phase 1 (mechanical, 333 → 211):**
- `6b88613` — step 1a — drop unused imports + locals (333 → 293)
- `2739bcc` — step 1b — drop unused fields/elements (293 → 244)
- `73517d8` — step 1c — print statements gated via debugPrint (244 → 228)
- `3367cd3` — step 1d — style fixes (braces, const, override, immutability, deps) (228 → 213)
- `3512845` — step 1e — rename files to satisfy file_names rule (213 → 211)

**Phase 2 (deprecated API migration, 211 → 157):**
- `e05f91b` — step 2a — Color component getter migration (211 → 202)
- `58dd601` — step 2b — SVG color → colorFilter migration (202 → 189)
- `e8dd6d4` — step 2c — misc deprecated API migration (189 → 157)

**Phase 3 (`use_build_context_synchronously`, 157 → 0):**
- `0c4106d` — B1: appointment_details_page (157 → 142)
- `fdf1994` — B2: login flow — login_page + login_otp (142 → 126)
- `8a51216` — B3: signup flow — validation + sign_up_phone + sign_up_email (126 → 108)
- `8586e63` — B4: doctor appointment flow — send_document + appointment_confirm + select_patient_page (108 → 90)
- `1608bf6` — B5: bottom_nav + login_start (90 → 79)
- `aeadb18` — B6: relatives — edit_relative + add_relative + my_relatives (79 → 66)
- `7ec2d44` — B7: documents — 6 files (66 → 51)
- `736c7c6` — B8: messages — 7 files (51 → 36)
- `a233f80` — B9: long-tail — 21 files (36 → 0)

**Phase 4 (ratchet):**
- `c5815cd` — chore(lint): promote risky lints to errors

## Inline `// ignore:` directives added

Only one inline ignore was added in the entire Phase 3 cleanup. Spot-auditable:

- `lib/services/notifications/notification_service.dart:1059` — `// ignore: use_build_context_synchronously` — `context` is re-read from `navigatorKey.currentContext` on each invocation of `_handleNotificationTap`; the analyzer's async-gap heuristic can't see through the closure capture but the context IS fresh at the point of use.

## How to verify after the fact

```bash
~/development/flutter/bin/flutter analyze
# Expected: No issues found!

~/development/flutter/bin/flutter test
# Expected: All tests passed!
```

If `flutter analyze` shows ANY new lint of a promoted-to-error rule after this point, that's a regression — fix forward, never bypass.

To temporarily silence a single legitimate occurrence:

```dart
// ignore: use_build_context_synchronously
// (one-line justification on the line above)
```

NEVER use `// ignore_for_file:` for a promoted rule.

## What this work did NOT do

- Refactored only what the lint required. No drive-by cleanup.
- Did NOT remove the dead `lib/screens/doctors/doctor_panel/` and `lib/screens/doctors/auth/` directories (leftover from before DocSera and DocSera-Pro split). Those were kept compiling but are still unused — separate architectural cleanup, not lint scope.
- Did NOT bump dependency versions. The 7 `depend_on_referenced_packages` findings got missing entries added to `pubspec.yaml` without version pins.
- Did NOT touch DocSera-Pro or DocSera-Admin (separate repos).
- Did NOT add new tests.

## What's NOT in this commit but worth noting

- The FCM agent's parallel work landed during this cleanup (commits `8c6b8f3`, `cc89f42`, `69600c2`, plus AES-GCM migration on a feature branch). These were intentionally kept separate; my commits only touched files relevant to lint cleanup.
- The half-finished `NotificationToastOverlay` port from DocSera-Pro that was sitting in `lib/main.dart`'s working tree at the start of this cleanup was surgically reverted in `e222836` (preserved the unrelated SystemUI overlay change that matches Pro's main.dart). See that commit message for the full investigation.

## Build verification recommendation

The native build workflow hasn't been run during this cleanup. Recommend running it before relying on these commits in production:

```bash
gh workflow run build.yml
```

Reason: while Phase 3 changes are pure Dart, they touch ~50 files including authentication, navigation, document upload, and the bottom nav bar — all paths that exercise the full native stack. The SystemUI overlay change in `e222836` also touches Android behavior.
