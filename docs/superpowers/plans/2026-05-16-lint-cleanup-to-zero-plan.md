# Lint Cleanup to Zero — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drive `flutter analyze` from 333 issues to 0 in the DocSera patient app, then ratchet `analysis_options.yaml` to prevent regression. Zero behavior change. Each sub-phase ends with a commit + push so multi-session work is durable.

**Architecture:** 5 phases ordered by risk (mechanical → deprecated → BuildContext → ratchet → sign-off). Resumability via commit-per-sub-phase, with `analyze: <before> -> <after>` embedded in every commit message so progress is grep-able from `git log`.

**Tech Stack:** Flutter (Dart SDK ≥3.6.0), `flutter_test`, `flutter analyze`. No new tools.

**Spec:** [docs/superpowers/specs/2026-05-16-lint-cleanup-to-zero-design.md](../specs/2026-05-16-lint-cleanup-to-zero-design.md)

**Repo scope:** `/Users/georgezakhour/development/DocSera` ONLY. DocSera-Pro and DocSera-Admin are out of scope.

---

## Conventions used in this plan

- **`flutter`** = the binary at `~/development/flutter/bin/flutter` (Flutter is not on PATH).
- **Analyzer count check:** `~/development/flutter/bin/flutter analyze 2>&1 | tail -1` returns a line like `333 issues found.` or `No issues found!`.
- **Per-rule count:** `~/development/flutter/bin/flutter analyze 2>&1 | grep "•" | awk -F'•' '{print $NF}' | sort | uniq -c | sort -rn`
- **Per-rule listing:** `~/development/flutter/bin/flutter analyze 2>&1 | grep "<rule_name>"`
- **Commit message format:** trailer always ends with `analyze: <before> -> <after>` so a future session can `git log --oneline | grep "analyze:"` to verify state. Always include the standard `Co-Authored-By:` trailer per CLAUDE.md.
- **Push after every commit.** No WIP-held-across-sessions per the user's `feedback_commit_and_push_aggressively` memory.
- **No parallel subagents in Phase 3.** Strictly sequential.

---

## Phase 0 — Baseline gate

### Task 0.1: Verify clean working tree and test green

**Files:** none modified

- [ ] **Step 1: Verify clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` on `main`, ahead of nothing.

If dirty: STOP. Investigate. Do NOT proceed with lint work on a dirty tree.

- [ ] **Step 2: Verify baseline analyzer count**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `333 issues found.`

If different: the codebase has moved since this plan was written. Re-confirm phase counts before proceeding (each phase header has the count it expects to remove).

- [ ] **Step 3: Run the full test suite**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -20
```

Expected: `All tests passed!` (or equivalent green).

If red: STOP. The failing test(s) are an independent problem. Fix and commit them as a standalone commit BEFORE Phase 1. Do not bundle the fix with lint cleanup.

- [ ] **Step 4: Boot the app once on iOS simulator**

```bash
~/development/flutter/bin/flutter run -d "iPhone" --dart-define-from-file=dart_defines/sentry.json &
```

Wait until you see `Flutter run key commands.` Then hot-reload (`r`) once and quit (`q`). This confirms the app builds and boots in its current state — anything that breaks during Phases 1-4 is caused by your changes, not pre-existing.

If the build fails to start: investigate before any lint work.

- [ ] **Step 5: Record baseline**

No commit needed — this is a verification phase only. Record in your scratch notes: `Baseline: 333 issues, tests green, app boots.`

---

## Phase 1 — Mechanical deletions (122 → expected target 211)

### Task 1a: Drop unused imports + local variables (39 issues)

**Files:** Various — discovered via analyzer.

- [ ] **Step 1: Inventory unused_import (2)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep -E "unused_import|unnecessary_import"
```

This outputs lines like:
```
warning • Unused import: 'package:docsera/models/appointment_details.dart' • test/models/appointment_details_test.dart:2:8 • unused_import
```

- [ ] **Step 2: Delete each unused import**

For each line in the inventory, use the Read tool to open the file at the cited line, confirm the import is genuinely unused (`grep` the symbol it exports in the same file — if zero references, safe to delete), then use the Edit tool to remove the import line.

DO NOT delete an import that is actually referenced — the analyzer is right ~99% of the time, but on the 1% case it's wrong, you'd break compilation. The grep step is the safety net.

- [ ] **Step 3: Inventory unused_local_variable (36)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "unused_local_variable"
```

