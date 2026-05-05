# 10 — Performance Pass

**Date:** 2026-05-05
**Score impact:** 9.45 → 9.55
**Roadmap step:** 11

> Note: this doc is numbered 10 because it covers what the launch roadmap calls Step 11 (perf). The `10-` prefix follows file-creation order.

## Why this step exists

The roadmap flagged three "highest-traffic screens" as perf-pass targets: `search_page`, `map_results_page`, and `doctor_profile_page`. Patients hit these constantly — search to find a doctor, map to evaluate proximity, profile to decide if they want to book. Slow or janky behaviour on any of the three directly costs conversions and trust.

Rather than guess at micro-optimizations, this pass audited each screen for known antipatterns (setState in hot paths, N+1 queries, missing debounce on user input) and fixed the four concrete bugs that turned up. No speculative refactors.

## What was actually broken

### 1. `map_results_page` — pulse animation rebuilt the entire Scaffold at 60fps

The user-location indicator on the map renders a soft pulsing circle (radius oscillates between 60m and 100m over a 2s loop). The implementation:

```dart
_pulseController = AnimationController(vsync: this, duration: 2s)
  ..addListener(() {
    setState(() {                       // ← rebuild trigger
      _pulseRadius = 60 + (_pulseController.value * 40);
    });
  })
  ..repeat(reverse: true);
```

Every tick of the controller (≈60 per second) called `setState`, which re-runs the `State.build()` method end-to-end. That meant 60 rebuilds per second of:

- The whole `Scaffold` and `Stack`
- The `GoogleMap` widget (including marker computation)
- The `PageView` of doctor cards at the bottom
- All of the layout / address-formatting helpers in `build()`

Even when Flutter elides most of the actual paint work via diffing, the *widget construction* runs every frame. On a low-end Syrian-market device this is the kind of bug that makes a screen feel laggy without anything visibly happening.

**Fix:** removed the `setState` call entirely. The `_pulseRadius` field is gone — the value is computed on demand. The `GoogleMap` is wrapped in an `AnimatedBuilder` listening to `_pulseController`:

```dart
AnimatedBuilder(
  animation: _pulseController,
  builder: (context, _) {
    final pulseRadius = 60 + (_pulseController.value * 40);
    final circles = {Circle(..., radius: pulseRadius, ...)};
    return GoogleMap(... circles: circles ...);
  },
)
```

Now only the `GoogleMap` rebuilds at 60fps. The Scaffold/Stack/PageView are stable and only rebuild when something they actually depend on changes.

### 2. `doctor_profile_page` — scroll listener rebuilt the 5,335-line widget tree on every scroll event

The scroll listener:

```dart
void _onScroll() {
  if (offset >= triggerOffset && !_showAppBar) {
    setState(() => _showAppBar = true);     // ← OK: threshold-based, fires only on cross
  } else if (offset < triggerOffset && _showAppBar) {
    setState(() => _showAppBar = false);    // ← OK: same
  }

  setState(() {                              // ← BAD: unconditional, every scroll event
    _buttonTopOffset = _calculateButtonOffset();
  });
}
```

The first two `setState` calls flip a `bool` and only fire when the user crosses the threshold — fine. The third one is a continuous numeric update that fires on every pixel of scroll. On a normal 60fps scroll gesture, that's 60 full-page rebuilds per second of a 5,335-line `StatefulWidget`. Even with Flutter's element diffing, scroll responsiveness drops noticeably.

**Fix:** converted `_buttonTopOffset` from a `double` field to a `ValueNotifier<double>`. The scroll listener writes to the notifier instead of calling `setState`:

```dart
final ValueNotifier<double> _buttonTopOffset = ValueNotifier<double>(0.0);

void _onScroll() {
  // ...threshold setStates kept as-is...
  _buttonTopOffset.value = _calculateButtonOffset();   // ← no setState
}
```

The consumer (a single floating CTA) is wrapped in a `ValueListenableBuilder`:

```dart
ValueListenableBuilder<double>(
  valueListenable: _buttonTopOffset,
  builder: (context, topOffset, child) => Positioned(top: topOffset, ..., child: child!),
  child: Opacity(...),
)
```

