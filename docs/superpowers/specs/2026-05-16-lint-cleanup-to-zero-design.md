# Lint Cleanup to Zero — DocSera Patient App

**Date:** 2026-05-16
**Author:** Claude (Opus 4.7) + George
**Status:** Spec approved, plan to follow
**Repo:** `/Users/georgezakhour/development/DocSera` (patient app only — DocSera-Pro and DocSera-Admin are out of scope)

## Goal

Drive `flutter analyze` from its current state to **0 issues** in the DocSera patient app, then promote the dangerous lints to compiler errors so they cannot regress after launch.

**Zero behavior change.** Every edit must be observable (analyzer count drops) and reversible (small commits, push after each phase).

## Baseline

As of commit `e222836`:

```
333 issues found.
- 0 errors
- 88 warnings
- 245 lints (info)
```

Composition:

| Rule | Count | Risk |
|---|---|---|
| `use_build_context_synchronously` | 157 | **High** — semantic |
| `deprecated_member_use` | 54 | Low-Medium |
| `unused_local_variable` | 36 | Low |
| `unused_element` | 30 | Low |
| `unused_field` | 17 | Low |
| `avoid_print` | 16 | Low |
| `depend_on_referenced_packages` | 7 | Low |
| `curly_braces_in_flow_control_structures` | 4 | Low |
| `unused_import` | 2 | Low |
| `non_constant_identifier_names` | 2 | Low |
| `file_names` | 2 | Low (but needs ref-renames) |
| `unused_element_parameter` | 1 | Low |
| `unnecessary_import` | 1 | Low |
| `prefer_const_literals_to_create_immutables` | 1 | Low |
| `prefer_const_constructors` | 1 | Low |
| `override_on_non_overriding_member` | 1 | Low |
| `must_be_immutable` | 1 | Low |

## Out of scope

- DocSera-Pro and DocSera-Admin (separate repos, separate work)
- New tests (existing tests are the verification gate)
- `pubspec.yaml` version bumps (only the 7 missing entries for `depend_on_referenced_packages`)
- Refactoring unrelated to lint requirements
- The deferred PDF-package consolidation noted in `docs/launch/13-deps-bundle-audit.md`
- The half-finished `NotificationToastOverlay` port from Pro (already cleaned up in `e222836`)

## Phasing

### Phase 0 — Baseline gate (one session, ~15 min)

**Pre-condition:** Working tree clean, on `main`, at `e222836` or later.

**Steps:**
1. Run `flutter test`. Record outcome.
2. If green → proceed to Phase 1.
3. If red → STOP. Failing tests are an independent problem. Fix + commit + push them first. The fix commit does NOT belong to the lint cleanup; it stands alone. Then proceed.
4. Run `flutter run` once to confirm app boots without runtime errors on the iOS simulator (sanity check, not a smoke test).

**Post-condition:** `flutter test` is green and `flutter run` boots cleanly. This is the reference state — any future test failure during Phases 1-4 is caused by lint work, not pre-existing.

### Phase 1 — Mechanical deletions (122 issues → expected target ~211 remaining)

Order from absolutely safe → mildly risky:

**1a. Pure deletions (no semantic risk):**
- `unused_import` (2)
- `unnecessary_import` (1)
- `unused_local_variable` (36)

**1b. Inspect-then-delete (verify not intentional API stub):**
- `unused_field` (17)
- `unused_element` (30)
- `unused_element_parameter` (1)

For each occurrence: read the surrounding class/file. A field/method may be an intentional stub for an interface or planned API. When in doubt, leave a `// ignore: unused_element` with a one-line justification rather than delete.

**1c. Print statements (16):**
- Production code (`lib/`): wrap in `if (kDebugMode) print(...)` or replace with `debugPrint(...)`. Per `docs/launch/05-security-review.md` and CLAUDE.md "Security conventions", never log PII — check each print's argument before deciding.
- Test code (`test/`): replace with `debugPrint(...)` or guard with `kDebugMode`; deletion is also acceptable.