- [ ] **Step 4: Fix each unused local variable**

For each, two options:
1. **If the variable was assigned from a function call with side effects** (e.g. `final result = await someAsyncCall();` where you don't need `result`): keep the call, drop the assignment → `await someAsyncCall();`.
2. **If the variable was assigned from a pure expression with no side effects** (e.g. `final x = computeFoo();` and `computeFoo()` has no side effects): delete the entire line.
3. **If keeping the name is documentation** (rare): prefix with `_` → `final _result = await someAsyncCall();` to silence the lint. Use sparingly.

Use the Read tool first to see the surrounding context before choosing the option.

- [ ] **Step 5: Verify analyzer count dropped**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `294 issues found.` (333 - 39 = 294)

If off by 1-2: re-check the inventory (maybe a follow-up `unused_local_variable` appeared after deleting a wrapping line). If off by more: STOP, investigate.

- [ ] **Step 6: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

If red: a delete broke something. `git diff` to see what changed; the breakage is in the most recently modified file.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 1a — drop unused imports + locals

Mechanical cleanup of 39 unused_import / unnecessary_import / unused_local_variable
findings. No behavior change. Each delete was verified by reading the
surrounding context and confirming the symbol/variable had zero references.

analyze: 333 -> 294

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

### Task 1b: Drop unused fields, elements, element parameters (48 issues)

**Files:** Various — discovered via analyzer.

- [ ] **Step 1: Inventory**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep -E "unused_field|unused_element"
```

- [ ] **Step 2: For each occurrence, decide: delete or `// ignore:`**

Use the Read tool on each cited file:line. Three categories:

1. **Truly unused, safe to delete:** private field/method with no references anywhere → delete. Confirm zero refs with `grep -rn "fieldName" lib/ test/`.
2. **Interface stub / planned API:** a method that's part of an interface or marked for an upcoming feature → keep, add `// ignore: unused_element` with a one-line justification. Example:
   ```dart
   // ignore: unused_element — implements Cubit lifecycle for future analytics hook
   void _onClose() { /* ... */ }
   ```
3. **Field referenced via reflection or platform code** (rare in Dart): keep, `// ignore:` with justification.

When in doubt: prefer option 2 (keep + ignore) over option 1 (delete). Deletion is irreversible without a revert; an `// ignore:` can be cleaned up later.

- [ ] **Step 3: Verify analyzer count dropped**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `246 issues found.` (294 - 48 = 246).

- [ ] **Step 4: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 1b — drop unused fields/elements (inspected each)

48 unused_field / unused_element / unused_element_parameter findings.
Each occurrence was read for context before deciding delete vs.
// ignore: with justification (used for intentional stubs).

analyze: 294 -> 246

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

### Task 1c: Print statements gated on kDebugMode (16 issues)

**Files:** Various — discovered via analyzer.

- [ ] **Step 1: Inventory**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "avoid_print"
```

- [ ] **Step 2: For each occurrence, choose the fix based on file location and argument content**

Read each file:line. Decide:

1. **Test file (`test/*`):** Replace `print(...)` with `debugPrint(...)`. `debugPrint` is the lint-safe equivalent; it does the same thing in tests.
2. **Production code (`lib/*`), argument has NO PII:** Wrap in `kDebugMode` guard:
   ```dart
   if (kDebugMode) print('foo');
   ```
   You'll need to add `import 'package:flutter/foundation.dart';` at the top of the file if not already present.
3. **Production code, argument HAS PII** (phone, email, OTP, token, name, address — check per CLAUDE.md "Security conventions"): replace with a length-only or boolean-outcome log gated on `kDebugMode`. Example:
   ```dart
   // Before: print('OTP sent to $phoneNumber');
   if (kDebugMode) print('OTP sent (phone length: ${phoneNumber.length})');
   ```

Per CLAUDE.md "Security conventions": **never log PII or auth material.** This step is your chance to fix any historical PII leaks.

- [ ] **Step 3: Verify analyzer count dropped**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `230 issues found.` (246 - 16 = 230).

- [ ] **Step 4: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 5: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 1c — print statements gated on kDebugMode

16 avoid_print findings. Test prints replaced with debugPrint;
production prints wrapped in kDebugMode guards. Any PII-containing
prints were rewritten to log length/boolean outcomes only, per
CLAUDE.md security conventions.

analyze: 246 -> 230

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

### Task 1d: Style fixes — braces, const, override, must_be_immutable, depend_on_referenced_packages (15 issues)

**Files:** Various — discovered via analyzer.

- [ ] **Step 1: Fix curly_braces_in_flow_control_structures (4)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "curly_braces_in_flow_control_structures"
```

For each: open the file, wrap the single-statement `if`/`else`/`for`/`while` body in `{}`. Example:
```dart
// Before
if (foo) doBar();
// After
if (foo) {
  doBar();
}
```

- [ ] **Step 2: Fix prefer_const_constructors + prefer_const_literals_to_create_immutables (2)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep -E "prefer_const"
```

For each: add `const` to the constructor call. Example:
```dart
// Before
SizedBox(width: 8)
// After
const SizedBox(width: 8)
```

- [ ] **Step 3: Fix override_on_non_overriding_member (1)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "override_on_non_overriding_member"
```

Read the file. Two options:
1. The `@override` is wrong (parent class doesn't have this method): delete the `@override` annotation.
2. The parent method exists but was renamed/removed: either restore the parent or update the override to match. Investigate before acting.

- [ ] **Step 4: Fix must_be_immutable (1)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "must_be_immutable"
```

Read the file. This usually means a `StatelessWidget` has a non-`final` field. Two options:
1. Make all fields `final`. Cleanest fix.
2. Convert to `StatefulWidget` if the mutable state is genuinely per-instance. Use only if option 1 isn't viable.

- [ ] **Step 5: Fix depend_on_referenced_packages (7)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "depend_on_referenced_packages"
```

For each: the analyzer is telling you that a package is `import`ed but not listed as a direct dependency in `pubspec.yaml` (it's coming in transitively). Open `pubspec.yaml`, add each missing package under `dependencies:` (NOT `dev_dependencies:` unless the import is in `test/` only). DO NOT specify a version — let the resolver pick to avoid conflicting with the transitive resolution. Use:
```yaml
  package_name:
```

After editing pubspec.yaml:
```bash
~/development/flutter/bin/flutter pub get
```

- [ ] **Step 6: Verify analyzer count dropped**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `215 issues found.` (230 - 15 = 215).

- [ ] **Step 7: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 8: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 1d — style fixes (braces, const, override, immutability, deps)

15 style/structural findings:
- 4 curly_braces_in_flow_control_structures
- 2 prefer_const_*
- 1 override_on_non_overriding_member
- 1 must_be_immutable
- 7 depend_on_referenced_packages (added to pubspec without version pins)

analyze: 230 -> 215

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

### Task 1e: Renames — file_names + non_constant_identifier_names (4 issues)

**Files:** Various — discovered via analyzer.

**This task carries higher risk than the other 1x sub-phases because renames affect every importer/referencer.**

- [ ] **Step 1: Inventory**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep -E "file_names|non_constant_identifier_names"
```

- [ ] **Step 2: For each `non_constant_identifier_names` (2): rename the variable**

Read the file. Identify the offending name (typically `snake_case` for a variable, or `camelCase` for a constant).

```bash
# Find every reference (project-wide)
grep -rn "\bold_name\b" lib/ test/
```

Use the Edit tool with `replace_all: true` *per file* (NOT cross-file). Rename in the defining file, then update each referencing file individually. Confirm by re-running the grep — it should return zero hits for the old name.

- [ ] **Step 3: For each `file_names` (2): rename the file + update every import**

Read the cited file. The Dart convention is `snake_case.dart`. Decide the new name.

```bash
# Find every importer
grep -rn "import.*old_filename" lib/ test/
```

Steps:
1. Use Bash to rename the file: `git mv lib/path/Old_Name.dart lib/path/new_name.dart`
2. For each importer found in the grep, use the Edit tool to update the import path.
3. Re-grep to confirm zero hits for the old filename.

- [ ] **Step 4: Verify analyzer count dropped**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `211 issues found.` (215 - 4 = 211).

- [ ] **Step 5: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

If red: most likely an import was missed. `git diff --stat` to see which files changed, `grep` the test failure's symbol name across the diff.

- [ ] **Step 6: Boot the app to verify no startup regression**

```bash
~/development/flutter/bin/flutter run -d "iPhone" --dart-define-from-file=dart_defines/sentry.json
```

Wait for `Flutter run key commands.`, then quit (`q`). This catches any rename that broke a runtime import path that the test suite doesn't exercise.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 1e — rename to satisfy file_names + identifier rules

4 rename findings:
- 2 non_constant_identifier_names: variables renamed + every ref updated
- 2 file_names: files renamed via git mv + every importer updated

Verified by re-grepping the old names (zero hits) and booting the
app on iOS sim.

analyze: 215 -> 211

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

**Phase 1 complete.** Analyzer count: 211. End of session-1 candidate.

---

## Phase 2 — Deprecated API migration (54 → expected target 157)

### Task 2a: Color component getter migration

**Files:** Discovered via analyzer.

- [ ] **Step 1: Inventory color component deprecations**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | grep -E "'(alpha|red|green|blue)'" | tee /tmp/lint_color_components.txt
```

This produces a file listing every `.alpha`/`.red`/`.green`/`.blue` deprecation.

- [ ] **Step 2: For each occurrence, migrate**

The Flutter Color API changed: `.alpha` (int 0-255) is replaced by `.a` (double 0.0-1.0). To preserve the same int value:

| Before | After |
|---|---|
| `color.alpha` | `(color.a * 255.0).round() & 0xff` |
| `color.red` | `(color.r * 255.0).round() & 0xff` |
| `color.green` | `(color.g * 255.0).round() & 0xff` |
| `color.blue` | `(color.b * 255.0).round() & 0xff` |

**BUT** — if the consumer of the value can take a double 0-1 directly (e.g., passing to another `Color()` constructor that accepts `Color.from(alpha:, red:, ...)`), use the doubles directly. Read the consumer to decide.

For each file in the inventory, use the Edit tool to apply the right replacement. The trickiest cases are when the value is composed (e.g., `Color.fromARGB(color.alpha, ...)`) — there, the simpler migration is `.toARGB32()` if you just need the int form, or the new `Color.from(alpha: color.a, red: color.r, ...)` constructor.

- [ ] **Step 3: Verify count dropped (partial — only the color components fixed in this step)**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | grep -E "'(alpha|red|green|blue)'" | wc -l
```

Expected: 0 (all color component deprecations fixed).

- [ ] **Step 4: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 5: Visual eyeball on iOS sim**

```bash
~/development/flutter/bin/flutter run -d "iPhone" --dart-define-from-file=dart_defines/sentry.json
```

Navigate through 3 screens that you saw in the inventory (the ones with the most color-component usages). Look for any color rendering oddities. If everything looks the same as before, quit.

**If a color looks off:** STOP. The most likely cause is a math error in a non-trivial migration (e.g., a composed color built from multiple components). Find the screen's file in the inventory, re-read the migration, fix.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 2a — Color component getter migration

Replaced deprecated .alpha/.red/.green/.blue with their double
equivalents (.a/.r/.g/.b), preserving int semantics via
(*.X * 255.0).round() & 0xff where consumers required ints.
Visual parity verified on iOS sim.

analyze: 211 -> <new_count>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

(Replace `<new_count>` with the actual count from Step 3's verification.)

---

### Task 2b: SVG color → colorFilter migration

**Files:** Discovered via analyzer.

- [ ] **Step 1: Inventory SVG color deprecations**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | grep "'color'" | tee /tmp/lint_svg_color.txt
```

These come from the `flutter_svg` package's `SvgPicture.asset(... color: ...)`. The replacement is `colorFilter: ColorFilter.mode(<color>, BlendMode.srcIn)`.

- [ ] **Step 2: For each occurrence, migrate**

Use the Edit tool. Pattern:

```dart
// Before
SvgPicture.asset(
  'assets/icons/foo.svg',
  color: AppColors.main,
  width: 24,
)

// After
SvgPicture.asset(
  'assets/icons/foo.svg',
  colorFilter: const ColorFilter.mode(AppColors.main, BlendMode.srcIn),
  width: 24,
)
```

**Important:** `BlendMode.srcIn` is what the old `color:` argument used internally. Using `srcIn` preserves the exact same visual appearance. Do NOT use `BlendMode.src` or `BlendMode.modulate` — they produce different results.

**If the color isn't a `const`** (e.g., `AppColors.primary.withOpacity(0.5)`), drop the `const`:
```dart
colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
```

- [ ] **Step 3: Verify SVG color count dropped to 0**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | grep "'color'" | wc -l
```

Expected: 0.

- [ ] **Step 4: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 5: Visual eyeball — check icon tinting**

```bash
~/development/flutter/bin/flutter run -d "iPhone" --dart-define-from-file=dart_defines/sentry.json
```

Open the home screen, the bottom nav bar, the doctor profile page, and the documents page. SVG icons should be tinted exactly as before. If any icon is now the wrong color (or untinted), STOP and check that `BlendMode.srcIn` was used.

- [ ] **Step 6: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 2b — SVG color → colorFilter migration

Replaced deprecated SvgPicture color: arg with
colorFilter: ColorFilter.mode(<color>, BlendMode.srcIn).
BlendMode.srcIn matches the old color: behavior — visual
parity verified on iOS sim.

analyze: <before> -> <new_count>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

### Task 2c: Misc deprecated API migration

**Files:** Discovered via analyzer.

- [ ] **Step 1: Inventory remaining deprecations**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | tee /tmp/lint_deprecated_remaining.txt
```

These are whatever's left after 2a + 2b. Common candidates in current Flutter:
- `MaterialState*` → `WidgetState*`
- `Color.value` → `.toARGB32()`
- `PopScope.onPopInvoked` → `onPopInvokedWithResult`
- `ThemeData.useMaterial3` (no replacement — was default)
- `Window.locale` / `Window.platformDispatcher` API moves

- [ ] **Step 2: Group by API, apply each group**

For each distinct deprecation message, look up the replacement (the analyzer message itself tells you, e.g. `Use colorFilter instead`). Apply file-by-file with Edit tool.

For any deprecation you're unsure about: search the Flutter changelog or `flutter analyze` doc URL for the exact migration. **Never guess** — a wrong migration here is a silent behavior change.

- [ ] **Step 3: Verify deprecated_member_use count is 0**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "deprecated_member_use" | wc -l
```

Expected: 0.

- [ ] **Step 4: Verify total analyzer count**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `157 issues found.` (only `use_build_context_synchronously` remaining).

- [ ] **Step 5: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

- [ ] **Step 6: Visual eyeball — broad sweep**

```bash
~/development/flutter/bin/flutter run -d "iPhone" --dart-define-from-file=dart_defines/sentry.json
```

Navigate through: home, doctors list, doctor profile, search, account, documents, messages. Look for visual regressions. If you find one, the most recent commit is the suspect — `git diff HEAD~1` to investigate.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(lint): step 2c — misc deprecated API migration

Cleaned up remaining deprecated_member_use findings (Flutter API
churn from version bumps). Each migration followed the replacement
suggested by the analyzer message. Visual parity verified on iOS sim.

analyze: <before> -> 157

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

**Phase 2 complete.** Analyzer count: 157 (all `use_build_context_synchronously`). End of session-2 candidate.

---

## Phase 3 — `use_build_context_synchronously` (157 → 0)

**Approach:** strictly sequential, file-by-file batches of 3-5 files, commit per batch.

### Task 3.0: Build file-grouped inventory

**Files:** none modified.

- [ ] **Step 1: Generate inventory grouped by file**

```bash
~/development/flutter/bin/flutter analyze 2>&1 \
  | grep "use_build_context_synchronously" \
  | awk -F'•' '{print $3}' \
  | awk -F':' '{print $1}' \
  | sort | uniq -c | sort -rn \
  | tee /tmp/lint_bc_by_file.txt
```

This produces a list like:
```
  14 lib/screens/home/messages/conversation_page.dart
  12 lib/screens/doctors/doctor_profile.dart
   9 lib/services/notifications/notification_service.dart
  ...
```

- [ ] **Step 2: Group files into batches of 3-5 for commits**

A "batch" is 3-5 files OR ~15 occurrences, whichever comes first. Note the batch boundaries in your scratch notes. Each batch will become one commit.

Example batches for the file list above:
- Batch B1: conversation_page.dart (14 occurrences) — one file alone, big enough
- Batch B2: doctor_profile.dart + notification_service.dart (21 occurrences) — two files, fine
- Batch B3-Bn: subsequent files grouped to ~3-5 files each

---

### Task 3.N: Fix batch N

**Repeat this task for each batch B1, B2, B3, ... Bn defined in Task 3.0.**

**Files:** the files in batch N, as defined in Task 3.0.

- [ ] **Step 1: For each file in the batch, list its occurrences**

```bash
~/development/flutter/bin/flutter analyze 2>&1 \
  | grep "use_build_context_synchronously" \
  | grep "<file_path>"
```

This gives you the exact `file:line:column` for every occurrence in this file.

- [ ] **Step 2: Open the file. For each occurrence, classify and fix.**

Read the surrounding async function. Each call falls into one of these 5 patterns:

**Pattern A — `setState` after await (StatefulWidget):**
```dart
// BEFORE
await someAsyncCall();
setState(() => x = newValue);

// AFTER
await someAsyncCall();
if (!mounted) return;
setState(() => x = newValue);
```

**Pattern B — `Navigator.of(context).pop/push` after await:**
```dart
// BEFORE
await someAsyncCall();
Navigator.of(context).pop();

// AFTER — cache before await, mounted check after
final navigator = Navigator.of(context);
await someAsyncCall();
if (!mounted) return;
navigator.pop();
```

**Pattern C — `ScaffoldMessenger.of(context).showSnackBar` after await:**
```dart
// BEFORE
await someAsyncCall();
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Done')));

// AFTER
final messenger = ScaffoldMessenger.of(context);
await someAsyncCall();
if (!mounted) return;
messenger.showSnackBar(SnackBar(content: Text('Done')));
```

**Pattern D — `context.read<SomeCubit>()` after await:**
```dart
// BEFORE
await someAsyncCall();
context.read<AuthCubit>().refreshSession();

// AFTER — cache the cubit; no context after await
final authCubit = context.read<AuthCubit>();
await someAsyncCall();
authCubit.refreshSession();
```

Note: Pattern D does NOT need a `mounted` check because the cubit reference is detached from the widget tree. The cubit's own internal `isClosed` guard handles the case where the cubit was disposed.

**Pattern E — `showDialog` / `showModalBottomSheet` / `Navigator.push` after await:**
```dart
// BEFORE
await someAsyncCall();
showDialog(context: context, builder: (_) => AlertDialog(...));

// AFTER — cache navigator, mounted check, push via cached navigator
final navigator = Navigator.of(context);
await someAsyncCall();
if (!mounted) return;
showDialog(context: navigator.context, builder: (_) => AlertDialog(...));
```

Or, for StatelessWidget callbacks where `mounted` isn't available, use `context.mounted`:
```dart
await someAsyncCall();
if (!context.mounted) return;
showDialog(context: context, builder: (_) => AlertDialog(...));
```

**Pattern F — Provably safe (use `// ignore:` with justification):**

If the `context` is a `Builder`'s local context that *cannot* outlive the await (e.g., used inside `showDialog(builder: (ctx) { ... await ...; Navigator.of(ctx).pop(); })`), the lint is a false positive. Add inline ignore:

```dart
showDialog(
  context: context,
  builder: (dialogContext) {
    return AlertDialog(
      content: TextButton(
        onPressed: () async {
          await Future.delayed(Duration(seconds: 1));
          // ignore: use_build_context_synchronously — dialogContext is the Builder's local
          // context, lives only inside this dialog; can't outlive the await.
          Navigator.of(dialogContext).pop();
        },
        child: Text('OK'),
      ),
    );
  },
);
```

**NEVER use `// ignore_for_file:` — that defeats the ratchet.**

- [ ] **Step 3: For each occurrence in this file, apply the matching pattern**

Use the Edit tool. After each edit, the analyzer line for that occurrence should disappear.

- [ ] **Step 4: Re-run analyzer for this file**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "use_build_context_synchronously" | grep "<file_path>"
```

Expected: empty (no findings in this file).

If findings remain: re-read the file, find the occurrences you missed.

- [ ] **Step 5: After all files in the batch are done, run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green.

If red: `git diff` to see what changed. The most likely culprit is a `if (!mounted) return;` that short-circuited a side effect the test expected. Fix by moving the side effect before the await OR by extracting it to a non-context-dependent helper.

- [ ] **Step 6: Verify total analyzer count dropped by the batch size**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: count dropped by exactly the number of occurrences in this batch.

- [ ] **Step 7: Commit and push**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix(lint): use_build_context_synchronously in <feature/folder name>

Fixed N occurrences across M files:
- <file1>: <count> (patterns A/B/C/D/E/F as applicable)
- <file2>: <count>
...

Each occurrence was classified before applying the matching fix:
A=mounted+setState, B=cached Navigator, C=cached ScaffoldMessenger,
D=cached Cubit, E=cached Navigator+mounted+dialog, F=inline ignore
with justification (dialog-builder local context).

Inline ignores added (for audit):
- <file:line>: <justification>
... (or "none" if no ignores)

analyze: <before> -> <after>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 8: If you classified ANY occurrence with low confidence, flag for user testing**

In your final user-facing message at the end of this batch, include a section:

> **Please test the following because I had to make a judgment call:**
> - **<feature>** on **<screen path: e.g. Home > Messages > Conversation>**
> - Interaction: **<exact taps/inputs>**
> - Concern: **<what could go wrong: e.g. "the snackbar might fire even if the user navigated away during the async call">**

Only flag judgment calls — for textbook Pattern A/B/C/D applications, no user test is needed.

**Repeat Task 3.N for each remaining batch.**

After the final batch:

- [ ] **Step 9: Confirm zero occurrences project-wide**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | grep "use_build_context_synchronously" | wc -l
```

Expected: 0.

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `No issues found!`

**Phase 3 complete.** Analyzer count: 0. End of session-3-through-N candidate.

---

## Phase 4 — Ratchet

### Task 4.1: Promote risky lints to errors in `analysis_options.yaml`

**Files:**
- Modify: `analysis_options.yaml`

- [ ] **Step 1: Read the current analysis_options.yaml**

Use the Read tool on `/Users/georgezakhour/development/DocSera/analysis_options.yaml`.

- [ ] **Step 2: Add the ratchet section**

Use the Edit tool to add (or extend) the `analyzer.errors` section. The exact diff depends on the file's existing structure. Typical result:

```yaml
analyzer:
  errors:
    use_build_context_synchronously: error
    unused_import: error
    unused_local_variable: error
    unused_field: error
    unused_element: error
    avoid_print: error
    deprecated_member_use: error
```

If the file already has an `analyzer.errors` section: merge — keep existing entries, add the new ones above. If a rule is already promoted to a different severity (e.g., `warning`), upgrade it to `error`.

- [ ] **Step 3: Re-run analyzer**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
```

Expected: `No issues found!`

**If issues appear:** the ratchet caught something that was previously info-level but is now error-level. This is by design — a finding that the ratchet surfaces is a finding that needed surfacing. Fix it before committing.

- [ ] **Step 4: Run tests**

```bash
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: green. (No code changed; this is paranoia.)

- [ ] **Step 5: Commit and push**

```bash
git add analysis_options.yaml
git commit -m "$(cat <<'EOF'
chore(lint): promote risky lints to errors — regression-prevention ratchet

Promoted the following analyzer rules from info to error so any
future regression breaks the build instead of silently accumulating:
- use_build_context_synchronously (hides real navigation/crash bugs)
- unused_import / unused_local_variable / unused_field / unused_element
  (accumulate fast in multi-agent codebase)
- avoid_print (enforces security-review "never log PII" rule)
- deprecated_member_use (keeps codebase current with Flutter bumps)

The ratchet sticks the discipline we just paid for. Inline
// ignore: <rule> with justification is still allowed for the rare
provably-safe case; // ignore_for_file: is not.

analyze: 0 -> 0 (ratchet only, no findings introduced)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

---

## Phase 5 — Sign-off

### Task 5.1: Final verification + suggest build workflow + document

**Files:**
- Create: `docs/launch/19-lint-cleanup-to-zero.md` (or next numbered step)

- [ ] **Step 1: Final analyzer + test run**

```bash
~/development/flutter/bin/flutter analyze 2>&1 | tail -1
~/development/flutter/bin/flutter test 2>&1 | tail -5
```

Expected: `No issues found!` and `All tests passed!`.

- [ ] **Step 2: Confirm push state**

```bash
git status
git log origin/main..HEAD --oneline
```

Expected: working tree clean, `origin/main..HEAD` is empty (all commits pushed).

- [ ] **Step 3: Find the next docs/launch/ step number**

```bash
ls docs/launch/ | sort | tail -5
```

Use the next number after the highest existing. Example: if `18-deployment-runbook.md` is highest, use `19-lint-cleanup-to-zero.md`.

- [ ] **Step 4: Write the launch-prep entry**

Use the Write tool to create the file with structure:

```markdown
# Step 19 — Lint cleanup to zero + regression ratchet

**Date completed:** 2026-MM-DD
**Spec:** [docs/superpowers/specs/2026-05-16-lint-cleanup-to-zero-design.md](../superpowers/specs/2026-05-16-lint-cleanup-to-zero-design.md)
**Plan:** [docs/superpowers/plans/2026-05-16-lint-cleanup-to-zero-plan.md](../superpowers/plans/2026-05-16-lint-cleanup-to-zero-plan.md)

## What happened

`flutter analyze` was driven from 333 issues to 0 in the patient app
over 5 phases, then `analysis_options.yaml` was ratcheted to promote
the following rules to errors so they can't regress:

- use_build_context_synchronously
- unused_import / unused_local_variable / unused_field / unused_element
- avoid_print
- deprecated_member_use

## Phases (commit hashes)

- Phase 1a: <hash> — drop unused imports + locals (333 → 294)
- Phase 1b: <hash> — drop unused fields/elements (294 → 246)
- Phase 1c: <hash> — print statements gated on kDebugMode (246 → 230)
- Phase 1d: <hash> — style fixes (braces, const, override, deps) (230 → 215)
- Phase 1e: <hash> — file_names + identifier renames (215 → 211)
- Phase 2a: <hash> — Color component getter migration
- Phase 2b: <hash> — SVG color → colorFilter migration
- Phase 2c: <hash> — misc deprecated API migration (→ 157)
- Phase 3.x: <hashes> — use_build_context_synchronously by batch (157 → 0)
- Phase 4: <hash> — ratchet
- Phase 5: this entry

## Files of note

- Inline `// ignore: use_build_context_synchronously` justifications:
  (list file:line + reason for each one, if any were added in Phase 3)

## How to verify after the fact

```bash
~/development/flutter/bin/flutter analyze   # expect: No issues found!
~/development/flutter/bin/flutter test      # expect: All tests passed!
```

If `flutter analyze` shows ANY new lint of a promoted-to-error rule
after this point, that's a regression — fix forward, never bypass.
```

Replace placeholders with actual commit hashes from `git log --oneline | grep -E "chore\(lint\)|fix\(lint\)"`.

- [ ] **Step 5: Commit the docs entry**

```bash
git add docs/launch/19-lint-cleanup-to-zero.md
git commit -m "$(cat <<'EOF'
docs(launch): step 19 — lint cleanup to zero + ratchet

Records the 333 -> 0 analyzer cleanup and the promoted-to-error
rules in analysis_options.yaml. Per CLAUDE.md "always document
launch-prep work after every meaningful change".

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 6: Suggest the build workflow to the user**

In the final user-facing message, suggest running the build workflow per CLAUDE.md "When to PROACTIVELY suggest running the Build workflow":

> "Lint cleanup complete: 333 → 0 issues, analyzer ratchet in place.
>
> Recommend running the build workflow before relying on these commits:
> ```
> gh workflow run build.yml
> ```
> Reason: the SystemUI overlay change in `e222836` (kept during the earlier cleanup) touches Android behavior and hasn't been native-verified. The lint cleanup itself is pure Dart, but bundling that one outstanding native-touching commit through the build gate gives you a clean native baseline for launch."

---

## Self-review

Spec coverage check:
- ✅ Phase 0 gate (test green + boot check) — Task 0.1
- ✅ Phase 1 mechanical (5 sub-phases) — Tasks 1a-1e
- ✅ Phase 2 deprecated (3 sub-phases) — Tasks 2a-2c
- ✅ Phase 3 BuildContext (5 patterns + safe-ignore) — Tasks 3.0 + 3.N
- ✅ Phase 4 ratchet — Task 4.1
- ✅ Phase 5 sign-off + launch docs — Task 5.1
- ✅ "Only ask user to test on judgment calls" — Task 3.N Step 8 codifies the format
- ✅ Commit-per-sub-phase resumability — every task ends with commit + push
- ✅ `analyze: <before> -> <after>` in commit messages — every commit template includes it
- ✅ No parallel subagents in Phase 3 — explicitly forbidden in phase intro
- ✅ DocSera-Pro / Admin scope exclusion — called out at top + spec link

No placeholders. All code blocks are concrete. All commands include expected output. Pattern A-F examples in Task 3.N are complete code. The only `<placeholders>` are intentional — they reflect counts/hashes the engineer will fill in as they execute (because the precise number of occurrences in each batch and the resulting commit hashes can't be known until runtime).