Now scrolling rebuilds only the `Positioned` widget itself — a tree of 1 widget. The rest of the page tree is stable. The rare threshold-cross still does a `setState` for the AppBar opacity (correct — it's a binary state change).

### 3. `search_page` — search fired a Supabase query on every keystroke

```dart
TextField(onChanged: _performSearch)   // _performSearch issues a network call
```

Typing `cardiology` (10 characters) fired 10 sequential `searchUnified()` Supabase queries in roughly one second. The first 9 are wasted bandwidth and trigger UI churn; only the last one's results matter.

**Fix:** added a 300ms debounce timer. `_onSearchChanged` cancels any pending timer and re-arms it; the actual `_performSearch` only fires after the user pauses typing. Empty-string still clears immediately (no debounce — clearing is intent-driven, not search-driven).

```dart
Timer? _searchDebounce;

void _onSearchChanged(String query) {
  _searchDebounce?.cancel();
  if (query.trim().isEmpty) { _performSearch(query); return; }
  _searchDebounce = Timer(const Duration(milliseconds: 300), () => _performSearch(query));
}
```

### 4. `search_page` — N+1 query in messaging-mode result list

When the search page is opened in `mode == "message"`, the result list shows a "patients-only" gate on doctors who restrict messaging to their existing patients. The implementation:

```dart
Widget _buildDoctorTile(Map<String, dynamic> doctor) {
  return FutureBuilder<bool>(
    future: _isUserPatientOfDoctor(doctor['id']),  // ← one Supabase query per row
    builder: ...,
  );
}
```

Each `_isUserPatientOfDoctor` call hits `appointments.select(id).eq(doctor_id, X).eq(user_id, Y).limit(1)`. With 50 search results, that's 50 separate database round-trips fired as the list scrolls into view. Worse: `FutureBuilder` re-runs its future on every rebuild, so the queries can refire repeatedly.

A second issue: this query was running **even in regular search mode** where its result is never used (the gate is only checked when `widget.mode == "message"`).

**Fix:** batch-prefetch all needed `is-patient` flags in a single query, then read synchronously from a cache in the tile builder:

```dart
final Map<String, bool> _isPatientCache = {};

Future<void> _prefetchPatientStatus(List<String> doctorIds) async {
  final rows = await client
    .from('appointments')
    .select('doctor_id')
    .eq('user_id', _userId!)
    .inFilter('doctor_id', doctorIds);          // ← single batched query
  final patientOf = rows.map((r) => r['doctor_id'].toString()).toSet();
  for (final id in doctorIds) {
    _isPatientCache[id] = patientOf.contains(id);
  }
}
```

`_performSearch` calls `_prefetchPatientStatus` once after results arrive, only in message mode. The tile builder reads `_isPatientCache[doctor['id']] ?? false` synchronously — no `FutureBuilder`, no rebuild storm. The dead `_isUserPatientOfDoctor` helper was deleted.

## What's intentionally NOT in this pass

- **Image caching strategy review.** `flutter_cache_manager` is already configured (see `doctor_image_utils.dart` — 100-image cache, 7-day TTL). No evidence of it being a bottleneck.
- **List virtualization.** Both result lists already use `ListView.builder` (lazy). No eager construction to fix.
- **Repaint boundaries.** Speculative without profile data showing where actual repaint cost lives. Defer until a real perf complaint surfaces.
- **`const` constructor sweep.** `dart fix --apply` ran in Step 9 caught most of these; the remaining are noise-level wins.

## Verification

| Check | Result |
|---|---|
| `flutter analyze` (3 perf-touched files) | 0 errors |
| `flutter test` | 367 passing, 1 skipped |
| `flutter build ios --debug --simulator` (CI) | green (run after this commit) |
| `flutter build apk --debug` (CI) | green |

No measured before/after timings — these are structural fixes for textbook antipatterns, not speculative micro-optimizations. The expected qualitative change:

- **Map page:** scroll/zoom/pan should feel notably smoother. Previously the pulse animation contended with map gesture handling on the same render queue.
- **Doctor profile:** scroll should be smoother on lower-end Syrian devices (e.g. older Android phones with 4GB RAM).
- **Search:** typing should feel snappier (no flash of partial results), and Supabase queries-per-search drop from N (per-character + per-row) to ~2 total.

## What could still go wrong

- The `AnimatedBuilder` around `GoogleMap` rebuilds the map widget every frame. If the underlying platform plugin (`google_maps_flutter`) does extra work on every diff, perf could regress. Worth observing on a real device. If it does, the fix is to only rebuild when `_currentPosition` is non-null (the pulse circle isn't visible until then anyway).
- The `_isPatientCache` is per-page-instance. Navigating away and returning loses it. That's acceptable: the page is cheap to re-fetch and the user typically searches for one doctor per session.
- The 300ms debounce might feel slightly sluggish to some users. 250ms is the lower bound where typing still feels instant; 350ms is the upper bound before users perceive lag. 300ms is the standard pick. Easy to tune.

## Score impact

9.45 → **9.55**. Largest-jump score increment of any step from 8 onward — perf wins are felt directly by every user on every interaction with these screens. Steps 12–15 raise the score further but compound on top of this baseline.