**1d. Style fixes (low risk):**
- `curly_braces_in_flow_control_structures` (4) — add `{}`
- `prefer_const_constructors` (1), `prefer_const_literals_to_create_immutables` (1) — add `const`
- `override_on_non_overriding_member` (1) — remove `@override` or restore the missing parent method
- `must_be_immutable` (1) — add Key field or convert StatelessWidget → StatefulWidget
- `depend_on_referenced_packages` (7) — add the missing entries to `pubspec.yaml` (no version bumps; let the resolver pick)

**1e. Renames (need grep + careful ref-update):**
- `non_constant_identifier_names` (2) — rename variable (snake_case → camelCase or vice versa per rule)
- `file_names` (2) — rename file + update every `import 'package:.../foo.dart';` reference. Use Bash + grep before editing; never assume the import list is short.

**Commits (suggested split):**
- `chore(lint): step 1a — drop unused imports + locals`
- `chore(lint): step 1b — drop unused fields/elements (inspected each)`
- `chore(lint): step 1c — print statements gated on kDebugMode`
- `chore(lint): step 1d — style fixes (braces, const, override)`
- `chore(lint): step 1e — rename to satisfy file_names + identifier rules`

Each commit message ends with `analyze: <count_before> -> <count_after>` so progress is grep-able from `git log --oneline`.

**Verification after Phase 1:** `flutter analyze` count drops by expected amount; `flutter test` still green.

### Phase 2 — Deprecated API migration (54 issues → expected target 157 remaining)

**Approach:** group by API, codemod each group, file-by-file.

**Likely groups (will confirm with grep at start of phase):**

- **Color component getters** (`.alpha`, `.red`, `.green`, `.blue`) — replace with `.a`, `.r`, `.g`, `.b`. Note the math change: `color.red` becomes `(color.r * 255.0).round() & 0xff` when an `int` 0-255 is needed. When the consumer takes a `double` 0-1, just use `.r`/`.g`/`.b` directly.

- **SVG `color:` property** — replace with `colorFilter: ColorFilter.mode(<color>, BlendMode.srcIn)`. `BlendMode.srcIn` is what `color:` used internally; preserves visual appearance.

- **Other Flutter API deprecations** — handle case by case as they surface. Likely candidates: `MaterialState*` → `WidgetState*`, `Color.value` → `.toARGB32()`, etc.

**Verification after Phase 2:**
- Analyzer count drops by ~54
- `flutter test` green
- I run the app on iOS sim and visually check screens with affected SVG/color references. **Only escalate to you for verification if I see something I'm uncertain about** — and only then with a specific "open this screen, look at this widget" instruction.

**Commits (suggested split):**
- `chore(lint): step 2a — Color component getter migration`
- `chore(lint): step 2b — SVG color → colorFilter migration`
- `chore(lint): step 2c — misc deprecated API migration`

### Phase 3 — `use_build_context_synchronously` (157 → 0)

The dangerous phase. Strictly sequential. **No parallel subagents** (per the multi-agent loss-prevention rule in user memory).

**Classification of each occurrence:**

| Pattern | Shape | Fix |
|---|---|---|
| A | `await foo(); setState(...)` | `if (!mounted) return;` before `setState` |
| B | `await foo(); Navigator.of(context).pop/push(...)` | Cache `final nav = Navigator.of(context);` BEFORE await; then `if (!mounted) return; nav.pop();` |
| C | `await foo(); ScaffoldMessenger.of(context).showSnackBar(...)` | Cache `final messenger = ScaffoldMessenger.of(context);` BEFORE await; mounted check after |
| D | `await foo(); context.read<SomeCubit>()` | Cache the Cubit BEFORE await; never read `context` after |
| E | `await foo(); showDialog(context: context, ...)` | Cache Navigator BEFORE await; `if (!mounted) return; await showDialog(context: nav.context, ...)` |

**Process:**
1. Build a file-grouped inventory of all 157 occurrences: `flutter analyze 2>&1 | grep use_build_context_synchronously | sort -u`.
2. For each file: read each flagged function; classify each call; apply the matching fix.
3. If a flagged call is *provably safe* (e.g., the `context` is a `Builder`'s local context that can't outlive the await): add inline `// ignore: use_build_context_synchronously` with a **one-line justification comment**. Never use `// ignore_for_file:`.
4. Batch commit every ~5 files: `fix(lint): use_build_context_synchronously in <feature/folder>`.
5. Push after every commit.

**Verification after Phase 3:**
- Analyzer count drops to 0
- `flutter test` still green
- **For each batch commit, I list in the commit body any `// ignore:` I added and the file:line — so you can spot-audit if you want.**
- I flag specific files for your testing **only** when I had to make a non-obvious judgment call. Format of the flag: `"Please test <feature> on <screen> by doing <interaction>. The concern is <X>."` No blanket asks.

### Phase 4 — Ratchet (one commit)

Edit `analysis_options.yaml` to promote regression-risky lints from `info` → `error`:

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

Run `flutter analyze` once more — must still show 0 issues. Commit: `chore(lint): promote risky lints to errors — regression-prevention ratchet`.

**Why these specifically:**
- `use_build_context_synchronously` is the one that hides real navigation/crash bugs.
- `unused_*` accumulate fast in a multi-agent codebase; promoting prevents drift.
- `avoid_print` enforces the security review's "never log PII" rule (per `docs/launch/05-security-review.md`).
- `deprecated_member_use` keeps the codebase current with each Flutter version bump.

### Phase 5 — Sign-off

1. `flutter analyze` → 0 issues
2. `flutter test` → all pass
3. Push origin/main (should already be pushed at every phase boundary)
4. Suggest running the build workflow:
   ```
   gh workflow run build.yml
   ```
   This catches any native regression introduced by the SystemUI overlay change in `e222836` (which has not yet been built) and any platform-specific issues from the lint cleanup.
5. Update `docs/launch/` with a new step entry recording the lint cleanup (per the user's "always document launch-prep work" preference).

## Verification gates summary

| Gate | When | Tool | What proves it |
|---|---|---|---|
| Tests green at baseline | Phase 0 | `flutter test` | All pass |
| App boots at baseline | Phase 0 | `flutter run` (iOS sim) | No fatal startup error |
| Analyzer count drops | After every commit | `flutter analyze 2>&1 \| tail -1` | Count matches expectation |
| Tests still green | After every phase | `flutter test` | All pass |
| Visual parity (Phase 2 only) | After Phase 2 | `flutter run` + eyeball | No screen looks wrong |
| Final zero | Phase 5 | `flutter analyze` | `No issues found!` |
| Native build still green | Phase 5 | `gh workflow run build.yml` | Android APK + iOS sim builds succeed |

## Resumability across sessions

A future session resumes by:

1. `git log --oneline | grep "chore(lint)\|fix(lint)"` — see what phases/sub-phases have landed.
2. `flutter analyze 2>&1 | tail -1` — confirm count matches the count in the last lint commit's body.
3. Read this spec to identify the next phase/sub-phase.
4. Read the matching plan checkpoint (will live in `docs/superpowers/plans/2026-05-16-lint-cleanup-to-zero-plan.md` once writing-plans runs).
5. Resume from there.

No mid-phase handoffs. Each commit is a clean resume point.

## What this design does NOT do

- Refactor unrelated code, even if it's ugly
- Add new tests
- Bump dependency versions
- Touch Pro or Admin
- Change app behavior in any user-visible way
- Use parallel subagents (especially in Phase 3)
- Use blanket `// ignore_for_file:` directives

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Deleting a "unused" field that's intentionally an API stub | Phase 1b says inspect each before deleting; when in doubt, `// ignore:` with justification |
| Phase 3 `if (!mounted) return;` accidentally short-circuits side effects that should run regardless of widget life | When fixing, distinguish: side effect tied to UI state (skip if unmounted) vs. side effect needing to complete (move before await, or extract to non-context-dependent helper) |
| SVG `color:` → `colorFilter:` changes visual appearance | Use `BlendMode.srcIn` — the same blend `color:` used internally |
| Multi-agent stomping during multi-session work | Push after every commit; never hold WIP across sessions |
| Tests fail mid-phase | STOP, `git revert` the most recent lint commit, investigate root cause, fix forward |

## Approval

This spec was approved in-chat by George on 2026-05-16. Implementation plan to follow via the `writing-plans` skill.
